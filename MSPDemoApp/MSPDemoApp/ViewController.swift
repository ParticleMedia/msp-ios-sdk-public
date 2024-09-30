import UIKit
import MSPCore
import MSPiOSCore
import AppTrackingTransparency

class ViewController: UIViewController {
    
    @IBOutlet var appBannerView: UIView!
    weak var adLoader: MSPAdLoader?
    public var nativeAdView: NativeAdView?
    public var isCtaShown = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let button1 = UIButton(type: .system)
                button1.setTitle("Prebid Banner View", for: .normal)
                button1.addAction(UIAction { [weak self] _ in
                    self?.openDemoAdPage(adType: .prebidBanner)
                }, for: .touchUpInside)
                button1.frame = CGRect(x: 100, y: 200, width: 200, height: 50)
                view.addSubview(button1)
        
        let button2 = UIButton(type: .system)
                button2.setTitle("Google Banner View", for: .normal)
                button2.addAction(UIAction { [weak self] _ in
                    self?.openDemoAdPage(adType: .googleBanner)
                }, for: .touchUpInside)
                button2.frame = CGRect(x: 100, y: 300, width: 200, height: 50)
                view.addSubview(button2)
        let button3 = UIButton(type: .system)
                button3.setTitle("Google Native View", for: .normal)
                button3.addAction(UIAction { [weak self] _ in
                    self?.openDemoAdPage(adType: .googleNative)
                }, for: .touchUpInside)
                button3.frame = CGRect(x: 100, y: 400, width: 200, height: 50)
                view.addSubview(button3)
        let button4 = UIButton(type: .system)
                button4.setTitle("Nova Native View", for: .normal)
                button4.addAction(UIAction { [weak self] _ in
                    self?.openDemoAdPage(adType: .novaNative)
                }, for: .touchUpInside)
                button4.frame = CGRect(x: 100, y: 500, width: 200, height: 50)
                view.addSubview(button4)
       
    }

    func openDemoAdPage(adType: AdType) {
        let demoAdVC = DemoAdViewController(adType: adType)
        navigationController?.pushViewController(demoAdVC, animated: true)
    }

}
