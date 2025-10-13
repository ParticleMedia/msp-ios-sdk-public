import Foundation

// import shared
import MSPiOSCore
import NovaCore

public class NovaNativeAd: NativeAd {
    // MARK: Public

    override public var mediaContainer: (any AdMediaContainer)? {
        return mediaContainerAdapter
    }

    public private(set) var priceInDollar: Double?

    var nativeAdItem: NovaNativeAdItem? {
        didSet {
            if let mediaContent = nativeAdItem?.mediaContent {
                mediaContainerAdapter = NovaAdMediaContainerAdapter(mediaContent: mediaContent)
            }

            adInfo[MSPConstants.AD_INFO_NOVA_AD_ID] = nativeAdItem?.novaAdReportContext.adId
            adInfo[MSPConstants.AD_INFO_NOVA_AD_SET_ID] = nativeAdItem?.novaAdReportContext.adSetId
            adInfo[MSPConstants.AD_INFO_NOVA_AD_REQUEST_ID] = nativeAdItem?.novaAdReportContext.adRequestId
            adInfo[MSPConstants.AD_INFO_NOVA_AD_ENCRYPTED_TOKEN] = nativeAdItem?.novaAdReportContext.encryptedToken
        }
    }

    override public func isValid() -> Bool {
        return nativeAdItem != nil
    }
    
    func setPriceInDollar(_ priceInDollar: Double?) {
        self.priceInDollar = priceInDollar
    }

    // MARK: Private

    private var mediaContainerAdapter: NovaAdMediaContainerAdapter?
}
