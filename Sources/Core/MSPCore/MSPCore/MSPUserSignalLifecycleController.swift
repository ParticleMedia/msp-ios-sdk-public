import Foundation
import MSPiOSCore
import UIKit

protocol MSPUserSignalReporting: AnyObject {
    func logUserSignal(
        type: Com_Newsbreak_Mes_Events_UserSignalType, completion: ((Bool, Error?) -> Void)?)
}

extension MESMetricReporter: MSPUserSignalReporting {}

final class MSPUserSignalLifecycleController {
    private let reporter: MSPUserSignalReporting
    private let userDefaults: UserDefaults
    private let applicationStateProvider: () -> UIApplication.State
    private let onEnterForeground: () -> Void
    private let onEnterBackground: () -> Void

    private var isForegroundSessionActive = false
    private var isAttributionSignalInFlight = false
    private var hasInitializationParameters = false

    init(
        reporter: MSPUserSignalReporting,
        userDefaults: UserDefaults = .standard,
        applicationStateProvider: @escaping () -> UIApplication.State,
        onEnterForeground: @escaping () -> Void,
        onEnterBackground: @escaping () -> Void
    ) {
        self.reporter = reporter
        self.userDefaults = userDefaults
        self.applicationStateProvider = applicationStateProvider
        self.onEnterForeground = onEnterForeground
        self.onEnterBackground = onEnterBackground
    }

    func setInitializationParametersReady() {
        hasInitializationParameters = true
        logForegroundSignalIfNeeded()
    }

    func appDidBecomeActive() {
        logForegroundSignalIfNeeded()
    }

    func appDidEnterBackground() {
        guard isForegroundSessionActive else { return }

        MSPLogger.shared.info(message: "App enters background")
        reporter.logUserSignal(type: Com_Newsbreak_Mes_Events_UserSignalType.intoBackground, completion: nil)
        isForegroundSessionActive = false
        onEnterBackground()
    }

    private func logForegroundSignalIfNeeded() {
        guard hasInitializationParameters else { return }
        guard applicationStateProvider() == .active else { return }
        guard !isForegroundSessionActive else { return }

        MSPLogger.shared.info(message: "App enters foreground")
        isForegroundSessionActive = true
        onEnterForeground()
        reporter.logUserSignal(type: Com_Newsbreak_Mes_Events_UserSignalType.intoForeground, completion: nil)

        logAttributionSignalIfNeeded()
    }

    private func logAttributionSignalIfNeeded() {
        guard !userDefaults.bool(forKey: MSP.KEY_MES_USER_SIGNAL_ATTRIBUTION) else { return }
        guard !isAttributionSignalInFlight else { return }

        isAttributionSignalInFlight = true
        // Mark before sending so a timeout after server receipt cannot create a duplicate attribution signal.
        userDefaults.set(true, forKey: MSP.KEY_MES_USER_SIGNAL_ATTRIBUTION)
        reporter.logUserSignal(type: Com_Newsbreak_Mes_Events_UserSignalType.attribution) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.isAttributionSignalInFlight = false
            }
        }
    }
}
