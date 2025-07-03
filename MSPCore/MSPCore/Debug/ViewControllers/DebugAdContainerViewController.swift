import UIKit
import SnapKit

class DebugAdContainerViewController: UIViewController {
    private let adView: UIView
    private let preferredSize: CGSize
    
    init(adView: UIView, preferredSize: CGSize) {
        self.adView = adView
        self.preferredSize = preferredSize
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupAdView()
    }
    
    private func setupAdView() {
        view.addSubview(adView)
        adView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(preferredSize.width)
            make.height.equalTo(preferredSize.height)
        }
    }
} 
