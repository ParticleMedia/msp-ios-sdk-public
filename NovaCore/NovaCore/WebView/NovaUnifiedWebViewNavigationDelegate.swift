import WebKit

public protocol NovaUnifiedWebViewNavigationDelegate: NSObject {

    func openWebPage(_ url: URL)

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!)

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!)

    func webView(_ webView: WKWebView, policyFor navigationAction: WKNavigationAction) -> WKNavigationActionPolicy?

    func webView(_ webView: WKWebView, canRedirectTo url: URL) -> Bool

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error)

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void)

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView)

    func webViewInitialLoadDidRedirect(_ webView: WKWebView);

    func webViewDidGoBackToInitialLoad(_ webView: WKWebView);
    
}

public extension NovaUnifiedWebViewNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { }

    func webView(_ webView: WKWebView, policyFor navigationAction: WKNavigationAction) -> WKNavigationActionPolicy? {
        return nil
    }

    func webView(_ webView: WKWebView, canRedirectTo url: URL) -> Bool {
        return true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { }
    
    func webViewInitialLoadDidRedirect(_ webView: WKWebView) {}
    
    func webViewDidGoBackToInitialLoad(_ webView: WKWebView) {}

}

