import Foundation
import Combine
import MSPiOSCore
import UIKit

struct ToastSignal {
    let message: String
    let style: DebugToastStyle
    let duration: TimeInterval?
}

enum DebugAdPresentationSignal {
    case native(nativeAd: NativeAd)
    case banner(bannerAd: BannerAd)
    case interstitial(interstitialAd: InterstitialAd)
}

class DebugAdLoadViewModel: AdListener {
    @Published private(set) var sections: [DebugAdLoadSectionViewModel] = []
    private let originalSectionData: [DebugSection]
    let placements: [String]
    var visibleSectionsPublisher: AnyPublisher<[DebugAdLoadSectionViewModel], Never> {
        $sections.map { $0.filter { $0.visible } }.eraseToAnyPublisher()
    }
    
    private let repository: DebugSectionsRepository
    private let loadAdRepository: LoadAdRepository
    private var adLoader: MSPAdLoader?
    private(set) var ad: MSPAd?
    
    // Toast signal publisher
    private let toastSignalSubject = PassthroughSubject<ToastSignal, Never>()
    var toastSignalPublisher: AnyPublisher<ToastSignal, Never> {
        toastSignalSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    // Ad presentation signal publisher
    private let adPresentationSubject = PassthroughSubject<DebugAdPresentationSignal, Never>()
    var adPresentationPublisher: AnyPublisher<DebugAdPresentationSignal, Never> {
        adPresentationSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    
    init(
        repository: DebugSectionsRepository = TestDebugSectionsService(),
        placementsRepository: PlacementsRepository = TestPlacementsService(),
        loadAdRepository: LoadAdRepository = LoadAdService()
    ) {
        self.repository = repository
        self.placements = placementsRepository.fetchPlacements()
        self.originalSectionData = repository.fetchDebugSections(placements: self.placements)
        self.loadAdRepository = loadAdRepository
        self.sections = createSectionViewModels()
        setDefaultSelections()
        updateSectionVisibility()
    }
    
    private func createSectionViewModels() -> [DebugAdLoadSectionViewModel] {
        return originalSectionData.enumerated().map { index, data in
            let sectionViewModel = DebugAdLoadSectionViewModel(from: data)
            
            // Set initial visibility based on showCondition
            sectionViewModel.visible = shouldShowSection(data)
            
            return sectionViewModel
        }
    }
    
    private func shouldShowSection(_ section: DebugSection) -> Bool {
        guard let showCondition = section.showCondition else {
            // If showCondition is nil, section is always visible
            return true
        }
        
        // Check if all required option IDs are in the current selection
        let selectedOptionIds = getSelectedOptionIds()
        return showCondition.isSubset(of: selectedOptionIds)
    }
    
    private func getSelectedOptionIds() -> Set<String> {
        var selectedIds: Set<String> = []
        
        for section in sections {
            if let selectedCell = section.selectedCell() {
                selectedIds.insert(selectedCell.id)
            }
        }
        
        return selectedIds
    }
    
    private func setDefaultSelections() {
        // Set default selections based on showCondition requirements
        for (index, section) in sections.enumerated() {
            if index < originalSectionData.count {
                let sectionData = originalSectionData[index]
                
                // If this section has a showCondition, set the first available option as default
                if let showCondition = sectionData.showCondition {
                    for requiredId in showCondition {
                        for i in 0..<section.numberOfCells {
                            if let cell = section.cellViewModel(at: i), cell.id == requiredId {
                                section.selectCell(at: i)
                                break
                            }
                        }
                    }
                } else {
                    // For sections without showCondition, set the first option as default
                    if section.numberOfCells > 0 {
                        section.selectCell(at: 0)
                    }
                }
            }
        }
    }
    
    func selectOption(section: Int, row: Int) {
        let sectionVM = sections[section]
        sectionVM.selectCell(at: row)
        updateSectionVisibility()
        // Trigger Combine update
        sections = sections
    }
    
    func updateSectionVisibility() {
        // Update visibility for all sections based on their showCondition
        for (index, section) in sections.enumerated() {
            if index < originalSectionData.count {
                let shouldShow = shouldShowSection(originalSectionData[index])
                section.visible = shouldShow
            }
        }
    }
    
    // Get test parameters from selected options
    func getTestParameters() -> [String: String] {
        var params: [String: String] = [:]
        
        // Add parameters from each selected option
        for (index, section) in sections.enumerated() {
            if let selectedCell = section.selectedCell(),
               index < originalSectionData.count {
                let originalOptions = originalSectionData[index].options
                if let selectedOption = originalOptions.first(where: { $0.id == selectedCell.id }) {
                    // Check if the option conforms to TestParamPresentable
                    if let testParamOption = selectedOption as? TestParamPresentable {
                        for (key, value) in testParamOption.keyValuePairs {
                            params[key] = value
                        }
                    }
                }
            }
        }
        
        return params
    }
    
    func getSelectedOptions() -> [String: DebugOption] {
        var selectedOptions: [String: DebugOption] = [:]
        
        for section in sections {
            if let selectedCell = section.selectedCell() {
                selectedOptions[section.title] = selectedCell.debugOption
            }
        }
        
        return selectedOptions
    }
    
    /// Generates placement ID based on current selections
    func generatePlacementId() -> String? {
        let selectedOptions = Array(getSelectedOptions().values)
        return TestPlacementsService().fetchPlacements(from: selectedOptions)
    }
    
    /// Loads an ad using the current selections
    func loadAd() {
        guard let placementId = generatePlacementId() else {
            toastSignalSubject.send(ToastSignal(message: "Failed to generate placement ID", style: .error, duration: nil))
            return
        }
        let selectedOptions = getSelectedOptions()
        let adFormat = selectedOptions.values.compactMap { $0 as? AdFormat }.first ?? .banner
        let testParams = getTestParameters()
        let adLoader = MSPAdLoader()
        self.adLoader = adLoader
        toastSignalSubject.send(ToastSignal(message: "Loading...", style: .loading, duration: nil))
        loadAdRepository.loadAd(
            placementId: placementId,
            adFormat: adFormat,
            testParams: testParams,
            adListener: self,
            customParams: nil
        )
    }
    
    // MARK: - AdListener
    func onError(msg: String) {
        print("[DebugAdLoadViewModel] Ad error: \(msg)")
        toastSignalSubject.send(ToastSignal(message: msg, style: .error, duration: nil))
    }
    func onAdImpression(ad: MSPAd) {
        print("[DebugAdLoadViewModel] Ad impression: \(ad)")
    }
    func onAdClick(ad: MSPAd) {
        print("[DebugAdLoadViewModel] Ad click: \(ad)")
    }
    func onAdLoaded(placementId: String) {
        guard let ad = self.adLoader?.getAd(placementId: placementId) else {
            print("[DebugAdLoadViewModel] No ad found for placementId: \(placementId)")
            toastSignalSubject.send(ToastSignal(message: "No ad found for placementId", style: .error, duration: nil))
            return
        }
        self.ad = ad
        print("[DebugAdLoadViewModel] Ad loaded for placementId: \(placementId)")
        toastSignalSubject.send(ToastSignal(message: "Ad loaded successfully", style: .success, duration: 2.0))
        if let price = ad.adInfo[MSPConstants.AD_INFO_PRICE] as? Double {
            print("[DebugAdLoadViewModel] Ad price: \(price)")
        }
        if let adNetworkName = ad.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] as? String {
            print("[DebugAdLoadViewModel] Ad network: \(adNetworkName)")
        }
        if let adUnitId = ad.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] {
            print("[DebugAdLoadViewModel] Ad unit id: \(adUnitId)")
        }
        if let creativeId = ad.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] {
            print("[DebugAdLoadViewModel] Creative id: \(creativeId)")
        }
        if let nativeAd = ad as? NativeAd {
            adPresentationSubject.send(.native(nativeAd: nativeAd))
        } else if let bannerAd = ad as? BannerAd {
            adPresentationSubject.send(.banner(bannerAd: bannerAd))
        } else if let interstitialAd = ad as? InterstitialAd {
            adPresentationSubject.send(.interstitial(interstitialAd: interstitialAd))
        }
    }
    func onAdDismissed(ad: InterstitialAd) {
        print("[DebugAdLoadViewModel] Interstitial ad dismissed: \(ad)")
    }
    func getRootViewController() -> UIViewController? {
        // This should be set by the view controller if needed
        return nil
    }
} 
