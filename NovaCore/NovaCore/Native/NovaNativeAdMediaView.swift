import Foundation
import UIKit

public final class NovaNativeAdMediaView: UIView {
    // MARK: - Properties

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    public let videoView: NovaNativeAdVideoView = {
        let videoView = NovaNativeAdVideoView()
        videoView.translatesAutoresizingMaskIntoConstraints = false
        return videoView
    }()

    private var isVideoDisplayed = false
    
    public var novaNativeAdVideoDelegate: NovaNativeAdVideoDelegate?

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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func setNovaNativeAdVideoDelegate(delegate: NovaNativeAdVideoDelegate) {
        self.novaNativeAdVideoDelegate = delegate
        self.videoView.novaNativeAdVideoDelegate = delegate
    }
}

// MARK: - Public methods

public extension NovaNativeAdMediaView {
    func config(with viewModel: NovaNativeAdMediaViewModel, iabReporter: IABMetricReporter?, completion: @escaping () -> Void) {
        videoView.novaNativeAdVideoDelegate = novaNativeAdVideoDelegate
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
        NovaUIUtils.setImage(from: imageUrl, to: imageView, completion: completion)
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
        updateVideoDisplayState(fullyDisplayed: videoView.nova_isFullyVisibleOnScreen)
    }

    func updateVideoDisplayState(fullyDisplayed: Bool) {
        if videoView.isHidden {
            return
        }
        if fullyDisplayed {
            
            isVideoDisplayed = true
            videoView.handleVideoOnScreen()
            
        } else {
            
            isVideoDisplayed = false
            videoView.handleVideoOffScreen()
        }
    }
    
    @objc func willResignActive() {
        updateVideoDisplayState(fullyDisplayed: false)
    }
    
    @objc func didBecomeActive() {
        if self.nova_isPartiallyVisibleOnScreen {
            updateVideoDisplayState(fullyDisplayed: true)
        }
    }
    
    @objc func handleVideoOnScreen() {
        videoView.handleVideoOnScreen()
    }
}
