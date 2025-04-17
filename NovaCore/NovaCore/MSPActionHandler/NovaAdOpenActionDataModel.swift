import Foundation

public struct NovaAdOpenActionDataModel {
    let url: URL
    let adId: String
    let requestId: String
    let adUnitId: String
    let clickTime: Double
    let videoInfo: NovaNativeAdVideoInfo?
    let encryptedAdToken: String
    let appStoreId: String?

    public init(url: URL, clickTime: Double, ad: NovaBaseAd) {
        self.url = url
        self.clickTime = clickTime
        self.adId = ad.adId
        self.requestId = ad.requestId
        self.adUnitId = ad.adUnitId
        self.encryptedAdToken = ad.encryptedAdToken
        self.videoInfo = (ad as? NovaNativeAdItem)?.videoInfo
        if ad is NovaNativeAdItem {
            self.appStoreId = (ad as? NovaNativeAdItem)?.appStoreId
        } else {
            self.appStoreId = (ad as? NovaAppOpenAd)?.appStoreId
        }
    }
}
