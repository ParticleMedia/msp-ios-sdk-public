//
//  NovaAdCarouselCell.swift
//  NBFeedCell
//
//  Created by Shanyu Li on 2024/7/17.
//

@_implementationOnly import Kingfisher
@_implementationOnly import SnapKit
import UIKit

// MARK: - NovaAdCarouselCellDelegate

@MainActor
protocol NovaAdCarouselCellDelegate: AnyObject {
    func nativeAdCarouselCell(_ cell: NovaAdCarouselCell, didClickArea area: ClickableAdArea?)
}

// MARK: - NovaNativeAdCarouselCell

class NovaAdCarouselCell: UICollectionViewCell {
    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
        layer.cornerRadius = 10.0
        layer.borderWidth = 1.0
        layer.borderColor = NovaColorPalettes.Gray.tint300.cgColor
        backgroundColor = .clear
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public

    weak var delegate: NovaAdCarouselCellDelegate?

    // MARK: Internal

    func setup(with item: NovaNativeMultipleItemsItem) {
        self.item = item
        imageView.kf.setImage(with: item.imageUrl)
        bodyLabel.text = item.body
        ctaButton.setTitle(item.callToAction, for: .normal)
    }

    // MARK: Private

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.adClickArea = .media
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapClickableArea(sender:))))
        return imageView
    }()

    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .Nova.body2
        label.textColor = UIColor(light: NovaColorPalettes.Black.withAlphaComponent(0.85), dark: NovaColorPalettes.White)
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.accessibilityLabel = "body"
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapClickableArea(sender:))))
        return label
    }()

    private lazy var ctaButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = NovaColorPalettes.Blue.tint500
        configuration.background.backgroundColor = .clear
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .Nova.caption2
            return outgoing
        }
        let button = UIButton(configuration: configuration)
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = 4.0
        button.layer.borderColor = NovaColorPalettes.Blue.tint500.cgColor
        button.clipsToBounds = true
        button.accessibilityIdentifier = "cta"
        button.addTarget(self, action: #selector(didTapCtaButton), for: .touchUpInside)
        return button
    }()

    private var item: NovaNativeMultipleItemsItem?
}

private extension NovaAdCarouselCell {
    func setupSubviews() {
        addSubviews([imageView, bodyLabel, ctaButton])

        imageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(220)
        }

        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalTo(ctaButton.snp.leading).offset(-8)
        }

        ctaButton.snp.makeConstraints { make in
            make.top.equalTo(bodyLabel.snp.top)
            make.trailing.equalToSuperview().offset(-12)
            make.height.equalTo(26)
            make.width.equalTo(96)
        }
    }

    @objc func didTapClickableArea(sender: UIGestureRecognizer) {
        self.delegate?.nativeAdCarouselCell(self, didClickArea: sender.view?.adClickArea)
    }

    @objc func didTapCtaButton() {
        self.delegate?.nativeAdCarouselCell(self, didClickArea: .cta)
    }
}
