import Nimble
import Quick

@testable import MSPDemoApp

// MARK: - StubClipboard

// Meszaros Type: Stub — returns canned urlString, no call tracking
private final class StubClipboard: ClipboardReading {
    var urlString: String?
    init(_ value: String? = nil) { urlString = value }
}

// MARK: - WebDebugViewModelSpec

final class WebDebugViewModelSpec: QuickSpec {

    override class func spec() {

        describe("WebDebugViewModel") {

            // Isolated UserDefaults suite — cleared before each test
            @TestState var testDefaults: UserDefaults!
            @TestState var clipboard: StubClipboard!
            @TestState var sut: WebDebugViewModel!

            beforeEach {
                testDefaults = UserDefaults(suiteName: "WebDebugViewModelTests")
                testDefaults.removePersistentDomain(forName: "WebDebugViewModelTests")
                clipboard = StubClipboard()
                sut = WebDebugViewModel(defaults: testDefaults, clipboard: clipboard)
            }

            // MARK: - History: openURL

            context("when openURL is called with a valid http URL") {
                it("[WDB001] inserts the URL at the front of history") {
                    sut.openURL("http://localhost:3000")
                    expect(sut.recentURLs).to(equal(["http://localhost:3000"]))
                }

                it("[WDB005] returns the corresponding URL") {
                    let result = sut.openURL("http://localhost:8080/path")
                    expect(result).toNot(beNil())
                    expect(result?.absoluteString).to(equal("http://localhost:8080/path"))
                }
            }

            context("when openURL is called with a valid https URL") {
                it("[WDB006] returns a non-nil URL") {
                    let result = sut.openURL("https://192.168.1.1:3000")
                    expect(result).toNot(beNil())
                }
            }

            context("when openURL is called with a duplicate URL") {
                it("[WDB002] moves the duplicate to the front without adding a second entry") {
                    sut.openURL("http://a.com")
                    sut.openURL("http://b.com")
                    sut.openURL("http://b.com")
                    expect(sut.recentURLs).to(equal(["http://b.com", "http://a.com"]))
                }
            }

            context("when openURL is called 16 times with unique URLs") {
                it("[WDB003] caps history at maxHistoryCount and trims the oldest entry") {
                    let urls = (1...16).map { "http://host\($0).com" }
                    urls.forEach { sut.openURL($0) }
                    expect(sut.recentURLs.count).to(equal(WebDebugViewModel.maxHistoryCount))
                    expect(sut.recentURLs).toNot(contain("http://host1.com"))
                }
            }

            context("when openURL is called with a URL missing http/https scheme") {
                it("[WDB007] returns nil and leaves history unchanged") {
                    let result = sut.openURL("ftp://example.com")
                    expect(result).to(beNil())
                    expect(sut.recentURLs).to(beEmpty())
                }
            }

            context("when openURL is called with an empty string") {
                it("[WDB008] returns nil and leaves history unchanged") {
                    let result = sut.openURL("")
                    expect(result).to(beNil())
                    expect(sut.recentURLs).to(beEmpty())
                }
            }

            // MARK: - History: deleteURL

            context("when deleteURL is called with a valid index") {
                it("[WDB004] removes the entry at that index") {
                    sut.openURL("http://a.com")
                    sut.openURL("http://b.com")
                    sut.openURL("http://c.com")
                    // history is now ["http://c.com", "http://b.com", "http://a.com"]
                    sut.deleteURL(at: 1)
                    expect(sut.recentURLs).to(equal(["http://c.com", "http://a.com"]))
                }
            }

            // MARK: - Clipboard

            context("when clipboard contains an http URL") {
                it("[WDB009] sets clipboardURL to that URL") {
                    clipboard.urlString = "http://localhost:3000"
                    sut.refreshClipboard()
                    expect(sut.clipboardURL?.absoluteString).to(equal("http://localhost:3000"))
                }
            }

            context("when clipboard contains an https URL") {
                it("[WDB010-a] sets clipboardURL to that URL") {
                    clipboard.urlString = "https://example.com"
                    sut.refreshClipboard()
                    expect(sut.clipboardURL).toNot(beNil())
                }
            }

            context("when clipboard contains plain text") {
                it("[WDB010] sets clipboardURL to nil") {
                    clipboard.urlString = "hello world"
                    sut.refreshClipboard()
                    expect(sut.clipboardURL).to(beNil())
                }
            }

            context("when clipboard contains a non-http scheme URL") {
                it("[WDB011] sets clipboardURL to nil") {
                    clipboard.urlString = "ftp://example.com"
                    sut.refreshClipboard()
                    expect(sut.clipboardURL).to(beNil())
                }
            }

            // MARK: - Persistence

            context("when a new ViewModel is created with the same UserDefaults suite") {
                it("[WDB012] restores history from a previous session") {
                    sut.openURL("http://localhost:3000")

                    let newSut = WebDebugViewModel(defaults: testDefaults, clipboard: StubClipboard())
                    expect(newSut.recentURLs).to(contain("http://localhost:3000"))
                }
            }

            // MARK: - onUpdate callback

            context("when openURL succeeds") {
                it("[WDB013] invokes the onUpdate callback exactly once") {
                    var callCount = 0
                    sut.onUpdate = { callCount += 1 }

                    sut.openURL("https://example.com")

                    expect(callCount).to(equal(1))
                }
            }
        }
    }
}
