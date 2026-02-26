import Combine
import Nimble
import Quick

@testable import MSPCore
@testable import MSPiOSCore

class DebugAdLoadSectionViewModelSpec: QuickSpec {
    override class func spec() {
        describe("DebugAdLoadSectionViewModel") {
            @TestState var options: [DebugOption]!
            @TestState var sectionData: FakeDebugSection!

            beforeEach {
                options = [
                    FakeDebugOption(id: "option-1", displayTitle: "Option 1"),
                    FakeDebugOption(id: "option-2", displayTitle: "Option 2"),
                ]
                sectionData = FakeDebugSection(
                    id: "section-id",
                    title: "Section Title",
                    options: options
                )
            }

            context("when initialized with section data") {
                it("[DAL001] should create view models from section data") {
                    let sut = DebugAdLoadSectionViewModel(from: sectionData)

                    expect(sut.id).to(equal(sectionData.id))
                    expect(sut.title).to(equal(sectionData.title))
                    expect(sut.numberOfCells).to(equal(options.count))
                    expect(sut.cellViewModel(at: 0)?.id).to(equal(options[0].id))
                }

                it("[DAL002] should return nil for out-of-bounds access") {
                    let sut = DebugAdLoadSectionViewModel(from: sectionData)

                    expect(sut.cellViewModel(at: -1)).to(beNil())
                    expect(sut.cellViewModel(at: options.count)).to(beNil())
                }
            }

            context("when selecting a cell") {
                it("[DAL003] should update selection state and return the selected cell") {
                    let sut = DebugAdLoadSectionViewModel(from: sectionData)

                    sut.selectCell(at: 1)

                    expect(sut.selectedIndex()).to(equal(1))
                    expect(sut.selectedCell()?.id).to(equal(options[1].id))
                    expect(sut.cellViewModel(at: 0)?.isSelected).to(beFalse())
                    expect(sut.cellViewModel(at: 1)?.isSelected).to(beTrue())
                }
            }

            context("when toggling visibility") {
                it("[DAL004] should toggle visibility state") {
                    let sut = DebugAdLoadSectionViewModel(from: sectionData)

                    expect(sut.visible).to(beTrue())
                    sut.visible = false
                    expect(sut.visible).to(beFalse())
                }
            }

            context("with empty options") {
                it("[DAL005] should handle empty options gracefully") {
                    let emptySection = FakeDebugSection(id: "empty", title: "Empty", options: [])
                    let sut = DebugAdLoadSectionViewModel(from: emptySection)

                    expect(sut.numberOfCells).to(equal(0))
                    expect(sut.selectedIndex()).to(beNil())
                    expect(sut.selectedCell()).to(beNil())
                }
            }
        }
    }
}
