import AdSupport
import AppTrackingTransparency

enum NovaAdUrlTransformer {
    static func replaceMacro(in urlString: String) -> String {
        var result = urlString

        let replacementByMacro = createReplacementByMacroDict()
        for (macro, replacement) in replacementByMacro {
            result = result.replacingOccurrences(of: macro, with: replacement)
        }

        let replacementByRegexMacro = createReplacementByRegexMacroDict()
        for (regexMacro, replacement) in replacementByRegexMacro {
            result = replaceAll(regexMacro: regexMacro, with: replacement, in: result)
        }

        return result
    }
}

// MARK: - Private methods

private extension NovaAdUrlTransformer {
    static func createReplacementByMacroDict() -> [String: String] {
        return [
            .adIdPlainMacro: ASIdentifierManager.shared().advertisingIdentifier.uuidString,
            .adIdTypeMacro: .adIdTypeValue,
            .adIdIsLatMacro: isIDFAAuthorized() ? .adIdIsLatTrue : .adidIsLatFalse,
            .siteMacro: .siteValue,
            .gdprMacro: .gdprValue,
        ]
    }

    static func createReplacementByRegexMacroDict() -> [String: String] {
        return [.gdprConsentMacroRegex: .gdprConsentValue]
    }

    static func replaceAll(regexMacro: String, with replacement: String, in originalText: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: regexMacro, options: [])

            let range = NSRange(location: 0, length: originalText.count)
            return regex.stringByReplacingMatches(
                in: originalText,
                options: [],
                range: range,
                withTemplate: replacement)
        } catch {
            return originalText
        }
    }
    
    static func isIDFAAuthorized() -> Bool {
        if #available(iOS 14, *), case .authorized = ATTrackingManager.trackingAuthorizationStatus {
            return true
        } else {
            return false
        }
    }

}

private extension String {
    static let adIdPlainMacro = "%%ADVERTISING_IDENTIFIER_PLAIN%%"
    static let adIdTypeMacro = "%%ADVERTISING_IDENTIFIER_TYPE%%"
    static let adIdTypeValue = "idfa"
    static let adIdIsLatMacro = "%%ADVERTISING_IDENTIFIER_IS_LAT%%"
    static let adIdIsLatTrue = "1"
    static let adidIsLatFalse = "0"
    static let siteMacro = "%%SITE%%"
    static let siteValue = "newsbreak.com"
    static let gdprMacro = "${GDPR}"
    static let gdprValue = ""
    static let gdprConsentMacroRegex = "\\$\\{GDPR_CONSENT_.+\\}"
    static let gdprConsentValue = ""
}
