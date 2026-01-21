import Combine
import Nimble
import Quick
@testable import MSPCore
@testable import MSPiOSCore

class DebugAdLoadSectionViewModelSpec: QuickSpec {
    override class func spec() {
        describe("DebugAdLoadSectionViewModel") {
            var options: [DebugOption]!
            var sectionData: MockDebugSection!

            beforeEach {
                options = [
                    MockDebugOption(id: "option-1", displayTitle: "Option 1"),
                    MockDebugOption(id: "option-2", displayTitle: "Option 2")
                ]
                sectionData = MockDebugSection(
                    id: "section-id",
                    title: "Section Title",
                    options: options
                )
            }

            it("creates view models from section data") {
                let sut = DebugAdLoadSectionViewModel(from: sectionData)

                expect(sut.id).to(equal(sectionData.id))
                expect(sut.title).to(equal(sectionData.title))
                expect(sut.numberOfCells).to(equal(options.count))
                expect(sut.cellViewModel(at: 0)?.id).to(equal(options[0].id))
            }

            it("exposes accessors and respects bounds") {
                let sut = DebugAdLoadSectionViewModel(from: sectionData)

                expect(sut.cellViewModel(at: -1)).to(beNil())
                expect(sut.cellViewModel(at: options.count)).to(beNil())
            }

            it("updates selection state and returns the selected cell") {
                let sut = DebugAdLoadSectionViewModel(from: sectionData)

                sut.selectCell(at: 1)

                expect(sut.selectedIndex()).to(equal(1))
                expect(sut.selectedCell()?.id).to(equal(options[1].id))
                expect(sut.cellViewModel(at: 0)?.isSelected).to(beFalse())
                expect(sut.cellViewModel(at: 1)?.isSelected).to(beTrue())
            }

            it("toggles visibility") {
                let sut = DebugAdLoadSectionViewModel(from: sectionData)

                expect(sut.visible).to(beTrue())
                sut.visible = false
                expect(sut.visible).to(beFalse())
            }

            it("handles empty options") {
                let emptySection = MockDebugSection(id: "empty", title: "Empty", options: [])
                let sut = DebugAdLoadSectionViewModel(from: emptySection)

                expect(sut.numberOfCells).to(equal(0))
                expect(sut.selectedIndex()).to(beNil())
                expect(sut.selectedCell()).to(beNil())
            }
        }
    }
}
