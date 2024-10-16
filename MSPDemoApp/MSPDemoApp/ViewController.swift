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
        let button5 = UIButton(type: .system)
                button5.setTitle("Google Interstitial View", for: .normal)
                button5.addAction(UIAction { [weak self] _ in
                    self?.openDemoAdPage(adType: .googleInterstitial)
                }, for: .touchUpInside)
                button5.frame = CGRect(x: 100, y: 600, width: 200, height: 50)
                view.addSubview(button5)
        let button6 = UIButton(type: .system)
                button6.setTitle("Nova Interstitial View", for: .normal)
                button6.addAction(UIAction { [weak self] _ in
                    self?.openDemoAdPage(adType: .novaInterstitial)
                }, for: .touchUpInside)
                button6.frame = CGRect(x: 100, y: 700, width: 200, height: 50)
                view.addSubview(button6)
        /*
        let button7 = UIButton(type: .system)
                button7.setTitle("Facebook Native View", for: .normal)
                button7.addAction(UIAction { [weak self] _ in
                    self?.openDemoAdPage(adType: .facebookNative)
                }, for: .touchUpInside)
                button7.frame = CGRect(x: 100, y: 800, width: 200, height: 50)
                view.addSubview(button7)
       */
    }

    func openDemoAdPage(adType: AdType) {
        let demoAdVC = DemoAdViewController(adType: adType)
        navigationController?.pushViewController(demoAdVC, animated: true)
    }

}
