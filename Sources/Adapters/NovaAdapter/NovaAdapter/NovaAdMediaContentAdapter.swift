//
//  NovaAdMediaContentAdapter.swift
//  NovaAdapter
//
//  Created by Shanyu Li on 2025/9/23.
//

import Foundation
import MSPiOSCore
import NovaCore
import UIKit

// MARK: - NovaAdMediaContentAdapter

class NovaAdMediaContainerAdapter: AdMediaContainer {
    // MARK: Lifecycle

    init(mediaContent: NovaAdMediaContent) {
        self.mediaContent = mediaContent
        if let imageController = mediaContent.imageController {
            self.imageControllerAdapter = NovaAdImageControllerAdapter(imageController: imageController)
        } else {
            self.imageControllerAdapter = nil
        }

        if let videoController = mediaContent.videoController {
            self.videoControllerAdapter = NovaAdVideoControllerAdapter(videoController: videoController)
        } else {
            self.videoControllerAdapter = nil
        }

        if let playableController = mediaContent.playableController {
            self.playableControllerAdapter = NovaAdPlayableControllerAdapter(playableController: playableController)
        } else {
            self.playableControllerAdapter = nil
        }
    }

    // MARK: Internal

    let mediaContent: NovaAdMediaContent
    let imageControllerAdapter: NovaAdImageControllerAdapter?
    let videoControllerAdapter: NovaAdVideoControllerAdapter?
    let playableControllerAdapter: NovaAdPlayableControllerAdapter?

    var imageController: (any MSPiOSCore.ImageController)? {
        return imageControllerAdapter
    }

    var videoController: (any MSPiOSCore.VideoController)? {
        return videoControllerAdapter
    }

    var playableController: (any MSPiOSCore.PlayableController)? {
        return playableControllerAdapter
    }
}

class NovaAdImageControllerAdapter: ImageController {
    init(imageController: NovaAdImageController) {
        self.imageController = imageController
    }

    let imageController: NovaAdImageController

    var contentMode: UIView.ContentMode {
        get {
            imageController.contentMode
        }
        set {
            imageController.contentMode = newValue
        }
    }
}

// MARK: - NovaAdVideoControllerAdapter

class NovaAdVideoControllerAdapter: VideoController {
    // MARK: Lifecycle

    init(videoController: NovaAdVideoController) {
        self.videoController = videoController
        self.delegateAdapter = NovaAdVideoControllerDelegateAdapter(videoController: nil)
        videoController.delegate = delegateAdapter
        self.delegateAdapter.videoController = self
    }

    // MARK: Internal

    let videoController: NovaAdVideoController
    let delegateAdapter: NovaAdVideoControllerDelegateAdapter

    var delegate: (any MSPiOSCore.VideoControllerDelegate)? {
        get {
            delegateAdapter.videoControllerDelegate
        }
        set {
            delegateAdapter.videoControllerDelegate = newValue
        }
    }

    var muted: Bool {
        get {
            videoController.muted 
        }
        set {
            videoController.muted = newValue
        }
    }

    func play() {
        videoController.play()
    }

    func pause() {
        videoController.pause()
    }

    func stop() {
        videoController.stop()
    }
}

// MARK: - NovaAdVideoControllerDelegateAdapter

class NovaAdVideoControllerDelegateAdapter: NovaAdVideoViewDelegate {
    // MARK: Lifecycle

    init(videoController: (any VideoController)?) {
        self.videoController = videoController
    }

    // MARK: Internal

    weak var videoController: (any VideoController)?
    weak var videoControllerDelegate: VideoControllerDelegate?

    func videoViewCurrentTimeDidChange(loopCount: Int, currentTime: TimeInterval, videoLength: TimeInterval) {
        videoControllerDelegate?
            .videoController(
                videoController,
                loopCount: loopCount,
                didUpdateProgress: currentTime,
                videoLength: videoLength
            )
    }
}

class NovaAdPlayableControllerAdapter: PlayableController {
    init(playableController: NovaAdPlayableController) {
        self.playableController = playableController
    }

    // MARK: Internal

    let playableController: NovaAdPlayableController

    var renderMode: PlayableRenderMode {
        get {
            switch playableController.renderOption {
            case .auto:
                return .auto
            case .imageOrVideo:
                return .imageOrVideo
            case .playable:
                return .playable
            @unknown default:
                return .auto
            }
        }
        set {
            switch newValue {
            case .auto:
                playableController.renderOption = .auto
            case .imageOrVideo:
                playableController.renderOption = .imageOrVideo
            case .playable:
                playableController.renderOption = .playable
            @unknown default:
                playableController.renderOption = .auto
            }
        }
    }
}
