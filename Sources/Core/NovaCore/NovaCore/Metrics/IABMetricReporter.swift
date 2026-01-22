//import OMSDK_Static_Newsbreak1
//import OMID
@_implementationOnly import OMSDK_Newsbreak1
import UIKit

class IABMetricReporter {
    private struct Constants {
        static let resourceBundleName = "NBResourceBundle.bundle"
        static let jsFileName = "omsdk-v1"

        static let partnerName = "Newsbreak"
    }

    private var session: OMIDNewsbreak1AdSession?
    private var impressionReported: Bool = false
    private var loadedReported: Bool = false

    private class VideoEventRecord {
        var didReportStart: Bool = false
        var didReportFirstQuartile: Bool = false
        var didReportMidpoint: Bool = false
        var didReportThirdQuartile: Bool = false
        var didReportComplete: Bool = false
    }

    private var adEvents: OMIDNewsbreak1AdEvents?
    private var mediaEvents: OMIDNewsbreak1MediaEvents?
    private var videoRecord: VideoEventRecord?

    private let omidJS: String? = {
        let url =
            Bundle(for: IABMetricReporter.self).url(forResource: "NBResourceBundle", withExtension: "bundle")
            ?? Bundle.main.bundleURL
        //let bundlePath = (Bundle.main.resourcePath! as NSString).appendingPathComponent(Constants.resourceBundleName)
        let bundle = Bundle(url: url)
        if let jsFilePath = bundle?.path(forResource: Constants.jsFileName, ofType: "js"),
            let contents = try? String(contentsOfFile: jsFilePath)
        {
            return contents
        } else {
            return ""
        }
    }()

    init() {
        if !OMIDNewsbreak1SDK.shared.isActive {
            OMIDNewsbreak1SDK.shared.activate()
        }
    }

    func startSession(
        adView: UIView,
        contentUrl: String,
        thirdPartyViewTrackingUrls: [String],
        hasVideo: Bool
    ) {
        guard OMIDNewsbreak1SDK.shared.isActive else {
            assertionFailure("failed to active IAB SDK")
            return
        }

        guard
            let partner = OMIDNewsbreak1Partner(
                name: Constants.partnerName,
                versionString: "1.0")
        else {
            assertionFailure("failed to create partner")
            return
        }

        var resources: [OMIDNewsbreak1VerificationScriptResource] = []
        for thirdPartyViewTrackingUrl in thirdPartyViewTrackingUrls {
            if let resourceURL = URL(string: thirdPartyViewTrackingUrl),
                let scriptResource = OMIDNewsbreak1VerificationScriptResource(
                    url: resourceURL, vendorKey: "iabtechlab.com-omid", parameters: "iabtechlab-Newsbreak1")
            {
                //DebugLogging.info(.ads, "iAB tracking resource created, resourceURL = \(resourceURL)")
                resources.append(scriptResource)
            }
        }

        do {
            let context = try OMIDNewsbreak1AdSessionContext(
                partner: partner,
                script: self.omidJS ?? "",
                resources: resources,
                contentUrl: contentUrl,
                customReferenceIdentifier: nil)

            let configuration = try OMIDNewsbreak1AdSessionConfiguration(
                creativeType: .nativeDisplay,
                impressionType: .viewable,
                impressionOwner: .nativeOwner,
                mediaEventsOwner: hasVideo ? .nativeOwner : .noneOwner,
                isolateVerificationScripts: true)

            let session = try OMIDNewsbreak1AdSession(configuration: configuration, adSessionContext: context)
            session.mainAdView = adView
            self.session = session

            adEvents = try OMIDNewsbreak1AdEvents(adSession: session)

            if hasVideo {
                videoRecord = VideoEventRecord()
                mediaEvents = try OMIDNewsbreak1MediaEvents(adSession: session)
            }

            self.session?.start()
        } catch {
            assertionFailure("IAB SDK error=\(error)")
        }
    }

    func logImpression() {
        guard OMIDNewsbreak1SDK.shared.isActive else {
            assertionFailure("failed to active IAB SDK")
            return
        }

        guard let adEvents else {
            assertionFailure("unexpected nil event")
            return
        }

        guard !impressionReported else { return }

        do {
            try adEvents.impressionOccurred()
            impressionReported = true
            //DebugLogging.info(.ads, "iAB SDK impression reported")
        } catch {
            assertionFailure("IAB SDK error=\(error)")
        }
    }

    func logLoaded() {
        guard OMIDNewsbreak1SDK.shared.isActive else {
            assertionFailure("failed to active IAB SDK")
            return
        }

        guard let adEvents else {
            assertionFailure("unexpected nil event")
            return
        }

        guard !loadedReported else { return }

        do {
            try adEvents.loaded()
            loadedReported = true
            //DebugLogging.info(.ads, "iAB SDK loaded reported")
        } catch {
            assertionFailure("IAB SDK error=\(error)")
        }
    }

    func stopSession() {
        videoRecord = nil
        mediaEvents = nil
        adEvents = nil
        session?.finish()
        session = nil
    }

    func logVideoStart(duration: CGFloat, volume: CGFloat) {
        guard let videoRecord, let mediaEvents else {
            assertionFailure("unexpected nil videoRecord")
            return
        }
        guard !videoRecord.didReportStart else { return }
        mediaEvents.start(withDuration: duration, mediaPlayerVolume: volume)
        videoRecord.didReportStart = true
        //DebugLogging.info(.ads, "iAB SDK video start reported")
    }

    func logVideoProgress(percentage: Double) {
        guard let videoRecord, let mediaEvents else {
            assertionFailure("unexpected nil videoRecord")
            return
        }
        if !videoRecord.didReportFirstQuartile && percentage >= 0.25 {
            mediaEvents.firstQuartile()
            videoRecord.didReportFirstQuartile = true
            //DebugLogging.info(.ads, "iAB SDK video firstQuartile reported")
        } else if !videoRecord.didReportMidpoint && percentage >= 0.5 {
            mediaEvents.midpoint()
            videoRecord.didReportMidpoint = true
            //DebugLogging.info(.ads, "iAB SDK video midpoint reported")
        } else if !videoRecord.didReportThirdQuartile && percentage >= 0.75 {
            mediaEvents.thirdQuartile()
            videoRecord.didReportThirdQuartile = true
            //DebugLogging.info(.ads, "iAB SDK video thirdQuartile reported")
        } else if !videoRecord.didReportComplete && percentage >= 1.0 {
            mediaEvents.complete()
            videoRecord.didReportComplete = true
            //DebugLogging.info(.ads, "iAB SDK video complete reported")
        }
    }

    func logVideoPause() {
        guard let mediaEvents else {
            assertionFailure("unexpected nil videoRecord")
            return
        }
        mediaEvents.pause()
        //DebugLogging.info(.ads, "iAB SDK video pause reported")
    }

    func logVideoResume() {
        guard let mediaEvents else {
            assertionFailure("unexpected nil videoRecord")
            return
        }
        mediaEvents.resume()
        //DebugLogging.info(.ads, "iAB SDK video resume reported")
    }

    func logVideoVolumeChange(to volume: CGFloat) {
        guard let mediaEvents else {
            //assertionFailure("unexpected nil videoRecord")
            return
        }
        mediaEvents.volumeChange(to: volume)
        //DebugLogging.info(.ads, "iAB SDK video volumeChange reported")
    }
}
