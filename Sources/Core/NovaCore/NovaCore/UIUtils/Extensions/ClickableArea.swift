//
//  ClickableArea.swift
//  NovaCore
//
//  Created by Shanyu Li on 2026/1/28.
//

enum ClickableAdArea: Hashable {
    case icon
    case advertiser
    case sponsor
    case headline
    case body
    case cta
    case media
    case badge
    case shadow

    case like
    case comment
    case share

    case advertiserEndcard
    case bodyEndcard
    case ctaEndcard
    case iconEndcard
    case blankEndcard

    case tapToTry
    case playable

    case autoJump
    case ctaPopover

    case html

    case custom(String)
}

extension ClickableAdArea {
    private static let predefinedAreas: [String: ClickableAdArea] = [
        "icon": .icon,
        "advertiser": .advertiser,
        "sponsor": .sponsor,
        "headline": .headline,
        "body": .body,
        "cta": .cta,
        "media": .media,
        "badge": .badge,
        "shadow": .shadow,

        "like": .like,
        "comment": .comment,
        "share": .share,

        "advertiser_endcard": .advertiserEndcard,
        "body_endcard": .bodyEndcard,
        "cta_endcard": .ctaEndcard,
        "icon_endcard": .iconEndcard,
        "blank_endcard": .blankEndcard,

        "tap_to_try": .tapToTry,
        "playable": .playable,

        "auto_jump": .autoJump,
        "cta_popover": .ctaPopover,

        "html": .html,
    ]

    /// Creates a `ClickableAdArea` from its raw string representation.
    ///
    /// This initializer maps known raw strings (e.g., `"cta"`, `"icon"`) to their corresponding
    /// enum cases. If the string is not recognized, it falls back to `.custom(raw)`.
    ///
    /// - Parameter raw: The raw string value representing the clickable area.
    ///
    /// - Important: If you encounter a new area string that is used consistently across the codebase,
    ///   **add a new enum case** instead of relying on `.custom`. The `.custom` case should only be
    ///   used for truly dynamic or one-off values that cannot be known at compile time.
    init(from raw: String) {
        self = Self.predefinedAreas[raw] ?? .custom(raw)
    }

    var stringValue: String {
        switch self {
        case .icon: return "icon"
        case .advertiser: return "advertiser"
        case .sponsor: return "sponsor"
        case .headline: return "headline"
        case .body: return "body"
        case .cta: return "cta"
        case .media: return "media"
        case .badge: return "badge"
        case .shadow: return "shadow"
        case .like: return "like"
        case .comment: return "comment"
        case .share: return "share"
        case .advertiserEndcard: return "advertiser_endcard"
        case .bodyEndcard: return "body_endcard"
        case .ctaEndcard: return "cta_endcard"
        case .iconEndcard: return "icon_endcard"
        case .blankEndcard: return "blank_endcard"
        case .tapToTry: return "tap_to_try"
        case .playable: return "playable"
        case .autoJump: return "auto_jump"
        case .ctaPopover: return "cta_popover"
        case .html: return "html"
        case .custom(let s): return s
        }
    }
}
