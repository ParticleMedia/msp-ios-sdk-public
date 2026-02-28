@_implementationOnly import MSPSnapKit
import MSPiOSCore
import UIKit

class DebugAdContainerViewController: UIViewController {
    private let adView: UIView
    private let preferredSize: CGSize
    private let nativeAd: NativeAd?
    private var observedVideoController: (any VideoController)?
    private var hasTriggeredSKOverlay = false

    init(adView: UIView, preferredSize: CGSize, nativeAd: NativeAd? = nil) {
        self.adView = adView
        self.preferredSize = preferredSize
        self.nativeAd = nativeAd
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupAdView()
        bindVideoControllerForSKOverlayIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissSKOverlayIfNeeded()
        observedVideoController?.delegate = nil
    }

    private func setupAdView() {
        view.addSubview(adView)
        adView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(preferredSize.width)
            make.height.equalTo(preferredSize.height)
        }
    }

    private var supportsSKOverlay: Bool {
        skOverlayControllableAd?.canAutoShowSKOverlayOnVideoPlayback == true
    }

    private var skOverlayControllableAd: (any NativeAdSKOverlayControllable)? {
        nativeAd as? any NativeAdSKOverlayControllable
    }

    private func bindVideoControllerForSKOverlayIfNeeded() {
        guard supportsSKOverlay,
            let videoController = nativeAd?.mediaContainer?.videoController
        else {
            return
        }
        observedVideoController = videoController
        videoController.delegate = self
    }

    private func dismissSKOverlayIfNeeded() {
        skOverlayControllableAd?.dismissSKOverlay()
    }
}

extension DebugAdContainerViewController: VideoControllerDelegate {
    func videoController(
        _ controller: VideoController?,
        loopCount: Int,
        didUpdateProgress currentTime: TimeInterval,
        videoLength: TimeInterval
    ) {
        guard supportsSKOverlay, !hasTriggeredSKOverlay, currentTime > 0 else {
            return
        }
        hasTriggeredSKOverlay = true
        skOverlayControllableAd?.showSKOverlayIfPossible(
            scene: view.window?.windowScene,
            position: .bottomRaised,
            userDismissible: false
        )
    }
}
