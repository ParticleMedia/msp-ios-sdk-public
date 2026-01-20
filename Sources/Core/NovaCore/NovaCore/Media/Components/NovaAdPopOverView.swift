//
//  NovaAdPopOverView.swift
//  NBNovaAdComponents
//
//  Created by Shanyu Li on 2025/7/15.
//

import Foundation
@_implementationOnly import SnapKit
import UIKit

enum NovaAdPopOverState {
    case hide
    case pop(sourceView: UIView, sourcePoint: CGPoint, extraLayoutConfig: NovaAdPopOverView.ExtraLayoutConfig)
}

protocol NovaAdPopOverContentView where Self: UIView {
    var preferredSize: CGSize { get }
    func configure(callToAction: String, advertiser: String?, iconURL: URL?)
    func changeState(_ state: NovaAdPopOverState, in host: NovaAdPopOverView)
}

struct NovaAdPopOverViewModel {
    let callToAction: String
    let advertiser: String?
    let iconURL: URL?
    let styleVariant: NovaPopupCTAStyleVariant
}

class NovaAdPopOverView: UIView {
    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        adClickArea = .cta_popover
        applyStyle(.legacy)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct ExtraLayoutConfig {
        let safeAreaInsets: UIEdgeInsets
        let exclusionRects: [CGRect]
    }

    // MARK: Public

    func config(with model: NovaAdPopOverViewModel) {
        applyStyle(model.styleVariant)
        contentView?.configure(
            callToAction: model.callToAction,
            advertiser: model.advertiser,
            iconURL: model.iconURL
        )
    }

    func changeState(to state: NovaAdPopOverState) {
        contentView?.changeState(state, in: self)
    }

    // MARK: Internal

    enum Constants {
        static let padding: CGFloat = 8.0
    }

    // MARK: Private

    private var contentView: (UIView & NovaAdPopOverContentView)?
    private var currentVariant: NovaPopupCTAStyleVariant?

    private func applyStyle(_ variant: NovaPopupCTAStyleVariant) {
        if currentVariant == variant {
            return
        }
        let nextView: (UIView & NovaAdPopOverContentView) = switch variant {
        case .legacy:
            NovaAdPopOverLegacyView()
        case .v2:
            NovaAdPopOverV2View()
        }

        contentView?.removeFromSuperview()
        contentView = nextView
        currentVariant = variant
        addSubview(nextView)
        nextView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

private final class NovaAdPopOverLegacyView: UIView, NovaAdPopOverContentView {
    // MARK: Constants

    enum Constants {
        static let popoverWidth: CGFloat = 124.0
        static let popoverHeight: CGFloat = 42.0
        static let popoverSpacing: CGFloat = 4.0
        static let arrowSize: CGFloat = 16.0
        static let popoverBottomPadding: CGFloat = 12.0
        static let padding: CGFloat = 8.0
    }

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        addSubview(popoverStack)
        popoverStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Constants.padding)
            make.trailing.lessThanOrEqualToSuperview().offset(-Constants.padding)
            make.bottom.equalToSuperview().offset(-Constants.popoverBottomPadding)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: NovaAdPopOverContentView

    var preferredSize: CGSize {
        CGSize(width: Constants.popoverWidth, height: Constants.popoverHeight)
    }

    func configure(callToAction: String, advertiser: String?, iconURL: URL?) {
        label.text = callToAction
        backgroundImage.image = .Nova.popOver?.imageByResize(to: preferredSize)
    }

    func changeState(_ state: NovaAdPopOverState, in host: NovaAdPopOverView) {
        switch state {
        case .hide:
            host.removeFromSuperview()
        case let .pop(sourceView, sourcePoint, extraLayoutConfig):
            sourceView.addSubview(host)
            host.isHidden = false

            let insets = extraLayoutConfig.safeAreaInsets
            let popoverSize = preferredSize
            let minX = insets.left + NovaAdPopOverView.Constants.padding
            let maxX = sourceView.frame.width - insets.right - NovaAdPopOverView.Constants.padding - popoverSize.width
            let desiredLeading = sourcePoint.x

            let leadingOffset: CGFloat = if desiredLeading < minX {
                minX
            } else if desiredLeading > maxX {
                maxX
            } else {
                desiredLeading
            }

            let maxY = sourceView.frame.height - insets.bottom - popoverSize.height
            let minY = insets.top + NovaAdPopOverView.Constants.padding
            let desiredTop = sourcePoint.y
            let topOffset: CGFloat = min(max(desiredTop, minY), maxY)

            host.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(topOffset)
                make.leading.equalToSuperview().offset(leadingOffset)
                make.width.equalTo(popoverSize.width)
                make.height.equalTo(popoverSize.height)
            }
        }
    }

