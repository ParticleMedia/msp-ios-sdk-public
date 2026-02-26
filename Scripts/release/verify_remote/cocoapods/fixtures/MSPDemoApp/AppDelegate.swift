// Minimal AppDelegate for CocoaPods remote verification.
// Imports MSPCore to validate trunk-published pod compiles correctly.
import UIKit
import MSPCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }
}
