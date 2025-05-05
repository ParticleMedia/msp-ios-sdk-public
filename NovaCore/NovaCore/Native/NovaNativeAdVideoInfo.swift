public final class NovaNativeAdVideoInfo: Codable {

    public let cacheKey: String

    public let coverUrlStr: String?

    public let videoUrlStr: String

    public let isVertical: Bool

    public let isVideoClickable: Bool
    
    public let isPlayOnLandingPage: Bool

    public let isAuto: Bool

    public let isMute: Bool

    public let isLoop: Bool

    public var state: NovaNativeAdVideoState? {
        didSet {
            
        }
    }

    public var didStart: Bool = false

    init(adId:String,
         coverUrlStr: String?,
         videoUrlStr: String,
         isVertical: Bool,
         isVideoClickable: Bool,
         isPlayOnLandingPage: Bool,
         isAuto: Bool,
         isMute: Bool,
         isLoop: Bool
    ) {
        self.cacheKey = adId
        self.coverUrlStr = coverUrlStr
        self.videoUrlStr = videoUrlStr
        self.isVertical = isVertical
        self.isVideoClickable = isVideoClickable
        self.isPlayOnLandingPage = isPlayOnLandingPage
        self.isAuto = isAuto
        self.isMute = isMute
        self.isLoop = isLoop
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case cacheKey
        case coverUrlStr
        case videoUrlStr
        case isVertical
        case isVideoClickable
        case isPlayOnLandingPage
        case isAuto
        case isMute
        case isLoop
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        cacheKey = try container.decode(String.self, forKey: .cacheKey)
        coverUrlStr = try? container.decode(String.self, forKey: .coverUrlStr)
        videoUrlStr = try container.decode(String.self, forKey: .videoUrlStr)
        isVertical = try container.decode(Bool.self, forKey: .isVertical)
        isVideoClickable = try container.decode(Bool.self, forKey: .isVideoClickable)
        isPlayOnLandingPage = try container.decode(Bool.self, forKey: .isPlayOnLandingPage)
        isAuto = try container.decode(Bool.self, forKey: .isAuto)
        isMute = try container.decode(Bool.self, forKey: .isMute)
        isLoop = try container.decode(Bool.self, forKey: .isLoop)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(cacheKey, forKey: .cacheKey)
        try container.encode(coverUrlStr, forKey: .coverUrlStr)
        try container.encode(videoUrlStr, forKey: .videoUrlStr)
        try container.encode(isVertical, forKey: .isVertical)
        try container.encodeIfPresent(isVideoClickable, forKey: .isVideoClickable)
        try container.encodeIfPresent(isPlayOnLandingPage, forKey: .isPlayOnLandingPage)
        try container.encodeIfPresent(isAuto, forKey: .isAuto)
        try container.encodeIfPresent(isMute, forKey: .isMute)
        try container.encodeIfPresent(isLoop, forKey: .isLoop)
    }
}
