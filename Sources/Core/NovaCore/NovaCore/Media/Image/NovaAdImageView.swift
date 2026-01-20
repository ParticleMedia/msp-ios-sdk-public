//
//  NovaAdImageView.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/7.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
@_implementationOnly import SnapKit

class NovaAdImageView: UIView {
    // MARK: Lifecycle
    
    // Track start time for click events
    private var startTime: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true
        addSubviews(backgroundImageView, contentImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        contentImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    override var contentMode: UIView.ContentMode {
        get { contentImageView.contentMode }
        set { contentImageView.contentMode = newValue }
    }

    func config(
        with mediaModel: NovaAdImageMediaModel,
        actionContext: NovaAdMediaActionContext?,
        completion: @escaping () -> Void,
        showBottomShadow: Bool = false
    ) {
        // Initialize start time for click tracking
        startTime = CACurrentMediaTime()
        
        self.mediaModel = mediaModel
        self.actionContext = actionContext

        if let contentMode = mediaModel.imageContentMode {
            contentImageView.contentMode = contentMode
        }
        contentImageView.novaSetup(with: mediaModel.resource) { _ in
            completion()
        }

        if mediaModel.shouldShowImageBorder {
            contentImageView.layer.borderWidth = 0.5
            contentImageView.layer.borderColor = NovaColorPalettes.Gray.tint200.cgColor
        }
        if mediaModel.isImageClickable {
            isUserInteractionEnabled = true
            setupActionHelper()
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapImage)))
        } else {
            isUserInteractionEnabled = false
        }
        setupBottomShadow(showBottomShadow: showBottomShadow)
    }
    
    private func setupBottomShadow(showBottomShadow: Bool) {
        bottomShadowView?.removeFromSuperview()
        bottomShadowView = nil
        
        guard showBottomShadow else {
            return
        }
        
        // Use fixed shadow configuration
        let config = GradientShadowViewConfig(
            colors: (
                UIColor.clear,
                UIColor.black.withAlphaComponent(0.85)
            ),
            points: (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1.0)),
            shadowColor: .clear,
            shadowOpacity: 0,
            shadowOffset: .zero,
            shadowRadius: 0
        )
        
        let shadowView = GradientShadowView(with: config)
        shadowView.isUserInteractionEnabled = false
        addSubview(shadowView)
        
        // Place shadow above contentImageView
        insertSubview(shadowView, aboveSubview: contentImageView)
        
        shadowView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            // Default height similar to interstitial handlers
            let screenWidth = UIScreen.main.bounds.width
            make.height.equalTo(screenWidth * 280 / 375)
        }
        
        bottomShadowView = shadowView
    }

    // MARK: Private

    private lazy var backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var contentImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private var mediaModel: NovaAdImageMediaModel?
    private var actionContext: NovaAdMediaActionContext?
    private var actionHelper: NovaActionHelper<NovaActionState.Init>?
    
    private var bottomShadowView: GradientShadowView?

    private func setupActionHelper() {
        guard let actionContext else {
            DebugLogger.ui.info("image media model is not clickable without action Context, but tapped")
            return
        }
        guard let mediaModel else {
            DebugLogger.ui.info("image media model is not set, but image tapped")
            return
        }

        if let weakVC = actionContext.viewController {
            actionHelper = NovaActionHelper
                .build(
                    with:
                    .adInViewController(
                        model: .init(
                            tracingInfo: actionContext.adActionTracingInfo,
                            extraInfo: actionContext.adActionExtraInfo,
                            ctrType: mediaModel.adCtrType
                        ),
                        viewController: weakVC
                    )
                )
        } else {
            actionHelper = NovaActionHelper
                .build(
                    with:
                    .adInView(
                        model: .init(
                            tracingInfo: actionContext.adActionTracingInfo,
                            extraInfo: actionContext.adActionExtraInfo,
                            ctrType: mediaModel.adCtrType
                        )
                    )
                )
        }
    }

    @objc private func didTapImage() {
        guard let mediaModel else {
            DebugLogger.ui.info("image media model is not set, but image tapped")
            return
        }
        
        switch mediaModel.adCtrType {
        case .openWeb, .appInstall:
            actionHelper = actionHelper?
                .logNovaClickEvent(with: CACurrentMediaTime() - startTime, in: .media)
                .handleAdTap(in: self)
        case .playable(let model):
            actionHelper = actionHelper?.logNovaPlayableAdTapToTryEvent(reason: .click).handleAdTap(in: self)
        }
    }
}
