import Foundation
import Darwin
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Value-only gauges, read on the main thread. No media or account identifiers.
struct PlaybackDiagnosticState {
    var disposed = false
    var hasPlayer = false
    var isPlaying = false
    var hasTexture = false
    var pendingLoads = 0
}

protocol PlaybackDiagnosticResource: AnyObject {
    var playbackDiagnosticState: PlaybackDiagnosticState { get }
}

/// Process-wide, main-thread-only instrumentation. Weak tracking deliberately
/// survives registry removal without extending the lifetime being measured.
final class PlaybackDiagnostics {
    static let shared = PlaybackDiagnostics()
    private let resources = NSHashTable<AnyObject>.weakObjects()
    private var framesDelivered: Int64 = 0

    func track(_ resource: PlaybackDiagnosticResource) {
        resources.add(resource)
    }

    func recordFrameDelivered() {
        framesDelivered += 1
    }

    func snapshot(registeredPlayers: Int) -> [String: Any] {
        let states = autoreleasepool {
            resources.allObjects.compactMap {
                ($0 as? PlaybackDiagnosticResource)?.playbackDiagnosticState
            }
        }
        var players = 0
        var playingPlayers = 0
        var textures = 0
        var pendingLoads = 0
        var disposedPlayers = 0
        for state in states {
            if state.hasPlayer { players += 1 }
            if state.isPlaying { playingPlayers += 1 }
            if state.hasTexture { textures += 1 }
            pendingLoads += state.pendingLoads
            if state.disposed && state.hasPlayer { disposedPlayers += 1 }
        }
        let vm = Self.vmInfo()
        return [
            "version": 1,
            "platform": Self.platform,
            "appState": Self.appState,
            "footprintBytes": Self.vmField(vm, \.phys_footprint),
            "graphicsFootprintBytes": Self.vmField(vm, \.ledger_tag_graphics_footprint),
            "mediaFootprintBytes": Self.vmField(vm, \.ledger_tag_media_footprint),
            "memoryLimitRemainingBytes": Self.vmField(vm, \.limit_bytes_remaining),
            "registeredPlayers": registeredPlayers,
            "liveInstances": states.count,
            "players": players,
            "playingPlayers": playingPlayers,
            "textures": textures,
            "pendingLoads": pendingLoads,
            "disposedPlayers": disposedPlayers,
            "framesDelivered": framesDelivered,
        ]
    }

    private static var platform: String {
        #if os(iOS)
        return ProcessInfo.processInfo.isiOSAppOnMac ? "ios_on_mac" : "ios"
        #else
        return "macos"
        #endif
    }

    private static var appState: String {
        #if os(iOS)
        switch UIApplication.shared.applicationState {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
        #else
        return NSApplication.shared.isActive ? "active" : "inactive"
        #endif
    }

    /// The kernel's VM accounting for this process and how many of its bytes
    /// the kernel filled in, or nil when the probe fails. An older OS fills a
    /// shorter, earlier revision of the struct.
    private static func vmInfo() -> (info: task_vm_info_data_t, filledBytes: Int)? {
        var info = task_vm_info_data_t()
        let capacity = MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(capacity)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        return (info, Int(count) * MemoryLayout<integer_t>.size)
    }

    /// One field of [vm], or -1 when the probe failed or this OS does not
    /// fill it, never a misleading zero. Apple's footprint includes compressed
    /// memory that RSS does not; the graphics and media ledgers are the parts
    /// of it GPU resources and media buffers own; the remaining limit is how
    /// far the footprint is from the point where the OS ends the app. None of
    /// this is an allocation trace.
    private static func vmField<T: BinaryInteger>(
        _ vm: (info: task_vm_info_data_t, filledBytes: Int)?,
        _ field: KeyPath<task_vm_info_data_t, T>
    ) -> Int64 {
        guard let vm,
              let offset = MemoryLayout<task_vm_info_data_t>.offset(of: field),
              vm.filledBytes >= offset + MemoryLayout<T>.size else { return -1 }
        return Int64(clamping: vm.info[keyPath: field])
    }
}
