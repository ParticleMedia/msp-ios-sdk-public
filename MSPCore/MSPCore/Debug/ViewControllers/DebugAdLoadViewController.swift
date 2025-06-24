import UIKit
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
    // Strings
    static let title = "msp-ios"
    static let loadAdTitle = "LOAD AD"
    static let destroyTitle = "DESTROY!"
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
    
    private func bindViewModel() {
        viewModel.visibleSectionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sections in
                self?.visibleSections = sections
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        // Set initial value
        visibleSections = viewModel.sections.filter { $0.isVisible }
    }
    
    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return visibleSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleSections[section].cellViewModels.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return visibleSections[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellVM = visibleSections[indexPath.section].cellViewModels[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: UIConfig.radioCellReuseId, for: indexPath)
        cell.textLabel?.text = cellVM.title
        cell.accessoryType = cellVM.isSelected ? .checkmark : .none
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sectionIdx = indexPath.section
        let rowIdx = indexPath.row
        guard let realSectionIdx = viewModel.sections.firstIndex(where: { $0 === visibleSections[sectionIdx] }) else { return }
        viewModel.selectOption(section: realSectionIdx, row: rowIdx)
    }
} 