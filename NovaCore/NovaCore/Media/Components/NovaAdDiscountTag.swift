//
//  NovaAdDiscountTag.swift
//  Pods
//
//  Created by Shanyu Li on 2024/12/24.
//

import UIKit

class NovaAdDiscountTag: UIView {
    enum Constants {
        static let discountTagHorizontalPadding = 14.0
        static let discountTagImmersiveHorizontalPadding = 17.0
        static let discountTagVerticalPadding = 12.0
        static let discountTagRedEmblemBackgroundPadding = 12.0
        static let discountTagRedEmblemSize = 72.0
    }

    private var style: NovaAdDiscountTagStyle?

    private lazy var tagLabel: UILabel = {
        let label = UILabel()
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var redEmblemBackground: UIImageView = {
        let imageView = UIImageView()
        imageView.image = .Nova.isolationMode
        return imageView
    }()

    init() {
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func config(with style: NovaAdDiscountTagStyle) {
        self.style = style
        setup(with: style)
        tagLabel.attributedText = generateTagAttributeText(with: style)
    }

    func setupNormalLayout(on mediaView: UIView, with info: NovaAdDiscountTagInfo) {
        let horizontalPadding: CGFloat = {
            switch info.style.background {
            case .default, .red:
                return Constants.discountTagHorizontalPadding
            case .redEmblem:
                return Constants.discountTagRedEmblemBackgroundPadding
            }
        }()
        let verticalPadding: CGFloat = {
            switch info.style.background {
            case .default, .red:
                return Constants.discountTagVerticalPadding
            case .redEmblem:
                return Constants.discountTagRedEmblemBackgroundPadding
            }
        }()
        switch info.style.background {
        case .default, .red:
            break
        case .redEmblem:
            snp.makeConstraints { make in
                make.width.height.equalTo(Constants.discountTagRedEmblemSize)
            }
        }
        switch info.position {
            // TODO: lsy, 因为外界没法感知 discount tag，放在左下角或者右下角的情况可能被外界文字遮挡。
        case .topLeft, .bottomLeft:
            snp.makeConstraints { make in
                make.top.equalTo(mediaView.safeAreaLayoutGuide.snp.top).offset(verticalPadding)
                make.leading.equalTo(mediaView.safeAreaLayoutGuide.snp.leading).offset(horizontalPadding)
            }
        case .topRight, .bottomRight:
            snp.makeConstraints { make in
                make.top.equalTo(mediaView.safeAreaLayoutGuide.snp.top).offset(verticalPadding)
                make.trailing.equalTo(mediaView.safeAreaLayoutGuide.snp.trailing).offset(-horizontalPadding)
            }
//        case .bottomLeft:
//            snp.makeConstraints { make in
//                make.leading.equalTo(mediaView.snp.leading).offset(horizontalPadding)
//                make.bottom.equalTo(mediaView.snp.bottom).offset(-verticalPadding)
//            }
//        case .bottomRight:
//            snp.makeConstraints { make in
//                make.trailing.equalTo(mediaView.snp.trailing).offset(-horizontalPadding)
//                make.bottom.equalTo(mediaView.snp.bottom).offset(-verticalPadding)
//            }
        }
    }

    func setupImmersiveLayout(
        on mediaView: UIView,
        over bottomView: UIView,
        with info: NovaAdDiscountTagInfo
    ) {
        let horizontalPadding: CGFloat = {
            switch info.style.background {
            case .default, .red:
                return Constants.discountTagImmersiveHorizontalPadding
            case .redEmblem:
                return Constants.discountTagRedEmblemBackgroundPadding
            }
        }()
        let verticalPadding: CGFloat = {
            switch info.style.background {
            case .default, .red:
                return Constants.discountTagVerticalPadding
            case .redEmblem:
                return Constants.discountTagRedEmblemBackgroundPadding
            }
        }()
        switch info.style.background {
        case .default, .red:
            break
        case .redEmblem:
            snp.makeConstraints { make in
                make.width.height.equalTo(Constants.discountTagRedEmblemSize)
            }
        }
        switch info.position {
        case .topLeft:
            snp.makeConstraints { make in
                make.top
                    .equalTo(mediaView.snp.top)
                    .offset(verticalPadding + UIApplication.novaSafeAreaInsets.top)
                make.leading.equalTo(mediaView.snp.leading).offset(horizontalPadding)

            }
        case .topRight:
            snp.makeConstraints { make in
                make.top
                    .equalTo(mediaView.snp.top)
                    .offset(verticalPadding + UIApplication.novaSafeAreaInsets.top)
                make.trailing.equalTo(mediaView.snp.trailing).offset(-horizontalPadding)
            }
        case .bottomLeft:
            snp.makeConstraints { make in
                make.leading.equalTo(mediaView.snp.leading).offset(horizontalPadding)
                make.bottom.equalTo(bottomView.snp.top).offset(-verticalPadding)
            }
        case .bottomRight:
            snp.makeConstraints { make in
                make.trailing.equalTo(mediaView.snp.trailing).offset(-horizontalPadding)
                make.bottom.equalTo(bottomView.snp.top).offset(-verticalPadding)
            }
        }
    }
}

private extension NovaAdDiscountTag {
    func setupShadow() {
        layer.shadowColor = NovaColorPalettes.buttonBackground.cgColor
        layer.shadowOffset = CGSize(width: 1, height: 1)
        layer.shadowRadius = 6.0
        layer.shadowOpacity = 0.25
    }

    func generateTagAttributeText(with style: NovaAdDiscountTagStyle) -> NSAttributedString {
        switch style.text {
        case .priceOff(let percentageText):
            let (textColor, textFont): (UIColor, UIFont) = {
                switch style.background {
                case .default:
                    return (NovaColorPalettes.buttonBackground, UIFont.Nova.deprecated14Bold)
                case .red:
                    return (NovaColorPalettes.White, UIFont.Nova.deprecated14Bold)
                case .redEmblem:
                    return (NovaColorPalettes.White, UIFont.Nova.headline2)
                }
            }()

            return NSAttributedString(
                string: percentageText,
                attributes: [.foregroundColor: textColor, .font: textFont]
            )
        case .priceSales(let newPrice, let originalPrice):
            let (newPriceTextColor, newPriceTextFont): (UIColor, UIFont) = {
                switch style.background {
                case .default:
                    return (NovaColorPalettes.buttonBackground, UIFont.Nova.subtitle1)
                case .red:
                    return (NovaColorPalettes.White, UIFont.Nova.subtitle1)
                case .redEmblem:
                    return (NovaColorPalettes.White, UIFont.Nova.headline2)
                }
            }()
            let priceSeparator: String = {
                switch style.background {
                case .default, .red:
                    return " "
                case .redEmblem:
                    return "\n"
                }
            }()
            let (originalPriceTextColor, originalPriceTextFont): (UIColor, UIFont) = {
                switch style.background {
                case .default:
                    return (NovaColorPalettes.buttonBackground, UIFont.Nova.caption1)
                case .red:
                    return (UIColor.black, UIFont.Nova.caption1)
                case .redEmblem:
                    return (UIColor.black, UIFont.Nova.body2)
                }
            }()
            let newPriceString = NSAttributedString(
                string: newPrice,
                attributes: [.foregroundColor: newPriceTextColor, .font: newPriceTextFont]
            )
            let originalPriceString = NSAttributedString(
                string: originalPrice,
                attributes: [
                    .foregroundColor: originalPriceTextColor,
                    .font: originalPriceTextFont,
                    .strikethroughStyle: NSNumber(integerLiteral: NSUnderlineStyle.single.rawValue)
                ]
            )
            let finalString = NSMutableAttributedString(attributedString: newPriceString)
            finalString.append(NSAttributedString(string: priceSeparator))
            finalString.append(originalPriceString)
            return finalString
        }
    }

    func setup(with style: NovaAdDiscountTagStyle) {
        switch style.background {
        case .default:
            backgroundColor = NovaColorPalettes.buttonText.withAlphaComponent(0.9)
            setupShadow()
            addSubview(tagLabel)
            layer.cornerRadius = 2.0
            tagLabel.snp.makeConstraints { make in
                make.verticalEdges.equalToSuperview().inset(0)
                make.horizontalEdges.equalToSuperview().inset(8)
            }
        case .red:
            backgroundColor = NovaColorPalettes.App.tint400
            addSubview(tagLabel)
            layer.cornerRadius = 2.0
            tagLabel.snp.makeConstraints { make in
                make.verticalEdges.equalToSuperview().inset(0)
                make.horizontalEdges.equalToSuperview().inset(8)
            }
        case .redEmblem:
            addSubview(redEmblemBackground)
            redEmblemBackground.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            redEmblemBackground.addSubview(tagLabel)
            tagLabel.snp.makeConstraints { make in
                make.top.leading.greaterThanOrEqualToSuperview()
                make.trailing.bottom.lessThanOrEqualToSuperview()
                make.center.equalToSuperview()
            }
        }
    }
}
