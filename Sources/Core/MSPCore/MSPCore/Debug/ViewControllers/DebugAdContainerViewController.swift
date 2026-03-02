@_implementationOnly import MSPSnapKit
import MSPiOSCore
import StoreKit
import UIKit

class DebugAdContainerViewController: UIViewController {
    private let adView: UIView
    private let preferredSize: CGSize
    private let nativeAd: NativeAd?
    private var observedVideoController: (any VideoController)?
    private var observedImageController: (any ImageController)?
    private var isSKOverlayShowing = false

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
        bindMediaControllersForSKOverlayIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissSKOverlayIfNeeded()
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
        skOverlayControllableAd != nil
    }

    private var skOverlayControllableAd: (any NativeAdSKOverlayControllable)? {
        nativeAd as? any NativeAdSKOverlayControllable
    }

    private func bindMediaControllersForSKOverlayIfNeeded() {
        guard supportsSKOverlay else { return }

        if let videoController = nativeAd?.mediaContainer?.videoController {
            observedVideoController = videoController
            videoController.delegate = self
        }

        if let imageController = nativeAd?.mediaContainer?.imageController {
            observedImageController = imageController
            imageController.delegate = self
        }
    }

    private func dismissSKOverlayIfNeeded() {
        skOverlayControllableAd?.dismissSKOverlay()
        isSKOverlayShowing = false
    }

    private func triggerSKOverlayIfNeeded() {
        guard supportsSKOverlay, !isSKOverlayShowing else { return }
        isSKOverlayShowing = true
        skOverlayControllableAd?.showSKOverlayIfPossible(
            scene: view.window?.windowScene,
            position: .bottomRaised,
            userDismissible: false,
            overlayDelegate: self
        )
    }
}

extension DebugAdContainerViewController: VideoControllerDelegate {
    func videoController(
        _ controller: VideoController?,
        loopCount: Int,
        didUpdateProgress currentTime: TimeInterval,
        videoLength: TimeInterval
    ) {}

    func videoControllerDidChangeToPlay(_ controller: VideoController?) {
        triggerSKOverlayIfNeeded()
    }
}

extension DebugAdContainerViewController: ImageControllerDelegate {
    func imageControllerDidStartDisplaying(_ controller: ImageController?) {
        triggerSKOverlayIfNeeded()
    }
}

extension DebugAdContainerViewController: SKOverlayDelegate {
    func storeOverlayDidFailToLoad(_ overlay: SKOverlay, error: any Error) {
        isSKOverlayShowing = false
    }

    func storeOverlayDidFinishPresentation(_ overlay: SKOverlay, transitionContext: SKOverlay.TransitionContext) {
        isSKOverlayShowing = true
    }

    func storeOverlayWillStartDismissal(_ overlay: SKOverlay, transitionContext: SKOverlay.TransitionContext) {
        isSKOverlayShowing = false
    }

    func storeOverlayDidFinishDismissal(_ overlay: SKOverlay, transitionContext: SKOverlay.TransitionContext) {
        isSKOverlayShowing = false
    }
}
