import Foundation

private final class Resource: NSObject, PlaybackDiagnosticResource {
    var playbackDiagnosticState = PlaybackDiagnosticState()
}

@main
enum PlaybackDiagnosticsTests {
    static func main() {
        let diagnostics = PlaybackDiagnostics()
        var resource: Resource? = Resource()
        weak var weakResource = resource
        diagnostics.track(resource!)
        resource!.playbackDiagnosticState.hasPlayer = true
        resource!.playbackDiagnosticState.isPlaying = true
        resource!.playbackDiagnosticState.hasTexture = true
        resource!.playbackDiagnosticState.pendingLoads = 1
        let loading = diagnostics.snapshot(registeredPlayers: 1)
        precondition(loading["players"] as? Int == 1)
        precondition(loading["playingPlayers"] as? Int == 1)
        precondition(loading["textures"] as? Int == 1)
        precondition(loading["pendingLoads"] as? Int == 1)

        // Removing a player from the registry must not hide an async load
        // that re-created resources after dispose was requested.
        resource!.playbackDiagnosticState.disposed = true
        resource!.playbackDiagnosticState.pendingLoads = 0
        let orphaned = diagnostics.snapshot(registeredPlayers: 0)
        precondition(orphaned["registeredPlayers"] as? Int == 0)
        precondition(orphaned["liveInstances"] as? Int == 1)
        precondition(orphaned["disposedPlayers"] as? Int == 1)

        resource = nil
        precondition(weakResource == nil, "Telemetry must not retain players")
        precondition(diagnostics.snapshot(registeredPlayers: 0)["players"] as? Int == 0)

        diagnostics.recordFrameDelivered()
        diagnostics.recordFrameDelivered()
        let frames = diagnostics.snapshot(registeredPlayers: 0)
        precondition(frames["framesDelivered"] as? Int64 == 2)
        precondition((frames["footprintBytes"] as? Int64 ?? -1) > 0)
        print("Playback diagnostics tests passed")
    }
}
