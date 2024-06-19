import WebKit
import Foundation

class ContentBlockHelper {
    
    static func contentBlockRuleList(for urlPrefixes: [String]) -> WKContentRuleList? {
        let array = urlPrefixes.filter({ !$0.isEmpty })
        guard !array.isEmpty else {
            return nil
        }
        
        let rules: [[String: [String: String]]] = array.map({ urlPrefix in
            let rule: [String: [String: String]] = [
                "trigger": [
                    "url-filter": "^\(NSRegularExpression.escapedPattern(for: urlPrefix))",
                ],
                "action": [
                    "type": "block",
                ],
            ]
            return rule
        })
        
        guard let data = try? JSONEncoder().encode(rules),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        var finished = false
        var contentRuleList: WKContentRuleList? = nil
        let ruleListStore = WKContentRuleListStore.default()
        ruleListStore?.compileContentRuleList(forIdentifier: "ad_block",
                                              encodedContentRuleList: string,
                                              completionHandler: { ruleList, error in
                                                  contentRuleList = ruleList
                                                  finished = true
                                                  CFRunLoopStop(CFRunLoopGetCurrent())
                                              })
        while !finished {
            CFRunLoopRun()
        }
        
        return contentRuleList
    }
    
}
