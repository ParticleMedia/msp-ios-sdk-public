import FBAudienceNetwork
import Foundation

/// Listens to FBAudienceNetwork verbose logs and registers the current device
/// as a test device via `FBAdSettings.addTestDevice`.
///
/// FB SDK may emit a temporary hash on first install before outputting the
/// stable hash, so the delegate remains active and updates on every occurrence.
///
/// Usage:
/// ```swift
/// private let fbTestDeviceRegistrar = FBTestDeviceRegistrar()
///
/// fbTestDeviceRegistrar.setup() // call before the first FB ad request
/// ```
final class FBTestDeviceRegistrar: NSObject {
    func setup() {
        FBAdSettings.setLogLevel(.verbose)
        FBAdSettings.loggingDelegate = self
    }
}

// MARK: - FBAdLoggingDelegate

extension FBTestDeviceRegistrar: FBAdLoggingDelegate {
    func log(
        at logLevel: FBAdLogLevel,
        withFileName fileName: String,
        withLineNumber lineNumber: Int32,
        withThreadId threadId: Int,
        withBody body: String
    ) {
        let pattern = "[0-9a-fA-F]{32,40}"
        guard body.lowercased().contains("hash"),
              let range = body.range(of: pattern, options: .regularExpression)
        else { return }

        let hash = String(body[range])
        DispatchQueue.main.async {
            FBAdSettings.addTestDevice(hash)
            print("[MSPDemoApp] FB test device updated: \(hash)")
        }
    }
}
