//
//  NovaAdsVideoLandingWebViewController.swift
//  NovaAdapter
//
//  Created by Huanzhi Zhang on 6/19/24.
//

import Foundation
import UIKit

public class NovaAdsVideoLandingWebViewController: UIViewController {
    private let model: NovaAdOpenActionDataModel
    private var containerGesture: UIPanGestureRecognizer?
    
    private let statusBarView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(light: NovaColorPalettes.White, dark: NovaColorPalettes.Gray.tint900)
        return view
    }()

    private var videoView: NovaNativeAdVideoView?
    
    lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()
    
    private var containerViewHeightConstraint: NSLayoutConstraint?
    private var initialHeight: CGFloat!
    private var currentHeight: CGFloat!
    private var nestedViewController: NovaAdsLandingWebViewController?
    private var translationYWhenScrollOnTop: CGFloat?
    private var isWebViewOnTop: Bool!
    
    // MARK: - Life Cycle
    
    public init(model: NovaAdOpenActionDataModel) {
        self.model = model
        
        super.init(nibName: nil, bundle: nil)
        videoView = {
            let videoView = NovaNativeAdVideoView(inLandingPage: true)
            videoView.didTapCloseButtonCallback = {
                self.dismiss(animated: true)
            }
            return videoView
        }()
        let navigationModel = NovaWebViewNavigationViewModel(
            includingStatusBar: false,
            title: nil,
            hideLeftButton: true,
            leftButtonIcon: .crossFilled,
            leftButtonTapActionHandler: { [weak self] in
                self?.dismiss(animated: true)
            },
            rightButtonIcon: nil,
            rightButtonTapActionHandler: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        self.nestedViewController = NovaAdsLandingWebViewController(
            dataModel: self.model,
            navigationModel: navigationModel,
            navigationHeight: 40
        )
        self.nestedViewController?.initialLoadDidRedirectTo = { [weak self] _ in
            self?.bindContainerToTop()
        }
        self.nestedViewController?.didGoBackToInitialLoad = { [weak self] _ in
            self?.backToInitialLoad()
        }
        self.nestedViewController?.webViewDidScroll = { [weak self] scrollView in
            guard let self, self.isWebViewOnTop else {
                return
            }
            let translationY = scrollView.panGestureRecognizer.translation(in: self.view).y

            if scrollView.contentOffset.y <= 0 {
                if self.translationYWhenScrollOnTop == nil {
                    self.translationYWhenScrollOnTop = translationY
                }
                let maxContainerHeight = self.view.bounds.height - view.safeAreaInsets.top
                let newContainerHeight = maxContainerHeight - (translationY - self.translationYWhenScrollOnTop!)
                let finalHeight: CGFloat? = {
                    switch newContainerHeight {
                    case ..<self.initialHeight:
                        return self.initialHeight
                    case self.initialHeight..<maxContainerHeight:
                        return newContainerHeight
                    case maxContainerHeight...:
                        return maxContainerHeight
                    default:
                        //DebugLogging.info(.ads, "New container height is: \(newContainerHeight), which is out of range")
                        return nil
                    }
                }()
                if let finalHeight {
                    self.containerViewHeightConstraint?.constant = finalHeight
                    self.view.layoutIfNeeded()
                }
            }
        }
        self.nestedViewController?.webViewDidEndDragging = { [weak self] scrollView in
            guard let self else {
                return
            }
            let translationY = scrollView.panGestureRecognizer.translation(in: self.view).y
            let offsetY = scrollView.contentOffset.y
            if translationY >= 0 && offsetY <= 0 {
                self.animateContainerHeight(self.initialHeight, isOnTop: false)
            }
            
            self.translationYWhenScrollOnTop = nil
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupPanGesture()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let videoInfo = model.videoInfo {
            videoView?.config(videoInfo: videoInfo, encryptedAdToken: model.encryptedAdToken, iabReporter: nil)
        }
        //videoView?.handleVideoOnScreen()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        videoView?.handleVideoOnScreen()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let videoView {
            videoView.handleVideoOffScreen()
        }
    }
    
    // MARK: - Private
    
    private func setupViews() {
        // Do any additional setup after loading the view.
        view.addSubview(statusBarView)
        statusBarView.translatesAutoresizingMaskIntoConstraints = false
        videoView?.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        nestedViewController?.view.translatesAutoresizingMaskIntoConstraints = false

        // statusBarView constraints
        NSLayoutConstraint.activate([
            statusBarView.topAnchor.constraint(equalTo: view.topAnchor),
            statusBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor)
        ])

        // Setting the video view’s height based on whether model.videoInfo is present
        let topVideoHeight = model.videoInfo != nil ? view.bounds.width / AdsMediaConstants.defaultAspectRatio : 0

        // videoView constraints
        if let videoView = videoView {
            view.addSubview(videoView)
            NSLayoutConstraint.activate([
                videoView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
                videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                videoView.heightAnchor.constraint(equalToConstant: topVideoHeight)
            ])
        }

        // Calculating initialHeight and currentHeight
        initialHeight = view.bounds.height - topVideoHeight - (UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 0)
        currentHeight = initialHeight
        isWebViewOnTop = topVideoHeight == 0

        // containerView constraints
        view.addSubview(containerView)
        containerViewHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: initialHeight)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerViewHeightConstraint!
        ])

        // Adding and setting up nestedViewController within containerView
        if let nestedViewController = nestedViewController {
            addChild(nestedViewController)
            containerView.addSubview(nestedViewController.view)
            nestedViewController.didMove(toParent: self)
            
            NSLayoutConstraint.activate([
                nestedViewController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
                nestedViewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                nestedViewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                nestedViewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
    }
    
    private func setupPanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanAction(gesture:)))
        containerGesture = panGesture
        panGesture.delaysTouchesBegan = false
        panGesture.delaysTouchesEnded = false
        containerView.addGestureRecognizer(panGesture)
        self.nestedViewController?.changeWebViewTappable(isEnable: false)
    }
    
    @objc private func handlePanAction(gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let isDraggingDown = translation.y > 0
        
        let maxContainerHeight = view.bounds.height - view.safeAreaInsets.top
        let newHeight = currentHeight - translation.y
        
        switch gesture.state {
        case .changed:
            if initialHeight <= newHeight && newHeight <= maxContainerHeight {
                containerViewHeightConstraint?.constant = newHeight
                view.layoutIfNeeded()
            } else if newHeight < initialHeight {
                containerViewHeightConstraint?.constant = initialHeight
                view.layoutIfNeeded()
            } else {
                containerViewHeightConstraint?.constant = maxContainerHeight
                self.nestedViewController?.setWebView(offset: CGPoint(x: 0, y: newHeight - maxContainerHeight))
                view.layoutIfNeeded()
            }
        case .ended:
            let newHeightExceedHalf = newHeight > initialHeight + (maxContainerHeight - initialHeight) / 2
            if newHeightExceedHalf {
                animateContainerHeight(maxContainerHeight, isOnTop: true)
            } else {
                animateContainerHeight(initialHeight, isOnTop: false)
            }
        default:
            break
        }
    }
    
    private func animateContainerHeight(_ height: CGFloat, isOnTop: Bool) {
        self.nestedViewController?.changeWebViewTappable(isEnable: isOnTop)
        UIView.animate(withDuration: 0.3) {
            self.containerViewHeightConstraint?.constant = height
            self.view.layoutIfNeeded()
            self.nestedViewController?.changeLeftButtonOnNavigation(isHidden: !isOnTop)
        }
        self.currentHeight = height
        self.isWebViewOnTop = isOnTop
    }
    
    private func bindContainerToTop() {
        let height = view.bounds.height - view.safeAreaInsets.top
        if let containerGesture {
            containerGesture.isEnabled = false
        }
        containerViewHeightConstraint?.constant = height
        view.layoutIfNeeded()
        nestedViewController?.changeLeftButtonOnNavigation(isHidden: false)
    }
    
    private func backToInitialLoad() {
        if let containerGesture {
            containerGesture.isEnabled = true
        }
        let maxHeight = view.bounds.height - view.safeAreaInsets.top
        containerViewHeightConstraint?.constant = self.currentHeight
        view.layoutIfNeeded()
        nestedViewController?.changeLeftButtonOnNavigation(isHidden: self.currentHeight != maxHeight)
    }
}

private extension NovaAdsVideoLandingWebViewController {
    func navigationViewDidClickBackButton() {
        dismiss(animated: true)
    }
}
