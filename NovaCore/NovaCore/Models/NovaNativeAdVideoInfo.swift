final class NovaNativeAdVideoInfo: Codable {

    let cacheKey: String

    let coverUrlStr: String?

    let videoUrlStr: String

    // deprecated, Using `layout` from NovaNativeBaseAd to figure out the layout instead
    let isLayoutVertical: Bool

    // Backward compatibility property
    var isVertical: Bool {
        return isLayoutVertical
    }

    let isVideoClickable: Bool
    
    let isPlayOnLandingPage: Bool

    let isAuto: Bool

    let isMute: Bool

    let isLoop: Bool

    let endCardStyle: NovaNativeAdEndCardStyle?

    var state: NovaAdVideoState?

    var didStart: Bool = false

    init(adId: String,
         coverUrlStr: String?,
         videoUrlStr: String,
         isLayoutVertical: Bool,
         isVideoClickable: Bool,
         isPlayOnLandingPage: Bool,
         isAuto: Bool,
         isMute: Bool,
         isLoop: Bool,
         endCardStyle: NovaNativeAdEndCardStyle?
    ) {
        self.cacheKey = adId
        self.coverUrlStr = coverUrlStr
        self.videoUrlStr = videoUrlStr
        self.isLayoutVertical = isLayoutVertical
        self.isVideoClickable = isVideoClickable
        self.isPlayOnLandingPage = isPlayOnLandingPage
        self.isAuto = isAuto
        self.isMute = isMute
        self.isLoop = isLoop
        self.endCardStyle = endCardStyle
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case cacheKey
        case coverUrlStr
        case videoUrlStr
        case isLayoutVertical
        case isVideoClickable
        case isPlayOnLandingPage
        case isAuto
        case isMute
        case isLoop
        case endCardStyle
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        cacheKey = try container.decode(String.self, forKey: .cacheKey)
        coverUrlStr = try? container.decode(String.self, forKey: .coverUrlStr)
        videoUrlStr = try container.decode(String.self, forKey: .videoUrlStr)
        isLayoutVertical = try container.decode(Bool.self, forKey: .isLayoutVertical)
        isVideoClickable = try container.decode(Bool.self, forKey: .isVideoClickable)
        isPlayOnLandingPage = try container.decode(Bool.self, forKey: .isPlayOnLandingPage)
        isAuto = try container.decode(Bool.self, forKey: .isAuto)
        isMute = try container.decode(Bool.self, forKey: .isMute)
        isLoop = try container.decode(Bool.self, forKey: .isLoop)
        endCardStyle = try container.decodeIfPresent(NovaNativeAdEndCardStyle.self, forKey: .endCardStyle)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(cacheKey, forKey: .cacheKey)
        try container.encode(coverUrlStr, forKey: .coverUrlStr)
        try container.encode(videoUrlStr, forKey: .videoUrlStr)
        try container.encode(isLayoutVertical, forKey: .isLayoutVertical)
        try container.encodeIfPresent(isVideoClickable, forKey: .isVideoClickable)
        try container.encodeIfPresent(isPlayOnLandingPage, forKey: .isPlayOnLandingPage)
        try container.encodeIfPresent(isAuto, forKey: .isAuto)
        try container.encodeIfPresent(isMute, forKey: .isMute)
        try container.encodeIfPresent(isLoop, forKey: .isLoop)
        try container.encodeIfPresent(endCardStyle, forKey: .endCardStyle)
    }
}
