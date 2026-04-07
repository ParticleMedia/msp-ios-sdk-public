import MSPSnapKit
import UIKit

final class TestParamsCardView: UIView {
    // MARK: - State (read by VC at ad load time)

    private(set) var bannerSize = CGSize(width: 320, height: 50)

    private(set) var novaSandbox = false
    private(set) var testAd = false
    private(set) var adNetwork: String?
    private(set) var creativeType = TestParams.creativeTypes[0]
    private(set) var creativeLayout: String? = TestParams.creativeLayouts[0]
    private(set) var enableH5Format = true
    private(set) var h5TemplateGroup = TestParams.h5TemplateGroupsImageVideo[2]
    private(set) var preload = true

    // MARK: - Private UI refs

    private weak var innerStack: UIStackView?
    private weak var divider: UIView?
    private weak var novaSection: UIStackView?
    private weak var creativeTypeChips: ChipFlowView?
    private weak var h5TemplateChips: ChipFlowView?
    private weak var preloadElements: UIStackView?
    private weak var h5TemplateSection: UIStackView?

    private let format: AdFormat

    // MARK: - Init

    init(format: AdFormat) {
        self.format = format
        super.init(frame: .zero)
        setupCard()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    private func setupCard() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12
        clipsToBounds = true

        let outerStack = UIStackView()
        outerStack.axis = .vertical
        outerStack.spacing = 0
        addSubview(outerStack)
        outerStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        outerStack.addArrangedSubview(buildHeaderRow())

        if format == .banner {
            let sizeDiv = UIView()
            sizeDiv.backgroundColor = .separator
            sizeDiv.snp.makeConstraints { make in make.height.equalTo(0.5) }
            outerStack.addArrangedSubview(sizeDiv)
            outerStack.addArrangedSubview(buildBannerSizeSection())
        }

        let div = UIView()
        div.backgroundColor = .separator
        div.snp.makeConstraints { make in make.height.equalTo(0.5) }
        div.isHidden = true
        divider = div
        outerStack.addArrangedSubview(div)

        outerStack.addArrangedSubview(buildInnerStack())
    }

    private func buildHeaderRow() -> UIView {
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8
        header.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        header.isLayoutMarginsRelativeArrangement = true

        let toggle = UISwitch()
        toggle.isOn = false
        toggle.addAction(
            UIAction { [weak self] action in
                guard let self, let toggle = action.sender as? UISwitch else { return }
                self.innerStack?.isHidden = !toggle.isOn
                self.divider?.isHidden = !toggle.isOn
            }, for: .valueChanged)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        header.addArrangedSubview(fieldLabel("Test Params"))
        header.addArrangedSubview(toggle)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(fieldLabel("Nova Sandbox"))
        header.addArrangedSubview(buildCheckbox { [weak self] checked in self?.novaSandbox = checked })
        return header
    }

    private func buildInnerStack() -> UIStackView {
        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 12
        inner.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)
        inner.isLayoutMarginsRelativeArrangement = true
        inner.isHidden = true
        innerStack = inner

        // Test Ad
        let testAdRow = UIStackView()
        testAdRow.axis = .horizontal
        testAdRow.alignment = .center
        testAdRow.spacing = 8
        testAdRow.addArrangedSubview(fieldLabel("Test Ad"))
        testAdRow.addArrangedSubview(buildCheckbox { [weak self] checked in self?.testAd = checked })
        inner.addArrangedSubview(testAdRow)

        // Ad Network
        inner.addArrangedSubview(fieldLabel("Ad Network"))
        inner.addArrangedSubview(
            ChipFlowView(options: TestParams.adNetworks, selected: nil) { [weak self] selected in
                guard let self else { return }
                self.adNetwork = selected
                self.novaSection?.isHidden = (selected != "msp_nova")
            }
        )

        // Nova section
        let nova = buildNovaSection()
        nova.isHidden = true
        novaSection = nova
        inner.addArrangedSubview(nova)

