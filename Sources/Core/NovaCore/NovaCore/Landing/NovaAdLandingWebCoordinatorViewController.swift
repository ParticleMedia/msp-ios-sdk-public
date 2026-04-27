//
//  NovaAdLandingWebCoordinatorViewController.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/8/12.
//

import Foundation
@_implementationOnly import MSPSnapKit
import UIKit

class NovaAdLandingWebCoordinatorViewController: UIViewController {
    struct LandingVideoContext {
        let initialFrame: CGRect
        let videoMediaModel: NovaAdVideoMediaModel
        let actionContext: NovaAdMediaActionContext?
        // TODO: lsy, 之前需要在这里面控制之前 video 的播放暂停逻辑，因为现在都是 normal view 来控制的，我感觉不需要了就删了，需要验证一下

        init(
            initialFrame: CGRect,
            videoMediaModel: NovaAdVideoMediaModel,
            actionContext: NovaAdMediaActionContext?
        ) {
            self.initialFrame = initialFrame
            self.videoMediaModel = videoMediaModel
            self.actionContext = actionContext
        }
    }

    enum NestedVCDetentStyle {
        case fullscreen
        case partOfScreen(height: Double, landingVideoContext: LandingVideoContext)
    }

    private let detentStyle: NestedVCDetentStyle
    private var containerViewController: NovaAdLandingWebContainerViewController? = nil
    private var nestedLandingWebViewController: NovaAdLandingWebContentViewController? = nil

    // video animation
    private var videoViewLeadingConstraint: MSPSnapKit.Constraint?
    private var videoViewTopConstraint: MSPSnapKit.Constraint?
    private var videoViewWidthConstraint: MSPSnapKit.Constraint?
    private var videoViewHeightConstraint: MSPSnapKit.Constraint?

    // status bar inset bootstrap flag: set once statusBarHeight is first observed as > 0
    private var statusBarInsetBootstrapped = false

    // container vc animation
    private var containerVCHeight: MSPSnapKit.Constraint?
    private var containerVCBottom: MSPSnapKit.Constraint?
    private var containerCurrentHeight: Double = 0
    private var containerGesture: UIPanGestureRecognizer?
    private var translationYWhenWebFirstlyScrollToTop: CGFloat?

