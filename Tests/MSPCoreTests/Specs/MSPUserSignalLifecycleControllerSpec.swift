import Nimble
import Quick
@testable import MSPCore
import UIKit

final class MSPUserSignalLifecycleControllerSpec: QuickSpec {
    override class func spec() {
        describe("MSPUserSignalLifecycleController") {
            var reporter: MockUserSignalReporter!
            var userDefaults: UserDefaults!
            var suiteName: String!
            var applicationState: UIApplication.State!
            var foregroundCallbackCount: Int!
            var backgroundCallbackCount: Int!
            var sut: MSPUserSignalLifecycleController!

            beforeEach {
                reporter = MockUserSignalReporter()
                suiteName = "MSPUserSignalLifecycleControllerSpec-\(UUID().uuidString)"
                userDefaults = UserDefaults(suiteName: suiteName)
                userDefaults.removePersistentDomain(forName: suiteName)
                applicationState = .inactive
                foregroundCallbackCount = 0
                backgroundCallbackCount = 0
                sut = MSPUserSignalLifecycleController(
                    reporter: reporter,
                    userDefaults: userDefaults,
                    applicationStateProvider: { applicationState },
                    onEnterForeground: { foregroundCallbackCount += 1 },
                    onEnterBackground: { backgroundCallbackCount += 1 }
                )
            }

            afterEach {
                userDefaults.removePersistentDomain(forName: suiteName)
            }

            it("does not log foreground before initialization parameters are ready") {
                applicationState = .active

                sut.appDidBecomeActive()

                expect(reporter.loggedTypes).to(beEmpty())
                expect(foregroundCallbackCount).to(equal(0))
            }

            it("logs one foreground session and attribution when initialized while active") {
                applicationState = .active

                sut.setInitializationParametersReady()
                sut.appDidBecomeActive()

                expect(reporter.loggedTypes).to(equal([
                    Com_Newsbreak_Mes_Events_UserSignalType.intoForeground,
                    Com_Newsbreak_Mes_Events_UserSignalType.attribution,
                ]))
                expect(foregroundCallbackCount).to(equal(1))
                expect(userDefaults.bool(forKey: MSP.KEY_MES_USER_SIGNAL_ATTRIBUTION)).to(beTrue())
            }

            it("does not duplicate foreground before background") {
                applicationState = .active
                sut.setInitializationParametersReady()

                sut.appDidBecomeActive()
                sut.appDidBecomeActive()

                expect(reporter.loggedTypes).to(equal([
                    Com_Newsbreak_Mes_Events_UserSignalType.intoForeground,
                    Com_Newsbreak_Mes_Events_UserSignalType.attribution,
                ]))
                expect(foregroundCallbackCount).to(equal(1))
            }

            it("logs background only once for an active foreground session") {
                applicationState = .active
                sut.setInitializationParametersReady()

                sut.appDidEnterBackground()
                sut.appDidEnterBackground()

                expect(reporter.loggedTypes).to(equal([
                    Com_Newsbreak_Mes_Events_UserSignalType.intoForeground,
                    Com_Newsbreak_Mes_Events_UserSignalType.attribution,
                    Com_Newsbreak_Mes_Events_UserSignalType.intoBackground,
                ]))
                expect(backgroundCallbackCount).to(equal(1))
            }

            it("does not log background for a background launch before foreground") {
                applicationState = .background
                sut.setInitializationParametersReady()

                sut.appDidEnterBackground()

                expect(reporter.loggedTypes).to(beEmpty())
                expect(backgroundCallbackCount).to(equal(0))
            }

            it("does not log foreground for a background launch while the app is not active") {
                applicationState = .background
                sut.setInitializationParametersReady()

                sut.appDidBecomeActive()

                expect(reporter.loggedTypes).to(beEmpty())
                expect(foregroundCallbackCount).to(equal(0))
                expect(userDefaults.bool(forKey: MSP.KEY_MES_USER_SIGNAL_ATTRIBUTION)).to(beFalse())
            }

            it("does not log foreground while the app remains inactive during launch") {
                applicationState = .inactive
                sut.setInitializationParametersReady()

                sut.appDidBecomeActive()

                expect(reporter.loggedTypes).to(beEmpty())
                expect(foregroundCallbackCount).to(equal(0))
                expect(userDefaults.bool(forKey: MSP.KEY_MES_USER_SIGNAL_ATTRIBUTION)).to(beFalse())
            }

            it("logs foreground only after a background launch later becomes active") {
                applicationState = .background
                sut.setInitializationParametersReady()
                sut.appDidBecomeActive()
                sut.appDidEnterBackground()

                applicationState = .active
                sut.appDidBecomeActive()

                expect(reporter.loggedTypes).to(equal([
                    Com_Newsbreak_Mes_Events_UserSignalType.intoForeground,
                    Com_Newsbreak_Mes_Events_UserSignalType.attribution,
                ]))
                expect(foregroundCallbackCount).to(equal(1))
                expect(backgroundCallbackCount).to(equal(0))
                expect(userDefaults.bool(forKey: MSP.KEY_MES_USER_SIGNAL_ATTRIBUTION)).to(beTrue())
            }

            it("logs foreground again after a background transition without repeating attribution") {
                applicationState = .active
                sut.setInitializationParametersReady()
                sut.appDidEnterBackground()

                sut.appDidBecomeActive()

                expect(reporter.loggedTypes).to(equal([
                    Com_Newsbreak_Mes_Events_UserSignalType.intoForeground,
                    Com_Newsbreak_Mes_Events_UserSignalType.attribution,
                    Com_Newsbreak_Mes_Events_UserSignalType.intoBackground,
                    Com_Newsbreak_Mes_Events_UserSignalType.intoForeground,
                ]))
                expect(foregroundCallbackCount).to(equal(2))
                expect(backgroundCallbackCount).to(equal(1))
            }
        }
    }
}

private final class MockUserSignalReporter: MSPUserSignalReporting {
    private(set) var loggedTypes: [Com_Newsbreak_Mes_Events_UserSignalType] = []

    func logUserSignal(
        type: Com_Newsbreak_Mes_Events_UserSignalType, completion: ((Bool, Error?) -> Void)?
    ) {
        loggedTypes.append(type)
    }
}
