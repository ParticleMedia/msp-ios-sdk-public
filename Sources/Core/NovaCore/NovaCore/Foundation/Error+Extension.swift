import Foundation

extension Error {
    /// Returns a concise error description in "domain:code" format.
    var formattedMessage: String {
        let nsError = self as NSError
        return "\(nsError.domain):\(nsError.code)"
    }
}
