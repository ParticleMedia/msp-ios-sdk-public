import Nimble
import Quick
import WebKit
@testable import NovaCore

final class StubMraidSupport: NovaMraidSupporting {
    let mraidWebView: WKWebView
    var hasRequestedMraidJs: Bool = false
    var hasInjectedMraidShim: Bool = false
    var hasFinishedLoad: Bool = false

    init(webView: WKWebView) {
        self.mraidWebView = webView
    }

    func handleMraidOpen(params: [String: Any]) {}
    func handleMraidOpen(url: URL) {}
    func handleMraidClose() {}
    func handleMraidPlayVideo(params: [String: Any]) {}
    func handleMraidStorePicture(params: [String: Any]) {}
    func handleMraidCreateCalendarEvent(params: [String: Any]) {}
}

final class FakeTestWebView: WKWebView {
    var lastEvaluatedJS: String?

    init() {
        super.init(frame: .zero, configuration: WKWebViewConfiguration())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func evaluateJavaScript(
        _ javaScriptString: String,
        completionHandler: ((Any?, Error?) -> Void)? = nil
    ) {
        lastEvaluatedJS = javaScriptString
        completionHandler?(nil, nil)
    }
}

class NovaMraidSupportingSpec: QuickSpec {
    override class func spec() {
        describe("NovaMraidSupporting") {
            var webView: FakeTestWebView!
            var sut: StubMraidSupport!

            beforeEach {
                webView = FakeTestWebView()
                sut = StubMraidSupport(webView: webView)
            }

            afterEach {
                webView = nil
                sut = nil
            }

            context("when expand is called") {
                it("[NMS001] fires an error event to JS") {
                    waitUntil { done in
                        sut.handleMraidExpand(params: [:])

                        DispatchQueue.main.async {
                            expect(webView.lastEvaluatedJS).to(contain("_fireEvent('error'"))
                            expect(webView.lastEvaluatedJS).to(contain("\"Expand is not supported.\""))
                            expect(webView.lastEvaluatedJS).to(contain("\"expand\""))
                            done()
                        }
                    }
                }
            }

            context("when resize is called") {
                it("[NMS002] fires an error event to JS") {
                    waitUntil { done in
                        sut.handleMraidResize(params: [:])

                        DispatchQueue.main.async {
                            expect(webView.lastEvaluatedJS).to(contain("_fireEvent('error'"))
                            expect(webView.lastEvaluatedJS).to(contain("\"Resize is not supported.\""))
                            expect(webView.lastEvaluatedJS).to(contain("\"resize\""))
                            done()
                        }
                    }
                }
            }
        }
    }
}
