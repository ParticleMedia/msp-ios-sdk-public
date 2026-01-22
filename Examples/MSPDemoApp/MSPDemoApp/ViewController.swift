import AppTrackingTransparency
import MSPCore
import MSPiOSCore
import UIKit

class ViewController: UIViewController {
    @IBOutlet var appBannerView: UIView!
    weak var adLoader: MSPAdLoader?
    public var nativeAdView: NativeAdView?
    public var isCtaShown = false

    override func viewDidLoad() {
        super.viewDidLoad()

        let button1 = UIButton(type: .system)
        button1.setTitle("Prebid Banner View", for: .normal)
        button1.addAction(
            UIAction { [weak self] _ in
                self?.openDemoAdPage(adType: .prebidBanner)
            }, for: .touchUpInside)
        button1.frame = CGRect(x: 100, y: 100, width: 200, height: 50)
        view.addSubview(button1)

        let button2 = UIButton(type: .system)
        button2.setTitle("Google Banner View", for: .normal)
        button2.frame = CGRect(x: 100, y: 150, width: 200, height: 50)
        view.addSubview(button2)
        let googleBannerMenuItems = [
            UIAction(title: "s2s", handler: { _ in self.openDemoAdPage(adType: .googleBanner) }),
            UIAction(title: "c2s", handler: { _ in self.openDemoAdPage(adType: .googleBannerC2S) }),
        ]

        button2.menu = UIMenu(title: "Choose an option", children: googleBannerMenuItems)
        button2.showsMenuAsPrimaryAction = true
        let button3 = UIButton(type: .system)
        button3.setTitle("Google Native View", for: .normal)
        button3.frame = CGRect(x: 100, y: 200, width: 200, height: 50)
        view.addSubview(button3)
        let googleNativeMenuItems = [
            UIAction(title: "s2s", handler: { _ in self.openDemoAdPage(adType: .googleNative) }),
            UIAction(title: "c2s", handler: { _ in self.openDemoAdPage(adType: .googleNativeC2S) }),
        ]

        button3.menu = UIMenu(title: "Choose an option", children: googleNativeMenuItems)
        button3.showsMenuAsPrimaryAction = true
        let button4 = UIButton(type: .system)
        button4.setTitle("Nova Native View", for: .normal)
        button4.addAction(
            UIAction { [weak self] _ in
                self?.openDemoAdPage(adType: .novaNative)
            }, for: .touchUpInside)
        button4.frame = CGRect(x: 100, y: 250, width: 200, height: 50)
        view.addSubview(button4)
        let button5 = UIButton(type: .system)
        button5.setTitle("Google Interstitial View", for: .normal)
        button5.frame = CGRect(x: 100, y: 300, width: 200, height: 50)
        view.addSubview(button5)
        let googleInterstitialMenuItems = [
            UIAction(title: "s2s", handler: { _ in self.openDemoAdPage(adType: .googleInterstitial) }),
            UIAction(title: "c2s", handler: { _ in self.openDemoAdPage(adType: .googleInterstitialC2S) }),
        ]

        button5.menu = UIMenu(title: "Choose an option", children: googleInterstitialMenuItems)
        button5.showsMenuAsPrimaryAction = true
        let button6 = UIButton(type: .system)
        button6.setTitle("Nova Interstitial View", for: .normal)
        button6.frame = CGRect(x: 100, y: 350, width: 200, height: 50)
        view.addSubview(button6)
        let novaInterstitialMenuItems = [
            UIAction(
                title: "Horizontal Image",
                handler: { _ in self.openDemoAdPage(adType: .novaInterstitialHorizontalImage) }),
            UIAction(
                title: "Vertical Image", handler: { _ in self.openDemoAdPage(adType: .novaInterstitialVerticalImage) }),
            UIAction(
                title: "Horizontal Video",
                handler: { _ in self.openDemoAdPage(adType: .novaInterstitialHorizontalVideo) }),
            UIAction(
                title: "Vertical Video", handler: { _ in self.openDemoAdPage(adType: .novaInterstitialVerticalVideo) }),
            UIAction(
                title: "High Engagement", handler: { _ in self.openDemoAdPage(adType: .novaInterstitialHighEngagement) }
            ),
            UIAction(
                title: "End Card 2 Parts", handler: { _ in self.openDemoAdPage(adType: .novaInterstitialEndCard) }),
        ]
        button6.menu = UIMenu(title: "Choose an option", children: novaInterstitialMenuItems)
        button6.showsMenuAsPrimaryAction = true

        let button7 = UIButton(type: .system)
        button7.setTitle("Facebook Native View", for: .normal)
        button7.addAction(
            UIAction { [weak self] _ in
                self?.openDemoAdPage(adType: .facebookNative)
            }, for: .touchUpInside)
        button7.frame = CGRect(x: 100, y: 400, width: 200, height: 50)
        view.addSubview(button7)

        let button8 = UIButton(type: .system)
        button8.setTitle("Facebook Interstitial View", for: .normal)
        button8.addAction(
            UIAction { [weak self] _ in
                self?.openDemoAdPage(adType: .facebookInterstitial)
            }, for: .touchUpInside)
        button8.frame = CGRect(x: 100, y: 450, width: 200, height: 50)
        view.addSubview(button8)

        let button9 = UIButton(type: .system)
        button9.setTitle("C2S Bidders Banner View", for: .normal)
        button9.frame = CGRect(x: 100, y: 500, width: 200, height: 50)
        view.addSubview(button9)
        let bannerMenuItems = [
            UIAction(title: "Unity", handler: { _ in self.openDemoAdPage(adType: .unityBanner) }),
            UIAction(title: "Pubmatic", handler: { _ in self.openDemoAdPage(adType: .pubmaticBanner) }),
            UIAction(title: "Inmobi", handler: { _ in self.openDemoAdPage(adType: .inmobiBanner) }),
            UIAction(title: "Mobilefuse", handler: { _ in self.openDemoAdPage(adType: .mobilefuseBanner) }),
            UIAction(title: "Mintegral", handler: { _ in self.openDemoAdPage(adType: .mintegralBanner) }),
        ]

        button9.menu = UIMenu(title: "Choose an option", children: bannerMenuItems)
        button9.showsMenuAsPrimaryAction = true


        let button10 = UIButton(type: .system)
        button10.setTitle("C2S Bidders Interstitial View", for: .normal)
        button10.frame = CGRect(x: 100, y: 550, width: 200, height: 50)
        view.addSubview(button10)
        let interstitialMenuItems = [
            UIAction(title: "Unity", handler: { _ in self.openDemoAdPage(adType: .unityInterstitial) }),
            UIAction(title: "Pubmatic", handler: { _ in self.openDemoAdPage(adType: .pubmaticInterstitial) }),
            UIAction(title: "Inmobi", handler: { _ in self.openDemoAdPage(adType: .inmobiInterstitial) }),
            UIAction(title: "Mobilefuse", handler: { _ in self.openDemoAdPage(adType: .mobilefuseInterstitial) }),
            UIAction(title: "Mintegral", handler: { _ in self.openDemoAdPage(adType: .mintegralInterstitial) }),
        ]

        button10.menu = UIMenu(title: "Choose an option", children: interstitialMenuItems)
        button10.showsMenuAsPrimaryAction = true


        let button11 = UIButton(type: .system)
        button11.setTitle("C2S Bidders Native View", for: .normal)
        button11.frame = CGRect(x: 100, y: 600, width: 200, height: 50)
        view.addSubview(button11)
        let nativeMenuItems = [
            UIAction(title: "Unity", handler: { _ in self.openDemoAdPage(adType: .unityNative) }),
            UIAction(title: "Pubmatic", handler: { _ in self.openDemoAdPage(adType: .pubmaticNative) }),
            UIAction(title: "Inmobi", handler: { _ in self.openDemoAdPage(adType: .inmobiNative) }),
            UIAction(title: "Mobilefuse", handler: { _ in self.openDemoAdPage(adType: .mobilefuseNative) }),
            UIAction(title: "Mintegral", handler: { _ in self.openDemoAdPage(adType: .mintegralNative) }),
        ]

        button11.menu = UIMenu(title: "Choose an option", children: nativeMenuItems)
        button11.showsMenuAsPrimaryAction = true


        let button12 = UIButton(type: .system)
        button12.setTitle("Client Bidding Banner", for: .normal)
        button12.addAction(
            UIAction { [weak self] _ in
                self?.openDemoAdPage(adType: .clientBiddingBanner)
            }, for: .touchUpInside)
        button12.frame = CGRect(x: 100, y: 650, width: 200, height: 50)
        view.addSubview(button12)

        let button13 = UIButton(type: .system)
        button13.setTitle("Prebid Interstitial", for: .normal)
        button13.addAction(
            UIAction { [weak self] _ in
                self?.openDemoAdPage(adType: .prebidInterstitial)
            }, for: .touchUpInside)
        button13.frame = CGRect(x: 100, y: 700, width: 200, height: 50)
        view.addSubview(button13)

        let debugButton = UIButton(type: .system)
        debugButton.setTitle("Debug Ad Load", for: .normal)
        debugButton.backgroundColor = .systemOrange
        debugButton.setTitleColor(.white, for: .normal)
        debugButton.layer.cornerRadius = 8
        debugButton.addAction(
            UIAction { _ in
                MSP.shared.showMediationDebugger()
            }, for: .touchUpInside)
        debugButton.frame = CGRect(x: 100, y: 750, width: 200, height: 50)
        view.addSubview(debugButton)
    }


    func openDemoAdPage(adType: AdType) {
        let demoAdVC = DemoAdViewController(adType: adType)
        navigationController?.pushViewController(demoAdVC, animated: true)
    }
}