    // MARK: Subviews

    private lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        return imageView
    }()

    private lazy var label: UILabel = {
        let label = UILabel()
        label.font = .Nova.subtitle1
        label.textColor = NovaColorPalettes.Black.withAlphaComponent(0.85)
        return label
    }()

    private lazy var arrowImageView: UIImageView = {
        let imageView = UIImageView(image: .Nova.chevronRightLine?.withTintColor(NovaColorPalettes.Black))
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var popoverStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [label, arrowImageView])
        arrowImageView.snp.makeConstraints { make in
            make.width.height.equalTo(Constants.arrowSize)
        }
        stackView.axis = .horizontal
        stackView.spacing = Constants.popoverSpacing
        stackView.alignment = .center
        return stackView
    }()
}

private final class NovaAdPopOverV2View: UIView, NovaAdPopOverContentView {
    // MARK: Constants

    enum Constants {
        static let maxTextWidth: CGFloat = 220.0
        static let horizontalPadding: CGFloat = 12.0
        static let horizontalPaddingWithLogo: CGFloat = 8.0
        static let noLogoPadding: CGFloat = 12.0
        static let verticalPadding: CGFloat = 8.0
        static let angleHeight: CGFloat = 8.0
        static let elementSpacing: CGFloat = 8.0
        static let textSpacing: CGFloat = 2.0
        static let arrowSize: CGFloat = 16.0
        static let logoSize: CGFloat = 44.0
        static let logoCornerRadius: CGFloat = 6.0
    }

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            leadingConstraint = make.leading.equalToSuperview().offset(Constants.horizontalPaddingWithLogo).constraint
            make.trailing.equalToSuperview().offset(-Constants.horizontalPadding)
            make.top.equalToSuperview().inset(Constants.verticalPadding)
            make.bottom.equalToSuperview().inset(Constants.verticalPadding + Constants.angleHeight)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: NovaAdPopOverContentView

    var preferredSize: CGSize {
        cachedSize
    }

    func configure(callToAction: String, advertiser: String?, iconURL: URL?) {
        let trimmedAdvertiser = advertiser?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasBrand = !(trimmedAdvertiser?.isEmpty ?? true)
        let hasLogo = iconURL != nil

        brandLabel.text = trimmedAdvertiser
        brandLabel.isHidden = !hasBrand
        textStack.spacing = hasBrand ? Constants.textSpacing : 0.0

        ctaLabel.text = callToAction
        logoImageView.isHidden = !hasLogo
        if let iconURL {
            logoImageView.kf.setImage(with: iconURL)
        } else {
            logoImageView.image = nil
        }

        leadingConstraint?.update(offset: hasLogo ? Constants.horizontalPaddingWithLogo : Constants.noLogoPadding)
        cachedSize = calculateSize(callToAction: callToAction, advertiser: trimmedAdvertiser, hasLogo: hasLogo)
        backgroundImage.image = .Nova.popOverFilledBlue?.imageByResize(to: cachedSize)
    }

