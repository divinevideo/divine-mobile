import Flutter
import UIKit

@available(iOS 14.0, *)
public class DivineDeviceAttestationPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "app_attestation", binaryMessenger: registrar.messenger())
        let instance = DivineDeviceAttestationPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAttestationServiceSupport":
            guard let args = call.arguments as? [String: Any],
                let challengeString = args["challengeString"] as? String,
                let keyScope = args["keyScope"] as? String
            else {
                result(FlutterError(code: "-3", message: "Invalid arguments", details: nil))
                return
            }

            // App Attest hits the Secure Enclave and Apple's attestation
            // servers. Flutter delivers channel calls on the main thread, so
            // doing that work here froze the UI for ~200ms on every call.
            // Stay off-main and only hop back to deliver the result.
            DispatchQueue.global(qos: .userInitiated).async {
                guard let deviceIntegrity = DivineDeviceAttestation(challengeString: challengeString, keyScope: keyScope) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "-4", message: "Failed to initialize DivineDeviceAttestation", details: nil))
                    }
                    return
                }

                // Directly generate key and attest
                deviceIntegrity.generateKeyAndAttest { success in
                    // Encode here, still off-main: the attestation string is
                    // several KB of base64.
                    let payload: Any
                    if success {
                        // The attestation proves the key came from a genuine
                        // Apple device; the assertion — present on every
                        // challenge after the key was provisioned — proves this
                        // specific challenge was signed by that key.
                        var attestationResult = [
                            "attestationString": deviceIntegrity.attestationString ?? "",
                            "keyID": deviceIntegrity.keyIdentifier()
                        ]
                        if let assertion = deviceIntegrity.assertionString {
                            attestationResult["assertionString"] = assertion
                        }

                        do {
                            let jsonData = try JSONEncoder().encode(attestationResult)
                            if let jsonString = String(data: jsonData, encoding: .utf8) {
                                payload = jsonString
                            } else {
                                payload = FlutterError(code: "-6", message: "Failed to convert JSON data to String", details: nil)
                            }
                        } catch {
                            payload = FlutterError(code: "-7", message: "JSON encoding error: \(error.localizedDescription)", details: nil)
                        }
                    } else {
                        // Attestation or key generation failed
                        payload = FlutterError(code: "-5", message: "Attestation failed", details: nil)
                    }

                    DispatchQueue.main.async {
                        result(payload)
                    }
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

}
