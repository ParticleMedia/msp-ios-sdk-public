import Combine
@_implementationOnly import MSPSnapKit
import MSPiOSCore
import UIKit

private enum UIConfig {
    // Layout
    static let tableBottomInset: CGFloat = 80
    static let buttonLeading: CGFloat = 24
    static let buttonTrailing: CGFloat = 24
    static let buttonBottom: CGFloat = 16
    static let buttonHeight: CGFloat = 48
    static let buttonSpacing: CGFloat = 16
    static let buttonFontSize: CGFloat = 18
    static let buttonCornerRadius: CGFloat = 6
    // Ad Sizes
    static let nativeAdSize = CGSize(width: 300, height: 250)
    static let bannerAdSize = CGSize(width: 320, height: 50)
    // Strings
    static let title = "MSP Debug"
    static let loadAdTitle = "Load Ad"
    static let destroyTitle = "Destroy!"
    static let radioCellReuseId = "RadioCell"
    static let toggleCellReuseId = "ToggleCell"
    static let chipGroupCellReuseId = "ChipGroupCell"
}

class DebugAdLoadViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let viewModel = DebugAdLoadViewModel()
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let loadAdButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(UIConfig.loadAdTitle, for: .normal)
        btn.backgroundColor = .systemPurple
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: UIConfig.buttonFontSize)
        btn.layer.cornerRadius = UIConfig.buttonCornerRadius
        return btn
    }()
    private let destroyButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(UIConfig.destroyTitle, for: .normal)
        btn.backgroundColor = .systemGray5
        btn.setTitleColor(.systemGray, for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: UIConfig.buttonFontSize)
        btn.layer.cornerRadius = UIConfig.buttonCornerRadius
        btn.isEnabled = false
        return btn
    }()
    private var visibleSections: [DebugAdLoadSectionViewModel] = []
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = UIConfig.title
        view.backgroundColor = .white
        viewModel.setViewController(self)
        setupTableView()
        setupButtons()
        bindViewModel()
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: UIConfig.radioCellReuseId)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: UIConfig.toggleCellReuseId)
        tableView.register(DebugChipGroupCell.self, forCellReuseIdentifier: UIConfig.chipGroupCellReuseId)
        tableView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(UIConfig.tableBottomInset)
        }
    }

    private func setupButtons() {
        view.addSubview(loadAdButton)
        view.addSubview(destroyButton)

        // Add action handlers
        loadAdButton.addTarget(self, action: #selector(loadAdButtonTapped), for: .touchUpInside)

        loadAdButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConfig.buttonLeading)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(UIConfig.buttonBottom)
            make.height.equalTo(UIConfig.buttonHeight)
            make.trailing.equalTo(destroyButton.snp.leading).offset(-UIConfig.buttonSpacing)
            make.width.equalTo(destroyButton)
        }
        destroyButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConfig.buttonTrailing)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(UIConfig.buttonBottom)
            make.height.equalTo(UIConfig.buttonHeight)
            make.width.equalTo(loadAdButton)
        }
    }

    @objc private func loadAdButtonTapped() {
        viewModel.loadAd()
    }

    private func bindViewModel() {
        viewModel.visibleSectionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sections in
                self?.visibleSections = sections
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        // Set initial value
        visibleSections = viewModel.sections.filter { $0.visible }

        viewModel.toastSignalPublisher
            .sink { [weak self] signal in
                guard let self = self else { return }
                let duration = signal.duration ?? 2.0
                ToastManager.shared.dismiss()
                ToastManager.shared.show(
                    message: signal.message, style: signal.style, in: self.view, duration: duration)
            }
            .store(in: &cancellables)

        viewModel.adPresentationPublisher
            .sink { [weak self] signal in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch signal {
                    case .native(let nativeAd):
                        let container = DebugNativeAdContainer(
                            frame: CGRect(origin: .zero, size: UIConfig.nativeAdSize))
                        let adView = NativeAdView(nativeAd: nativeAd, nativeAdContainer: container)
                        let adVC = DebugAdContainerViewController(
                            adView: adView,
                            preferredSize: UIConfig.nativeAdSize,
                            nativeAd: nativeAd
                        )
                        self.navigationController?.pushViewController(adVC, animated: true)
                    case .banner(let bannerAd):
                        let adView = bannerAd.adView
                        let adVC = DebugAdContainerViewController(adView: adView, preferredSize: UIConfig.bannerAdSize)
                        self.navigationController?.pushViewController(adVC, animated: true)
                    case .interstitial(let interstitialAd):
                        interstitialAd.show(rootViewController: self)
                    case .rewarded(let rewardedAd):
                        rewardedAd.show(rootViewController: self)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        visibleSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // For placement section, return 0 rows when collapsed
        if visibleSections[section].title == DebugSectionData.SectionTitles.placement
            && !viewModel.isPlacementSectionVisible
        {
            return 0
        }
        return visibleSections[section].numberOfCells
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let isPlacementSection = visibleSections[section].title == DebugSectionData.SectionTitles.placement
        let headerView = DebugSectionHeaderView(isPlacementSection: isPlacementSection)
        headerView.title = visibleSections[section].title

        if isPlacementSection {
            headerView.isExpanded = viewModel.isPlacementSectionVisible
            headerView.tapAction = {
                [weak self] in
                self?.placementSectionHeaderTapped()
            }
        }

        return headerView
    }

    @objc private func placementSectionHeaderTapped() {
        viewModel.togglePlacementSection()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        44
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionVM = visibleSections[indexPath.section]

        if sectionVM.isChipGroupCell(at: indexPath.row) {
            guard
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: UIConfig.chipGroupCellReuseId, for: indexPath) as? DebugChipGroupCell
            else { return UITableViewCell() }
            guard let chipVM = sectionVM.chipGroupCellViewModel(at: indexPath.row) else { return cell }
            cell.configure(with: chipVM)
            cell.onChipTapped = { [weak self, weak chipVM] tappedId in
                chipVM?.selectOption(id: tappedId)
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            }
            return cell
        }

        if sectionVM.isToggleCell(at: indexPath.row) {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: UIConfig.toggleCellReuseId, for: indexPath)
            guard let toggleVM = sectionVM.toggleCellViewModel(at: indexPath.row) else { return cell }
            cell.textLabel?.text = toggleVM.title
            cell.selectionStyle = .none
            let toggle = UISwitch()
            toggle.isOn = toggleVM.isOn
            toggle.addTarget(self, action: #selector(toggleValueChanged(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            return cell
        }

        let cellVM = visibleSections[indexPath.section].cellViewModel(at: indexPath.row)!
        let cell = tableView.dequeueReusableCell(withIdentifier: UIConfig.radioCellReuseId, for: indexPath)
        cell.textLabel?.text = cellVM.title
        cell.accessoryType = cellVM.isSelected ? .checkmark : .none
        cell.selectionStyle = .none
        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sectionIdx = indexPath.section
        let rowIdx = indexPath.row
        // Chip-group cells handle their own interaction via onChipTapped; skip radio selection logic.
        guard !visibleSections[sectionIdx].isChipGroupCell(at: rowIdx) else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        // Toggle cells handle their own interaction via UISwitch; skip radio selection logic.
        guard !visibleSections[sectionIdx].isToggleCell(at: rowIdx) else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        guard let realSectionIdx = viewModel.sections.firstIndex(where: { $0 === visibleSections[sectionIdx] }) else {
            return
        }
        viewModel.selectOption(section: realSectionIdx, row: rowIdx)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    @objc private func toggleValueChanged(_ sender: UISwitch) {
        // Walk the view hierarchy to find the enclosing UITableViewCell.
        var view: UIView? = sender
        while let current = view, !(current is UITableViewCell) {
            view = current.superview
        }
        guard let cell = view as? UITableViewCell,
            let indexPath = tableView.indexPath(for: cell)
        else { return }
        visibleSections[indexPath.section]
            .toggleCellViewModel(at: indexPath.row)?
            .setOn(sender.isOn)
    }
}
