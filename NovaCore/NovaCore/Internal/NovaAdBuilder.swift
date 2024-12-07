import Foundation

public enum NovaAdBuilder {
    public static func buildNativeAd(
        adItem: AdItem,
        adUnitId: String,
        eCPMInDollar: Decimal,
        isParallax: Bool = false
    ) -> NovaNativeAdItem {
        let launchOption: NovaAdLaunchOption
        if  let realLaunchOption = NovaAdLaunchOption(rawValue: adItem.creative.launchOption ?? "") {
            launchOption = realLaunchOption
        } else {
            assertionFailure("Unsupported launch option")
            // Use browser as default option
            launchOption = .launchBrowser
        }

        let ctrUrlStr = transformedUrlStr(adItem.creative.ctrUrl)
        let ctrUrl = URL(string: ctrUrlStr)

        let thirdPartyViewTrackingUrls = adItem.creative.thirdPartyViewTrackingUrls?.map {
            transformedUrlStr($0)
        } ?? []
        let thirdPartyImpressionTrackingUrls = adItem.creative.thirdPartyImpressionTrackingUrls?.map {
            transformedUrlStr($0)
        } ?? []
        let thirdPartyClickTrackingUrls = adItem.creative.thirdPartyClickTrackingUrls?.map {
            transformedUrlStr($0)
        } ?? []

        return NovaNativeAdItem(
            adUnitId: adUnitId,
            requestId: adItem.requestId,
            adId: adItem.adId,
            adSetId: adItem.adsetId,
            eCPMInDollar: eCPMInDollar,
            headline: adItem.creative.headline,
            body: adItem.creative.body,
            callToAction: adItem.creative.callToAction,
            creativeType: NovaCreativeType(rawValue: adItem.creative.creativeType ?? ""),
            imageUrlStr: adItem.creative.imageUrl,
            isImageClickable: adItem.creative.isImageClickable ?? false,
            videoInfo: buildVideoInfo(adItem.creative.videoItem, adId: adItem.adId),
            advertiser: adItem.creative.advertiser,
            iconUrlStr: adItem.creative.iconUrl,
            addOnItem: buildInteractiveBanner(adItem.creative.addonItem),
            ctrUrl: ctrUrl,
            launchOption: launchOption,
            thirdPartyViewTrackingUrls: thirdPartyViewTrackingUrls,
            thirdPartyImpressionTrackingUrls: thirdPartyImpressionTrackingUrls,
            thirdPartyClickTrackingUrls: thirdPartyClickTrackingUrls,
            priceInDollar: adItem.price,
            encryptedAdToken: adItem.encryptedAdToken,
            isParallax: isParallax)
    }
    
    public static func buildAppOpenAds(adItems: [AdItem], adUnitId: String) -> [NovaAppOpenAd] {
        return adItems.map { adItem in
            let ctrUrlStr = transformedUrlStr(adItem.creative.ctrUrl)
            let ctrUrl = URL(string: ctrUrlStr)
            let videoInfo = NovaAdBuilder.buildVideoInfo(adItem.creative.videoItem, adId: adItem.adId)

            let thirdPartyViewTrackingUrls = adItem.creative.thirdPartyViewTrackingUrls?.map {
                transformedUrlStr($0)
            } ?? []
            let thirdPartyImpressionTrackingUrls = adItem.creative.thirdPartyImpressionTrackingUrls?.map {
                transformedUrlStr($0)
            } ?? []
            let thirdPartyClickTrackingUrls = adItem.creative.thirdPartyClickTrackingUrls?.map {
                transformedUrlStr($0)
            } ?? []

            let startTimeInMs = Double(adItem.startTimeMs ?? "")
            let expirationTimeInMs = Double(adItem.expirationMs ?? "")
            let isImageClickable = adItem.creative.isImageClickable ?? true
            let isVerticalImage = adItem.creative.isVerticalImage ?? false

            return NovaAppOpenAd(
                adUnitId: adUnitId,
                requestId: adItem.requestId,
                adId: adItem.adId,
                adSetId: adItem.adsetId,
                imageUrlStr: adItem.creative.imageUrl,
                ctrUrl: ctrUrl,
                headline: adItem.creative.headline,
                body: adItem.creative.body,
                callToAction: adItem.creative.callToAction,
                advertiser: adItem.creative.advertiser,
                creativeType: NovaCreativeType(rawValue: adItem.creative.creativeType ?? ""),
                videoInfo: videoInfo,
                isImageClickable: isImageClickable,
                isVerticalImage: isVerticalImage,
                iconUrl: adItem.creative.iconUrl,
                launchOption: adItem.creative.launchOption,
                thirdPartyViewTrackingUrls: thirdPartyViewTrackingUrls,
                thirdPartyImpressionTrackingUrls: thirdPartyImpressionTrackingUrls,
                thirdPartyClickTrackingUrls: thirdPartyClickTrackingUrls,
                priceInDollar: adItem.price,
                startTimeInMs: startTimeInMs,
                expirationTimeInMs: expirationTimeInMs,
                encryptedAdToken: adItem.encryptedAdToken)
        }
    }

   
    
}

// MARK: - Private methods

private extension NovaAdBuilder {
    static func transformedUrlStr(_ urlStr: String) -> String {
        return NovaAdUrlTransformer.replaceMacro(in: urlStr)
    }

    static func buildVideoInfo(_ videoItem: VideoItem?, adId: String) -> NovaNativeAdVideoInfo? {
        guard let videoItem = videoItem, let videoUrlStr = videoItem.videoUrl else { return nil }

        return NovaNativeAdVideoInfo(
            adId: adId,
            coverUrlStr: videoItem.coverUrl,
            videoUrlStr: videoUrlStr,
            isVertical: videoItem.isVertical ?? false,
            isVideoClickable: videoItem.isVideoClickable ?? false,
            isPlayOnLandingPage: videoItem.isPlayOnLandingPage ?? false,
            isAuto: videoItem.isPlayAutomatically ?? true,
            isMute: videoItem.isMute ?? true,
            isLoop: videoItem.isLoop ?? true)
    }
    
    static func buildInteractiveBanner(_ addOnItem: AddOnItem?) -> NovaNativeAdInteractiveBanner? {
        guard let type = addOnItem?.type,
              let type = InteractiveBannerType(rawValue: type),
              let url = addOnItem?.imageUrl,
              let imageUrl = URL(string: url),
              let displayTime = addOnItem?.displayTime
        else {
            return nil
        }
        return NovaNativeAdInteractiveBanner(type: type, imageUrl: imageUrl, displayTime: .milliseconds(displayTime))
    }
}

