import Foundation

@objc public class NovaIcon: NSObject {
    override private init() {}
}

public protocol IconName: CustomStringConvertible {}


extension NovaIcon {
    @objc public enum NovaSystem: Int, CaseIterable {
        case arrowLeftOutline
        case bellFilled
        case bellOutline
        case breezeFilled
        case breezeOutline
        case cameraOutline
        case chartBarOutline
        case checkCircleFilled
        case checkCircleOutline
        case chevronDownFilled
        case chevronDownOutline
        case chevronLeftFilled
        case chevronLeftOutline
        case chevronRightFilled
        case chevronRightOutline
        case chevronUpFilled
        case clockOutline
        case crossFilled
        case crossOutline
        case crossCircleFilled
        case crossCircleOutline
        case ellipsisHorizontalOutline
        case ellipsisVerticalFilled
        case exclamationCircleOutline
        case exclamationTriangleOutline
        case globeOutline
        case hashtagOutline
        case heartOutline
        case imageOutline
        case linkOutline
        case locationOutline
        case moneyOutline
        case navigationArrowOutline
        case newsbreakOutline
        case peopleFilled
        case peopleOutline
        case playFilled
        case plusOutline
        case prohibitOutline
        case shareOutline
        case shieldErrorOutline
        case trashOutline
        case videoClipFilled
        case videoClipOutline
        case magicOutline
        case magicStarFilled
        case homeOutline
    }
}

extension NovaIcon.NovaSystem: IconName {
    public var description: String {
        switch self {
        case .arrowLeftOutline: return "arrow_left_outline"
        case .bellFilled: return "bell_filled"
        case .bellOutline: return "bell_outline"
        case .breezeFilled: return "breeze_filled"
        case .breezeOutline: return "breeze_outline"
        case .cameraOutline: return "camera_outline"
        case .chartBarOutline: return "chart_bar_outline"
        case .checkCircleFilled: return "check_circle_filled"
        case .checkCircleOutline: return "check_circle_outline"
        case .chevronDownFilled: return "chevron_down_filled"
        case .chevronDownOutline: return "chevron_down_outline"
        case .chevronLeftFilled: return "chevron_left_filled"
        case .chevronLeftOutline: return "chevron_left_outline"
        case .chevronRightFilled: return "chevron_right_filled"
        case .chevronRightOutline: return "chevron_right_outline"
        case .chevronUpFilled: return "chevron_up_filled"
        case .clockOutline: return "clock_outline"
        case .crossFilled: return "cross_filled"
        case .crossOutline: return "cross_outline"
        case .crossCircleFilled: return "cross_circle_filled"
        case .crossCircleOutline: return "cross_circle_outline"
        case .ellipsisHorizontalOutline: return "ellipsis_horizontal_outline"
        case .ellipsisVerticalFilled: return "ellipsis_vertical_filled"
        case .exclamationCircleOutline: return "exclamation_circle_outline"
        case .exclamationTriangleOutline: return "exclamation_triangle_outline"
        case .globeOutline: return "globe_outline"
        case .hashtagOutline: return "hashtag_outline"
        case .heartOutline: return "heart_outline"
        case .imageOutline: return "image_outline"
        case .linkOutline: return "link_outline"
        case .locationOutline: return "location_outline"
        case .moneyOutline: return "money_outline"
        case .navigationArrowOutline: return "navigation_arrow_outline"
        case .newsbreakOutline: return "newsbreak_outline"
        case .peopleFilled: return "people_filled"
        case .peopleOutline: return "people_outline"
        case .playFilled: return "play_filled"
        case .plusOutline: return "plus_outline"
        case .prohibitOutline: return "prohibit_outline"
        case .shareOutline: return "share_outline"
        case .shieldErrorOutline: return "shield_error_outline"
        case .trashOutline: return "trash_outline"
        case .videoClipFilled: return "video_clip_filled"
        case .videoClipOutline: return "video_clip_outline"
        case .magicOutline: return "magic_outline"
        case .magicStarFilled: return "magic_star_filled"
        case .homeOutline: return "home_outline"
        }
    }
}
