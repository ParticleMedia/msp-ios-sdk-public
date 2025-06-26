import Foundation
import MSPiOSCore

protocol TestParamsPresentable {
    var testParams: [String: String] { get }
}

protocol TestParamPresentable {
    var keyValuePairs: [(String, String)] { get }
} 