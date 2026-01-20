//
//  NovaAdLandingWebContainerViewController.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/12.
//

import UIKit

class NovaAdLandingWebContainerViewController: UIViewController {
    private let nestedViewController: UIViewController

    internal init(nestedViewController: UIViewController) {
        self.nestedViewController = nestedViewController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        nestedViewController.willMove(toParent: self)
        addChild(nestedViewController)
        view.addSubview(nestedViewController.view)
        nestedViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        nestedViewController.didMove(toParent: self)
    }
}
