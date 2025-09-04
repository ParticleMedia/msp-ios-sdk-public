//
//  NovaAdPlayableViewController.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/8/18.
//

import UIKit

// MARK: - NovaAdPlayableViewController

class NovaAdPlayableViewController: UIViewController {
    // MARK: Lifecycle

    init(with config: Config) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public

    struct Config {
        let playableConfigs: (model: PlayableModel, actionContext: NovaAdMediaActionContext?)
        let title: String?
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.addSubviews(topBar, playableView, bottomBar)

        topBar.snp.makeConstraints { make in
            make.top.directionalHorizontalEdges.equalToSuperview()
            make.height.equalTo((UIApplication.novaHasTopSafeArea ? (88) : (64)))
        }
        topBar.addSubviews(closeButton, titleLabel)
        closeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(6)
            make.bottom.equalToSuperview()
            make.size.equalTo(44)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualToSuperview().offset(56)
            make.trailing.lessThanOrEqualToSuperview().offset(-56)
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }
        playableView.snp.makeConstraints { make in
            make.directionalHorizontalEdges.equalToSuperview()
            make.top.equalTo(topBar.snp.bottom)
            make.bottom.equalTo(bottomBar.snp.top)
        }
        bottomBar.snp.makeConstraints { make in
            make.bottom.directionalHorizontalEdges.equalToSuperview()
            make.height.equalTo(56)
        }

        config(with: config)
    }

    // MARK: Private

    private lazy var topBar: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()

    private lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10.0, leading: 10.0, bottom: 10.0, trailing: 10.0)
        configuration.image = .Nova.crossLine
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(light: NovaColorPalettes.Gray.tint800, dark: NovaColorPalettes.White)
        label.textAlignment = .center
        label.font = .boldSystemFont(ofSize: 16)
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private lazy var playableView: NovaAdPlayableView = .init()

    private lazy var bottomBar: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()

    private let config: Config

    private func config(with config: Config) {
        playableView.config(with: config.playableConfigs.model, actionContext: config.playableConfigs.actionContext)
        titleLabel.text = config.title
    }
}

private extension NovaAdPlayableViewController {
    @objc func didTapCloseButton() {
        dismiss(animated: true)
    }
}
