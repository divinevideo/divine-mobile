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
        return [
            "version": 1,
            "platform": Self.platform,
            "appState": Self.appState,
            "footprintBytes": Self.physicalFootprint(),
            "registeredPlayers": registeredPlayers,
            "liveInstances": states.count,
            "players": states.filter { $0.hasPlayer }.count,
            "playingPlayers": states.filter { $0.isPlaying }.count,
            "textures": states.filter { $0.hasTexture }.count,
            "pendingLoads": states.reduce(0) { $0 + $1.pendingLoads },
            "disposedPlayers": states.filter { $0.disposed && $0.hasPlayer }.count,
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

    /// Apple's footprint includes compressed memory that RSS does not. Return
    /// -1 on failure, never a misleading zero. This is not an allocation trace.
    private static func physicalFootprint() -> Int64 {
        var info = task_vm_info_data_t()
        let capacity = MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(capacity)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let footprintEnd = MemoryLayout<task_vm_info_data_t>.offset(of: \.phys_footprint)!
            + MemoryLayout<UInt64>.size
        guard status == KERN_SUCCESS,
              Int(count) * MemoryLayout<integer_t>.size >= footprintEnd else { return -1 }
        return Int64(clamping: info.phys_footprint)
    }
}
