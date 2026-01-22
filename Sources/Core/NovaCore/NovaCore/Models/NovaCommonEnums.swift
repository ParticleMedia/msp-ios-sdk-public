import UIKit

enum NovaNativeImageContentMode: String, Codable {
    case crop
    case fit

    func toUIViewContentMode() -> UIView.ContentMode {
        switch self {
        case .crop:
            return .scaleAspectFill
        case .fit:
            return .scaleAspectFit
        }
    }
}

public enum NovaNativeLayoutStyle: String, Codable {
    case unknown
    case sponsor
    case horizontal
    case vertical
    case interscroller
    case taller
    case carousel
    case collection

    var mediaOrientation: NovaNativeMediaLayoutOrientation? {
        switch self {
        case .horizontal: return .horizontal
        case .vertical: return .vertical
        default: return nil
        }
    }
}

enum NovaInterstitialAdLayout: String, Codable, CaseIterable {
    case unknown
    case horizontal
    case vertical
    case horizontalCancelTopRight = "horizontal_cancel_top_right"
    case verticalCancelTopRight = "vertical_cancel_top_right"
    case endCard = "end_card_2_part"
    case sponsor

    var mediaOrientation: NovaNativeMediaLayoutOrientation? {
        switch self {
        case .horizontal, .horizontalCancelTopRight: return .horizontal
        case .vertical, .verticalCancelTopRight: return .vertical
        default: return nil
        }
    }
}

enum NovaAdMarketingType: String, Codable {
    case unknown
    case normal = "NORMAL"
    case dpa = "DPA"
}

enum NovaNativeAdEndCardStyle: String, Codable {
    case `default` = "DEFAULT"
}

enum NovaClickableComponent: String, Codable {
    case title = "title"
    case body = "body"
    case media = "media"
    case advertiserName = "advertiser_name"
    case adTag = "ad_tag"
    case cta = "cta"
    case icon = "icon"
    case all = "all"
}