    private let statusBarView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(light: NovaColorPalettes.White, dark: NovaColorPalettes.Gray.tint900)
        return view
    }()

    private lazy var videoView: NovaAdVideoView? = { () -> NovaAdVideoView? in
        guard case .partOfScreen(_, let landingVideoContext) = detentStyle else {
            assertionFailure("media view will only be used in half screen detent style")
            return nil
        }
        let videoView = NovaAdVideoView(with: .landingPage)
        videoView.delegate = self
        videoView
            .config(
                with: landingVideoContext.videoMediaModel,
                actionContext: landingVideoContext.actionContext,
                iabReporter: nil
            )

        // NOTE: without this line, the player in the video view may cause the animation shown incorrectly
        videoView.clipsToBounds = true
        return videoView
    }()

    private var containerMaxHeight: Double {
        view.bounds.height - view.safeAreaInsets.top
    }

    init(webContext: NovaAdsLandingWebContext, detentStyle: NestedVCDetentStyle) {
        self.detentStyle = detentStyle
        super.init(nibName: nil, bundle: nil)
        let nestedLandingWebViewController: NovaAdLandingWebContentViewController = {
            switch detentStyle {
            case .fullscreen:
                return NovaAdLandingWebContentViewController(webContext: webContext)
            case .partOfScreen(let height, landingVideoContext: _):
                let navigationModel = NovaWebViewNavigationViewModel(
                    includingStatusBar: false,
                    title: nil,
                    hideLeftButton: true,
                    leftButtonIcon: UIImage.Nova.crossFilled,
                    leftButtonTapActionHandler: { [weak self] in
                        self?.dismissAndRestoreVideoViewToInitialFrameIfNeeded()
                    },
                    rightButtonIcon: nil,
                    rightButtonTapActionHandler: { [weak self] in
                        self?.dismissAndRestoreVideoViewToInitialFrameIfNeeded()
                    },
                    navigationBarHeight: 40
                )
                let nestedLandingWebViewController = NovaAdLandingWebContentViewController(
                    webContext: webContext,
                    navigationModel: navigationModel
                )
                nestedLandingWebViewController.initialLoadDidRedirectTo = { [weak self] _ in
                    self?.bindContainerToTop()
                }
                nestedLandingWebViewController.didGoBackToInitialLoad = { [weak self] _ in
                    self?.backToInitialLoad()
                }
                nestedLandingWebViewController.webViewDidScroll = { [weak self] scrollView in
                    guard let self, self.containerCurrentHeight == self.containerMaxHeight else {
                        return
                    }
                    let translationY = scrollView.panGestureRecognizer.translation(in: self.view).y

                    if self.containerCurrentHeight == self.containerMaxHeight && scrollView.contentOffset.y <= 0 {
                        if self.translationYWhenWebFirstlyScrollToTop == nil {
                            self.translationYWhenWebFirstlyScrollToTop = translationY
                        }
                        let newContainerHeight =
                            containerMaxHeight - (translationY - self.translationYWhenWebFirstlyScrollToTop!)
                        let finalHeight: CGFloat? = {
                            switch newContainerHeight {
                            case ..<height:
                                return height
                            case height..<self.containerMaxHeight:
                                return newContainerHeight
                            case self.containerMaxHeight...:
                                return self.containerMaxHeight
                            default:
                                DebugLogger.ui.error("New container height is out of range: \(newContainerHeight)")
                                return nil
                            }
                        }()
                        if let finalHeight {
                            self.containerVCHeight?.update(offset: finalHeight)
                            self.view.layoutIfNeeded()
                        }
                    }
                }
                nestedLandingWebViewController.webViewDidEndDragging = { [weak self] scrollView, willDecelerate in
                    guard let self else {
                        return
                    }
                    let translationY = scrollView.panGestureRecognizer.translation(in: self.view).y
                    let offsetY = scrollView.contentOffset.y
                    if translationY >= 0 && offsetY <= 0 {
                        self.animateContainer(to: height)
                    }

                    if !willDecelerate {
                        self.translationYWhenWebFirstlyScrollToTop = nil
                    }
                }
                nestedLandingWebViewController.webViewDidEndDecelerating = { [weak self] scrollView in
                    guard let self else {
                        return
                    }
                    self.translationYWhenWebFirstlyScrollToTop = nil
                }
                return nestedLandingWebViewController
            }
        }()
        self.nestedLandingWebViewController = nestedLandingWebViewController
        self.containerViewController = NovaAdLandingWebContainerViewController(
            nestedViewController: nestedLandingWebViewController
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        guard let containerViewController else {
            assertionFailure("Impossible")
            return
        }
        containerViewController.willMove(toParent: self)
        addChild(containerViewController)
        view.addSubview(containerViewController.view)
        containerViewController.didMove(toParent: self)

        view.addSubview(statusBarView)
        statusBarView.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview()
            // Pin to safe area so height matches real status bar (novaSafeAreaInsets can be 0 on iPad at setup).
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top)
        }
        // Pre-apply status bar compensation before first layout.  On iPadOS 26, safeAreaInsets.top
        // is 0 for fullscreen-presented VCs even when the status bar overlays content.
        // UIApplication.shared.connectedScenes is used because view.window is still nil in viewDidLoad.
        // viewSafeAreaInsetsDidChange will self-correct this to 0 on older OS where the system
        // already provides the correct safeAreaInsets.top.
        adjustAdditionalSafeAreaInsetsForStatusBarIfNeeded()
        switch detentStyle {
        case .fullscreen:
            containerViewController.view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            containerCurrentHeight = view.frame.height
        case let .partOfScreen(height: height, landingVideoContext: landingVideoContext):
            containerViewController.view.snp.makeConstraints { make in
                make.horizontalEdges.equalToSuperview()
                containerVCBottom = make.bottom.equalToSuperview().offset(height).constraint
                containerVCHeight = make.height.equalTo(height).constraint
            }
            containerCurrentHeight = height

            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanAction(gesture:)))
            containerGesture = panGesture
            panGesture.delaysTouchesBegan = false
            panGesture.delaysTouchesEnded = false
            containerViewController.view
                .addGestureRecognizer(
                    UIPanGestureRecognizer(target: self, action: #selector(handlePanAction(gesture:)))
                )
            nestedLandingWebViewController?.changeWebViewTappable(isEnable: false)
            if let videoView {
                view.insertSubview(videoView, at: 0)
                videoView.snp.makeConstraints { make in
                    videoViewTopConstraint =
                        make.top
                        .equalToSuperview()
                        .offset(landingVideoContext.initialFrame.origin.y).constraint
                    videoViewLeadingConstraint =
                        make.leading
                        .equalToSuperview()
                        .offset(landingVideoContext.initialFrame.origin.x).constraint
                    videoViewWidthConstraint =
                        make.width.equalTo(landingVideoContext.initialFrame.size.width).constraint
                    videoViewHeightConstraint =
                        make.height
                        .equalTo(landingVideoContext.initialFrame.size.height).constraint
                }
                view.layoutIfNeeded()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        switch detentStyle {
        case .fullscreen:
            break
        case .partOfScreen(let height, _):
            videoView?.play(with: .continueFromLast)
            UIView.animate(withDuration: 0.3) { [weak self] in
                guard let self else { return }
                let topInset = self.view.safeAreaInsets.top
                self.videoViewTopConstraint?.update(offset: topInset)
                self.videoViewLeadingConstraint?.update(offset: 0)
                self.videoViewWidthConstraint?.update(offset: self.view.frame.width)
                self.videoViewHeightConstraint?.update(
                    offset: self.view.frame.height - topInset - height)
                self.view.layoutIfNeeded()
            } completion: { [weak self] _ in
                self?.videoView?.toggleAllSubviewVisibilityAndRecover(after: 3.0)
            }

            UIView.animate(withDuration: 0.3, delay: 0.3) { [weak self] in
                self?.containerVCBottom?.update(offset: 0)
                self?.view.layoutIfNeeded()
            }
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        adjustAdditionalSafeAreaInsetsForStatusBarIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Bootstrap only: on iPadOS 26, safeAreaInsets.top stays 0 so viewSafeAreaInsetsDidChange
        // never fires again after the initial 0-value call.  Retry here until statusBarHeight > 0,
        // then mark as bootstrapped so this becomes a no-op for all subsequent layout passes.
        guard !statusBarInsetBootstrapped else { return }
        let scene = view.window?.windowScene
            ?? UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        guard (scene?.statusBarManager?.statusBarFrame.height ?? 0) > 0 else { return }
        statusBarInsetBootstrapped = true
        adjustAdditionalSafeAreaInsetsForStatusBarIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        switch detentStyle {
        case .fullscreen:
            break
        case .partOfScreen:
            // Keep the shared video state at `.paused` so feed playback can resume from the last position.
            videoView?.pause()
        }
    }

    func present(from vc: UIViewController) {
        switch detentStyle {
        case .fullscreen:
            self.modalPresentationStyle = .fullScreen
            vc.present(self, animated: true)
        case .partOfScreen:
            self.modalPresentationStyle = .overFullScreen
            vc.present(self, animated: false)
        }
    }
}

private extension NovaAdLandingWebCoordinatorViewController {
    // MARK: - Status bar safe area fix

    /// On iPadOS 26+, `safeAreaInsets.top` can be 0 for a fullscreen-presented VC even though the
    /// system status bar overlays the content as a separate system window.  We compensate by adding
    /// `additionalSafeAreaInsets.top` equal to the missing height so that both `statusBarView` and
    /// the child VC's `naviView` are correctly sized and pushed below the status bar.
    func adjustAdditionalSafeAreaInsetsForStatusBarIfNeeded() {
        let windowScene = view.window?.windowScene
            ?? UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        guard let windowScene else { return }
        let statusBarHeight = windowScene.statusBarManager?.statusBarFrame.height ?? 0
        // Subtract our own additionalSafeAreaInsets.top to recover the system-provided value,
        // preventing an infinite feedback loop when the callback re-fires after we set the inset.
        let naturalTop = view.safeAreaInsets.top - additionalSafeAreaInsets.top
        let needed = max(0, statusBarHeight - naturalTop)
        guard additionalSafeAreaInsets.top != needed else { return }
        additionalSafeAreaInsets.top = needed
    }

    // MARK: - Pan gesture

    @objc func handlePanAction(gesture: UIPanGestureRecognizer) {
        guard case let .partOfScreen(height: height, landingVideoContext: _) = detentStyle else {
            return
        }

        let translation = gesture.translation(in: view)
        let newHeight = containerCurrentHeight - translation.y

        switch gesture.state {
        case .changed:
            if height <= newHeight && newHeight <= containerMaxHeight {
                containerVCHeight?.update(offset: newHeight)
                view.layoutIfNeeded()
            } else if newHeight < height {
                containerVCHeight?.update(offset: height)
                view.layoutIfNeeded()
            } else {
                containerVCHeight?.update(offset: containerMaxHeight)
                self.nestedLandingWebViewController?.setWebView(offset: CGPointMake(0, newHeight - containerMaxHeight))
                view.layoutIfNeeded()
            }
        case .ended:
            let newHeightExceedHalf = newHeight > height + (containerMaxHeight - height) / 2
            if newHeightExceedHalf {
                animateContainer(to: containerMaxHeight)
            } else {
                animateContainer(to: height)
            }
        default:
            break
        }
    }

    private func animateContainer(to height: Double) {
        let containerIsOnTop = height == containerMaxHeight
        self.nestedLandingWebViewController?.changeWebViewTappable(isEnable: containerIsOnTop)
        UIView.animate(withDuration: 0.3) {
            self.containerVCHeight?.update(offset: height)
            self.view.layoutIfNeeded()
            self.nestedLandingWebViewController?.changeLeftButtonOnNavigation(isHidden: !containerIsOnTop)
        }
        containerCurrentHeight = height
        if containerIsOnTop {
            videoView?.pause()
        } else {
            videoView?.play(with: .continueFromLast)
        }
    }

    private func bindContainerToTop() {
        let height = view.bounds.height - view.safeAreaInsets.top
        if let containerGesture {
            containerGesture.isEnabled = false
        }
        containerVCHeight?.update(offset: height)
        view.layoutIfNeeded()
        nestedLandingWebViewController?.changeLeftButtonOnNavigation(isHidden: false)
    }

    private func backToInitialLoad() {
        if let containerGesture {
            containerGesture.isEnabled = true
        }
        let maxHeight = view.bounds.height - view.safeAreaInsets.top
        containerVCHeight?.update(offset: self.containerCurrentHeight)
        view.layoutIfNeeded()
        nestedLandingWebViewController?.changeLeftButtonOnNavigation(isHidden: self.containerCurrentHeight != maxHeight)
    }

    private func dismissAndRestoreVideoViewToInitialFrameIfNeeded() {
        switch detentStyle {
        case let .partOfScreen(height: height, landingVideoContext: landingVideoContext):
            UIView.animate(withDuration: 0.1) {
                self.view.backgroundColor = .clear
                self.containerVCBottom?.update(offset: height)
                self.view.layoutIfNeeded()
            }
            UIView.animate(withDuration: 0.3) {
                self.videoView?.snp.remakeConstraints { make in
                    make.top.equalToSuperview().offset(landingVideoContext.initialFrame.origin.y)
                    make.leading.equalToSuperview().offset(landingVideoContext.initialFrame.origin.x)
                    make.size.equalTo(landingVideoContext.initialFrame.size)
                }
                self.view.layoutIfNeeded()
            } completion: { _ in
                self.nestedLandingWebViewController?.logPageClose()
                self.dismiss(animated: false)
            }
        case .fullscreen:
            self.nestedLandingWebViewController?.logPageClose()
            dismiss(animated: true)
        }
    }
}

extension NovaAdLandingWebCoordinatorViewController: NovaAdVideoViewDelegate {
    func videoViewDidTapCloseButton() {
        dismissAndRestoreVideoViewToInitialFrameIfNeeded()
    }
}
