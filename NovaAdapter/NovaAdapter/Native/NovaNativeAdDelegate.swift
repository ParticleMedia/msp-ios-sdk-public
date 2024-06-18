@objc public protocol NovaNativeAdDelegate: AnyObject {
    func nativeAdDidLogImpression(_ nativeAd: NovaNativeAd)
    func nativeAdDidLogClick(_ nativeAd: NovaNativeAd, clickAreaName: String)
    func nativeAdDidFinishRender(_ nativeAd: NovaNativeAd)
}
