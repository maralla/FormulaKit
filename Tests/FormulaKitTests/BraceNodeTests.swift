import Foundation
import XCTest

@testable import FormulaKit

final class BraceNodeTests: XCTestCase {
    func testUnderbraceLayoutNonEmpty() {
        let node = BraceNode(isOver: false, targetWidth: 200, fontSize: 16)
        let box = node.getBox(options: FormulaKit.Options(style: .display, fontSize: 16))
        XCTAssertGreaterThan(box.width, 0)
        XCTAssertGreaterThan(box.height + box.depth, 0)
    }

    func testUnderbraceUsesOpenTypeGlyphWhenSTIXAvailable() throws {
        guard STIX.isPrimaryMathFontAvailable(forFontSize: 16) else { return }
        let layout = try FormulaKit.render(#"\underbrace{ab}_{x}"#)
        let braceRuns = layout.textRuns.filter { ($0.openTypeMathGlyphName ?? "").contains("23DF") }
        XCTAssertFalse(
            braceRuns.isEmpty,
            "expected uni23DF(.sN) brace glyph via Core Text when STIX Two Math is present"
        )
    }
}
