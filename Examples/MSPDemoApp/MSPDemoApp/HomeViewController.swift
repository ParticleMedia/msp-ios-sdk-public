import MSPCore
import MSPSnapKit
import MSPiOSCore
import UIKit

final class HomeViewController: UIViewController {

    private enum MenuItem: String, CaseIterable {
        case banner = "Banner"
        case native = "Native"
        case interstitial = "Interstitial"
        case rewarded = "Rewarded"
        case debugAdLoader = "Debug Ad Loader"
        case legacyTest = "Legacy Test"
        case webDebugger = "Web Debugger"
    }

    private weak var tableView: UITableView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupProfileTitleView()
        setupInfoButton()
        setupTableView()
    }

    // MARK: - Info Button

    private func setupInfoButton() {
        let btn = UIBarButtonItem(
            image: UIImage(systemName: "info.circle")?
                .withRenderingMode(.alwaysTemplate),
            style: .plain,
            target: self,
            action: #selector(infoTapped)
        )
        btn.tintColor = .secondaryLabel
        navigationItem.rightBarButtonItem = btn
    }

    @objc private func infoTapped() {
        let vc = UINavigationController(rootViewController: AppInfoSheetViewController())
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }

    // MARK: - Profile Switcher

    private func setupProfileTitleView() {
        let menuItems = AppProfile.profiles.enumerated().map { index, profile in
            UIAction(
                title: profile.appName,
                state: index == AppProfile.selectedIndex ? .on : .off
            ) { [weak self] _ in
                self?.switchToProfile(at: index)
            }
        }
        let menu = UIMenu(title: "", children: menuItems)

        var config = UIButton.Configuration.plain()
        config.title = AppProfile.current.appName
        config.image = UIImage(systemName: "arrowtriangle.down.fill",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 9))
        config.imagePlacement = .trailing
        config.imagePadding = 4
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var updated = attrs
            updated.font = .boldSystemFont(ofSize: 17)
            return updated
        }
        let titleButton = UIButton(configuration: config)
        titleButton.tintColor = .label
        titleButton.menu = menu
        titleButton.showsMenuAsPrimaryAction = true
        navigationItem.titleView = titleButton
    }

    private func switchToProfile(at index: Int) {
        guard index != AppProfile.selectedIndex else { return }
        let profile = AppProfile.profiles[index]
        let alert = UIAlertController(
            title: "Switch Profile",
            message: "Switch to \"\(profile.appName)\"? The app will close — please relaunch to apply the new profile.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Switch & Close", style: .destructive) { _ in
            AppProfile.selectedIndex = index
            exit(0)
        })
        present(alert, animated: true)
    }

    // MARK: - Table View

    private func setupTableView() {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.isScrollEnabled = false
        view.addSubview(tableView)
        self.tableView = tableView

        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}

// MARK: - UITableViewDataSource

extension HomeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        MenuItem.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let item = MenuItem.allCases[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = item.rawValue
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

// MARK: - UITableViewDelegate

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch MenuItem.allCases[indexPath.row] {
        case .banner:
            navigationController?.pushViewController(AdTestViewController(format: .banner, placements: AppProfile.current.bannerPlacements), animated: true)
        case .native:
            navigationController?.pushViewController(AdTestViewController(format: .native, placements: AppProfile.current.nativePlacements), animated: true)
        case .interstitial:
            navigationController?.pushViewController(AdTestViewController(format: .interstitial, placements: AppProfile.current.interstitialPlacements), animated: true)
        case .rewarded:
            navigationController?.pushViewController(AdTestViewController(format: .rewarded, placements: AppProfile.current.rewardedPlacements), animated: true)
        case .debugAdLoader:
            MSP.shared.showMediationDebugger()
        case .legacyTest:
            navigationController?.pushViewController(LegacyTestViewController(), animated: true)
        case .webDebugger:
            navigationController?.pushViewController(WebDebugViewController(), animated: true)
        }
    }
}