        return inner
    }

    private func buildNovaSection() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        stack.addArrangedSubview(fieldLabel("Creative Type"))
        let ctOptions =
            (format == .interstitial)
            ? TestParams.creativeTypes
            : TestParams.creativeTypes.filter { $0 != "playable_video" }
        let ctChips = ChipFlowView(options: ctOptions, selected: creativeType) { [weak self] selected in
            guard let self else { return }
            if let selected { self.creativeType = selected }
            self.updateH5TemplateOptions()
        }
        creativeTypeChips = ctChips
        stack.addArrangedSubview(ctChips)

        stack.addArrangedSubview(fieldLabel("Creative Layout"))
        stack.addArrangedSubview(
            ChipFlowView(options: TestParams.creativeLayouts, selected: creativeLayout) { [weak self] selected in
                self?.creativeLayout = selected
            }
        )

        if format == .interstitial {
            stack.addArrangedSubview(buildH5Section())
        }
        return stack
    }

    private func buildH5Section() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.addArrangedSubview(fieldLabel("Enable H5 Format"))
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        let h5Toggle = UISwitch()
        h5Toggle.isOn = enableH5Format
        row.addArrangedSubview(h5Toggle)

        let preloadStack = UIStackView()
        preloadStack.axis = .horizontal
        preloadStack.alignment = .center
        preloadStack.spacing = 8
        preloadStack.addArrangedSubview(fieldLabel("Preload"))
        let preloadSwitch = UISwitch()
        preloadSwitch.isOn = preload
        preloadSwitch.addAction(
            UIAction { [weak self] action in
                guard let self, let toggle = action.sender as? UISwitch else { return }
                self.preload = toggle.isOn
            }, for: .valueChanged)
        preloadStack.addArrangedSubview(preloadSwitch)
        preloadStack.isHidden = !enableH5Format
        preloadElements = preloadStack
        row.addArrangedSubview(preloadStack)

        h5Toggle.addAction(
            UIAction { [weak self] action in
                guard let self, let toggle = action.sender as? UISwitch else { return }
                self.enableH5Format = toggle.isOn
                self.preloadElements?.isHidden = !toggle.isOn
                self.h5TemplateSection?.isHidden = !toggle.isOn
            }, for: .valueChanged)
        stack.addArrangedSubview(row)

        let templateSection = UIStackView()
        templateSection.axis = .vertical
        templateSection.spacing = 12
        templateSection.isHidden = !enableH5Format
        h5TemplateSection = templateSection

        templateSection.addArrangedSubview(fieldLabel("H5 Template Group"))
        let chips = ChipFlowView(
            options: TestParams.h5TemplateGroupsImageVideo,
            selected: h5TemplateGroup
        ) { [weak self] selected in
            if let selected { self?.h5TemplateGroup = selected }
        }
        h5TemplateChips = chips
        templateSection.addArrangedSubview(chips)
        stack.addArrangedSubview(templateSection)
        return stack
    }

    private func updateH5TemplateOptions() {
        let options =
            (creativeType == "playable_video")
            ? TestParams.h5TemplateGroupsPlayableVideo
            : TestParams.h5TemplateGroupsImageVideo
        if !options.contains(h5TemplateGroup) { h5TemplateGroup = options[0] }
        h5TemplateChips?.reload(options: options, selected: h5TemplateGroup)
    }

    // MARK: - Helpers

    private func buildBannerSizeSection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true

        stack.addArrangedSubview(fieldLabel("Ad Size"))

        // "×" is U+00D7 MULTIPLICATION SIGN (not ASCII "x") — display only, not used as a key
        let sizeOptions = ["320×50", "300×250", "320×480"]
        let sizeMap: [String: CGSize] = [
            "320×50": CGSize(width: 320, height: 50),
            "300×250": CGSize(width: 300, height: 250),
            "320×480": CGSize(width: 320, height: 480),
        ]
        stack.addArrangedSubview(
            ChipFlowView(options: sizeOptions, selected: "320×50") { [weak self] selected in
                guard let self, let selected else { return }
                self.bannerSize = sizeMap[selected] ?? CGSize(width: 320, height: 50)
            }
        )
        return stack
    }

    private func buildCheckbox(onChange: @escaping (Bool) -> Void) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "square")
        config.baseForegroundColor = .secondaryLabel
        config.contentInsets = .zero
        let btn = UIButton(configuration: config)
        btn.automaticallyUpdatesConfiguration = false
        btn.addAction(
            UIAction { [weak btn] _ in
                guard let btn else { return }
                btn.isSelected.toggle()
                var updated = btn.configuration
                updated?.image = UIImage(systemName: btn.isSelected ? "checkmark.square.fill" : "square")
                updated?.baseForegroundColor = btn.isSelected ? .systemBlue : .secondaryLabel
                btn.configuration = updated
                onChange(btn.isSelected)
            }, for: .touchUpInside)
        return btn
    }

    private func fieldLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .secondaryLabel
        return l
    }
}
