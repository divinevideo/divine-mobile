import Foundation

/// Preserve an explicit readiness response without treating other 5xx as ready.
func httpServiceUnavailableCode(status: Int) -> String? {
    status == 503 ? "service_unavailable" : nil
}