    func changeState(_ state: NovaAdPopOverState, in host: NovaAdPopOverView) {
        switch state {
        case .hide:
            host.removeFromSuperview()
        case let .pop(sourceView, sourcePoint, extraLayoutConfig):
            sourceView.addSubview(host)
            host.isHidden = false

            let insets = extraLayoutConfig.safeAreaInsets
            let popoverSize = preferredSize
            let minX = insets.left + NovaAdPopOverView.Constants.padding
            let maxX = sourceView.frame.width - insets.right - NovaAdPopOverView.Constants.padding - popoverSize.width
            let desiredLeading = sourcePoint.x - (popoverSize.width / 2.0)

            let leadingOffset: CGFloat = if desiredLeading < minX {
                minX
            } else if desiredLeading > maxX {
                maxX
            } else {
                desiredLeading
            }

            let maxY = sourceView.frame.height - insets.bottom - popoverSize.height
            let minY = insets.top + NovaAdPopOverView.Constants.padding
            let desiredTop = sourcePoint.y - popoverSize.height
            let topOffset: CGFloat = min(max(desiredTop, minY), maxY)

            host.snp.remakeConstraints { make in
                make.top.equalToSuperview().offset(topOffset)
                make.leading.equalToSuperview().offset(leadingOffset)
                make.width.equalTo(popoverSize.width)
                make.height.equalTo(popoverSize.height)
            }
        }
    }

    // MARK: Private

    private var cachedSize: CGSize = .zero
    private var leadingConstraint: Constraint?

    private lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        return imageView
    }()

    private lazy var logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Constants.logoCornerRadius
        imageView.snp.makeConstraints { make in
            make.width.height.equalTo(Constants.logoSize)
        }
        return imageView
    }()

    private lazy var brandLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.body2
        label.textColor = NovaColorPalettes.White.withAlphaComponent(0.8)
        label.lineBreakMode = .byTruncatingTail
        label.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(Constants.maxTextWidth)
        }
        return label
    }()

    private lazy var ctaLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.headline3
        label.textColor = NovaColorPalettes.White
        label.lineBreakMode = .byTruncatingTail
        label.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(Constants.maxTextWidth)
        }
        return label
    }()

    private lazy var arrowImageView: UIImageView = {
        let imageView = UIImageView(image: .Nova.chevronRightLine?.withTintColor(NovaColorPalettes.White))
        imageView.contentMode = .scaleAspectFit
        imageView.snp.makeConstraints { make in
            make.width.height.equalTo(Constants.arrowSize)
        }
        return imageView
    }()

    private lazy var textStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [brandLabel, ctaLabel])
        stackView.axis = .vertical
        stackView.spacing = Constants.textSpacing
        stackView.alignment = .leading
        return stackView
    }()

    private lazy var contentStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [logoImageView, textStack, arrowImageView])
        stackView.axis = .horizontal
        stackView.spacing = Constants.elementSpacing
        stackView.alignment = .center
        return stackView
    }()

    private func calculateSize(callToAction: String, advertiser: String?, hasLogo: Bool) -> CGSize {
        let maxTextWidth = Constants.maxTextWidth
        let ctaSize = (callToAction as NSString).size(withAttributes: [.font: ctaLabel.font as Any])
        let ctaWidth = min(ctaSize.width, maxTextWidth)

        var brandWidth: CGFloat = 0.0
        var brandHeight: CGFloat = 0.0
        if let advertiser, !advertiser.isEmpty {
            let brandSize = (advertiser as NSString).size(withAttributes: [.font: brandLabel.font as Any])
            brandWidth = min(brandSize.width, maxTextWidth)
            brandHeight = brandSize.height
        }

        let textWidth = max(brandWidth, ctaWidth)
        let textHeight = brandHeight + (brandHeight > 0 ? Constants.textSpacing : 0.0) + ctaSize.height
        let contentHeight = max(textHeight, hasLogo ? Constants.logoSize : 0.0, Constants.arrowSize)
        let leftPadding = hasLogo ? Constants.horizontalPaddingWithLogo : Constants.noLogoPadding

        var width = leftPadding + textWidth + Constants.elementSpacing + Constants.arrowSize + Constants.horizontalPadding
        if hasLogo {
            width += Constants.logoSize + Constants.elementSpacing
        }
        let height = contentHeight + (Constants.verticalPadding * 2.0 + Constants.angleHeight)

        return CGSize(width: ceil(width), height: ceil(height))
    }
}
