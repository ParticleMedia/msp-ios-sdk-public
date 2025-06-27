import Foundation
import MSPiOSCore
import UIKit
import SnapKit

class DebugNativeAdContainer: UIView, MSPNativeAdContainer {
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.textAlignment = .natural
        return label
    }()
    
    private lazy var advertiserLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.numberOfLines = 1
        label.textColor = .tertiaryLabel
        return label
    }()
    
    private lazy var icon: UIImageView = {
        let view = UIImageView()
        return view
    }()
    
    private lazy var ctaButton: UIButton = {
        let button = UIButton()
        button.semanticContentAttribute = .forceRightToLeft
        button.contentHorizontalAlignment = .right
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: -10, bottom: 0, right: 10)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(.systemBlue, for: .normal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()
    
    private lazy var mediaView: UIView = {
        let view = UIView()
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setUpViews() {
        let subViews = [titleLabel, bodyLabel, advertiserLabel, ctaButton, mediaView, icon]
        for view in subViews {
            self.addSubview(view)
        }
        self.titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        mediaView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(mediaView.snp.width).multipliedBy(1.0 / AdsMediaConstants.defaultAspectRatio)
        }
        mediaView.isHidden = false
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.paddingSmall)
            make.top.equalTo(mediaView.snp.bottom).offset(Constants.paddingSmall)
            make.trailing.equalToSuperview().offset(-Constants.paddingSmall)
        }
        icon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.paddingSmall)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.width.height.equalTo(17)
        }
        bodyLabel.snp.makeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(Constants.paddingSmall)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.trailing.equalToSuperview().offset(-Constants.paddingSmall)
        }
        advertiserLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.paddingSmall)
            make.centerY.equalTo(ctaButton.snp.centerY)
            make.trailing.lessThanOrEqualTo(ctaButton.snp.leading).offset(-16)
        }
        ctaButton.snp.makeConstraints { make in
            make.top.equalTo(bodyLabel.snp.bottom).offset(4)
            make.bottom.equalToSuperview().offset(-8)
            make.trailing.equalToSuperview().offset(-18)
            make.height.equalTo(Constants.ctaButtonHeight)
        }
    }
    
    private enum Constants {
        static let paddingSmall: Double = 12.0
        static let ctaButtonHeight: Double = 26.0
        static let adWidth: Double = UIScreen.main.bounds.width - 32.0
    }
    
    enum AdsMediaConstants {
        static let iPadAspectRatio: Double = 0.56
        static let defaultAspectRatio: Double = 1200.0 / 627.0
        static let verticalVideoDefaultAspectRatio: Double = 9.0 / 16.0
    }
    
    func getTitle() -> UILabel? {
        return titleLabel
    }
    func getbody() -> UILabel? {
        return bodyLabel
    }
    func getAdvertiser() -> UILabel? {
        return advertiserLabel
    }
    func getCallToAction() -> UIButton? {
        return ctaButton
    }
    func getMedia() -> UIView? {
        return mediaView
    }
    func getIcon() -> UIImageView? {
        return self.icon
    }
} 