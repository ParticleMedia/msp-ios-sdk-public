import UIKit
import MSPiOSCore
import SnapKit
import Combine

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
                ToastManager.shared.show(message: signal.message, style: signal.style, in: self.view, duration: duration)
            }
            .store(in: &cancellables)

        viewModel.adPresentationPublisher
            .sink { [weak self] signal in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch signal {
                    case .native(let nativeAd):
                        let container = DebugNativeAdContainer(frame: CGRect(origin: .zero, size: UIConfig.nativeAdSize))
                        let adView = NativeAdView(nativeAd: nativeAd, nativeAdContainer: container)
                        let adVC = DebugAdContainerViewController(adView: adView, preferredSize: UIConfig.nativeAdSize)
                        self.navigationController?.pushViewController(adVC, animated: true)
                    case .banner(let bannerAd):
                        let adView = bannerAd.adView
                        let adVC = DebugAdContainerViewController(adView: adView, preferredSize: UIConfig.bannerAdSize)
                        self.navigationController?.pushViewController(adVC, animated: true)
                    case .interstitial(let interstitialAd):
                        interstitialAd.show(rootViewController: self)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return visibleSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // For placement section, return 0 rows when collapsed
        if visibleSections[section].title == DebugSectionData.SectionTitles.placement && !viewModel.isPlacementSectionVisible {
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
        return 44
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
        guard let realSectionIdx = viewModel.sections.firstIndex(where: { $0 === visibleSections[sectionIdx] }) else { return }
        viewModel.selectOption(section: realSectionIdx, row: rowIdx)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
