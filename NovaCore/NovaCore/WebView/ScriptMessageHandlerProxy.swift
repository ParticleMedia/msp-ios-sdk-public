import WebKit

class ScriptMessageHandlerProxy: NSObject, WKScriptMessageHandler {

    private weak var handler: WKScriptMessageHandler?

    public init(handler: WKScriptMessageHandler) {
        self.handler = handler
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        self.handler?.userContentController(userContentController, didReceive: message)
    }

}

