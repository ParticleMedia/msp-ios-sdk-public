import Foundation
import UIKit
import SDWebImage

public final class NovaNativeAdMediaView: UIView {
    // MARK: - Properties

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let videoView: NovaNativeAdVideoView = {
        let videoView = NovaNativeAdVideoView()
        videoView.translatesAutoresizingMaskIntoConstraints = false
        return videoView
    }()

    private var isVideoDisplayed = false

    // MARK: -

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        addSubview(videoView)

        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: topAnchor),
            videoView.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoView.bottomAnchor.constraint(equalTo: bottomAnchor),
            videoView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Public methods

public extension NovaNativeAdMediaView {
    func config(with viewModel: NovaNativeAdMediaViewModel, iabReporter: IABMetricReporter?, completion: @escaping () -> Void) {
        if let videoInfo = viewModel.videoInfo {
            videoView.config(videoInfo: videoInfo,
                             encryptedAdToken: viewModel.encryptedAdToken,
                             iabReporter: iabReporter)
            imageView.isHidden = true
            videoView.isHidden = false
            return
        }
        imageView.isHidden = false
        videoView.isHidden = true
        guard let imageUrlStr = viewModel.imageUrlStr, let imageUrl = URL(string: imageUrlStr) else { return }
        imageView.sd_setImage(with: imageUrl) { _, error, _, _ in
            if let error {
                //DebugLogging.error(.ads, "Set image on view failed: \(error.localizedDescription)")
            }
            completion()
        }
    }

    func prepareForReuse() {
        videoView.isHidden = true
        videoView.prepareForReuse()
    }

    func updateVideoStateOnScroll(containerFrame: CGRect, cellFrame: CGRect, offset: CGPoint, inset: UIEdgeInsets) {
        if videoView.isHidden {
            return
        }
        let videoTop = videoView.frame.origin.y + frame.origin.y + cellFrame.origin.y
        let videoBottom = videoTop + videoView.frame.size.height
        let scrollTop = offset.y + inset.top
        let scrollBottom = offset.y + containerFrame.size.height - inset.bottom
        updateVideoDisplayState(fullyDisplayed: videoTop >= scrollTop && videoBottom <= scrollBottom)
    }

    func updateVideoStateOnScroll() {
        updateVideoDisplayState(fullyDisplayed: videoView.nb_isFullyVisibleOnScreen)
    }

    func updateVideoDisplayState(fullyDisplayed: Bool) {
        if videoView.isHidden {
            return
        }
        if fullyDisplayed {
            if !isVideoDisplayed {
                isVideoDisplayed = true
                videoView.handleVideoOnScreen()
            }
        } else {
            if isVideoDisplayed {
                isVideoDisplayed = false
                videoView.handleVideoOffScreen()
            }
        }
    }
}
