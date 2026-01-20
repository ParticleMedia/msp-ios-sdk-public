import Foundation
import UIKit
//import NBColorPalettes

class NovaVideoProgressView: UIView {

    private let progressTrackWidth: CGFloat = 8.0

    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let progressBar: UIProgressView = {
        let progressBar = UIProgressView()
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        return progressBar
    }()

    private let unplayedProgressView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let progressTrackView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var trackViewLeftConstraint: NSLayoutConstraint!
    private var containerHeight: NSLayoutConstraint!

    init() {
        super.init(frame: .zero)

        self.addSubview(containerView)

        containerView.addSubview(unplayedProgressView)
        containerView.addSubview(progressBar)
        containerView.addSubview(progressTrackView)

        trackViewLeftConstraint = progressTrackView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 0)
        containerHeight = containerView.heightAnchor.constraint(equalToConstant: 1)

        NSLayoutConstraint.activate([
            containerView.leftAnchor.constraint(equalTo: self.leftAnchor),
            containerView.rightAnchor.constraint(equalTo: self.rightAnchor),
            containerView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            containerHeight,

            progressBar.leftAnchor.constraint(equalTo: containerView.leftAnchor),
            progressBar.rightAnchor.constraint(equalTo: containerView.rightAnchor),
            progressBar.heightAnchor.constraint(equalTo: containerView.heightAnchor),
            progressBar.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            unplayedProgressView.leftAnchor.constraint(equalTo: containerView.leftAnchor),
            unplayedProgressView.rightAnchor.constraint(equalTo: containerView.rightAnchor),
            unplayedProgressView.heightAnchor.constraint(equalTo: containerView.heightAnchor),
            unplayedProgressView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            trackViewLeftConstraint,
            progressTrackView.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            progressTrackView.widthAnchor.constraint(equalToConstant: progressTrackWidth),
            progressTrackView.heightAnchor.constraint(equalToConstant: progressTrackWidth),
        ])

        progressTrackView.layer.cornerRadius = progressTrackWidth * 0.5
        progressTrackView.isHidden = true

        self.configProgressColor(progressTintColor: NovaColorPalettes.White.withAlphaComponent(0.6),
                                 trackTintColor: NovaColorPalettes.White.withAlphaComponent(0.2))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTrackView(hidden: Bool) {
        progressTrackView.isHidden = hidden
        if hidden {
            containerHeight.constant = 1
            self.configProgressColor(progressTintColor: NovaColorPalettes.White.withAlphaComponent(0.6),
                                     trackTintColor: NovaColorPalettes.White.withAlphaComponent(0.3))
        } else {
            containerHeight.constant = 2
            self.configProgressColor(progressTintColor: NovaColorPalettes.White,
                                     trackTintColor: NovaColorPalettes.White.withAlphaComponent(0.2))
        }
    }

    func configProgressColor(progressTintColor: UIColor, trackTintColor: UIColor) {
        progressBar.progressTintColor = progressTintColor
        progressTrackView.backgroundColor = progressTintColor
        progressBar.trackTintColor = .clear
        unplayedProgressView.backgroundColor = trackTintColor
    }

    func updateProgress(_ progress: Float) {
        guard progress >= 0 else {
            progressBar.setProgress(0, animated: false)
            trackViewLeftConstraint.constant = -progressTrackWidth
            return
        }

        if progress == 0 {
            trackViewLeftConstraint.constant = -progressTrackWidth
        } else {
            trackViewLeftConstraint.constant = self.frame.width * CGFloat(progress) - progressTrackWidth * 0.5
        }
        progressBar.setProgress(progress, animated: false)
    }

    func shouldReceivePanGesture(with position: CGPoint) -> Bool {
        let current = CGFloat(self.progressBar.progress) * self.frame.width
        return (current - position.x) <= 40
    }
}
