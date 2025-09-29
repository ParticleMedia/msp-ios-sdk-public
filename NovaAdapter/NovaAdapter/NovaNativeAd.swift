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
    
    public var novaAdReportContext: NovaAdReportContext? {
        return nativeAdItem?.novaAdReportContext
    }

    var nativeAdItem: NovaNativeAdItem? {
        didSet {
            if let mediaContent = nativeAdItem?.mediaContent {
                mediaContainerAdapter = NovaAdMediaContainerAdapter(mediaContent: mediaContent)
            }
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
