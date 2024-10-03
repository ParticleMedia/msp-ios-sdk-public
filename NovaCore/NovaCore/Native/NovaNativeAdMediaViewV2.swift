//
//  NovaNativeAdMediaViewV2.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation
import UIKit


@objc public final class NovaNativeAdMediaViewV2: UIView {
    // MARK: - Properties

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var videoView: NovaNativeAdVideoView = {
        let videoView = NovaNativeAdVideoView()
        return videoView
    }()

    private var isVideoDisplayed = false
    private var media: NovaNativeAdMedia?
    
    public init() {
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Public methods

public extension NovaNativeAdMediaViewV2 {
    func config(with media: NovaNativeAdMedia) {
        self.media = media
        switch media {
        case .image(let imageResource):
            addSubviews(imageView)
            imageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            switch imageResource {
            case .imageURLStr(let urlStr):
                imageView.sd_setImage(with: URL(string: urlStr))
            case .image(let image):
                imageView.image = image
            }
        case .video(let videoResource):
            addSubview(videoView)
            videoView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            videoView.config(videoInfo: videoResource.videoInfo, encryptedAdToken: videoResource.adToken, iabReporter: videoResource.reporter)
        }
    }

    func prepareForReuse() {
        if let media, case .video(_) = media {
            videoView.isHidden = true
            videoView.prepareForReuse()
        }
    }
    
    func mediaStartShown() {
        if let media, case .video(_) = media {
            videoView.handleVideoOnScreen()
        }
    }
    
    func mediaEndShown() {
        if let media, case .video(_) = media {
            videoView.handleVideoOffScreen()
        }
    }
}
