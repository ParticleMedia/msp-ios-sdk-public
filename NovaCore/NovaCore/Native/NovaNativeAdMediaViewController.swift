//
//  NovaNativeAdMediaViewController.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 7/15/24.
//

import Foundation
import UIKit

public class NovaNativeAdMediaViewController: UIViewController {
    public var mediaView: NovaNativeAdMediaView
    
    public init(mediaView: NovaNativeAdMediaView) {
        self.mediaView = mediaView
        super.init(nibName: nil, bundle: nil)
        self.view = mediaView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        self.view = mediaView
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mediaView.updateVideoDisplayState(fullyDisplayed: true)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        mediaView.updateVideoDisplayState(fullyDisplayed: false)
    }
}
