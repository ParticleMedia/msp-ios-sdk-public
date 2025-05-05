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

    public lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    public lazy var videoView: NovaNativeAdVideoView = {
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
            imageView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: imageView.superview!.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: imageView.superview!.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: imageView.superview!.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: imageView.superview!.bottomAnchor)
            ])
            switch imageResource {
            case .imageURLStr(let urlStr):
                if let url = URL(string: urlStr) {
                    NovaUIUtils.setImage(from: url, to: imageView) {
                        
                    }
                }
            case .image(let image):
                imageView.image = image
            }
        case .video(let videoResource):
            addSubview(videoView)
            videoView.translatesAutoresizingMaskIntoConstraints = false

            if let superView = videoView.superview {
                NSLayoutConstraint.activate([
                    videoView.topAnchor.constraint(equalTo: superView.topAnchor),
                    videoView.leadingAnchor.constraint(equalTo: superView.leadingAnchor),
                    videoView.trailingAnchor.constraint(equalTo: superView.trailingAnchor),
                    videoView.bottomAnchor.constraint(equalTo: superView.bottomAnchor)
                ])
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
