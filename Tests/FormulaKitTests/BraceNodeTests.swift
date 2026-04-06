import CoreGraphics
import XCTest

@testable import FormulaKit

/// Layout and ink metrics for horizontal braces (OpenType STIX masters or reference `svgGeometry.js` paths).
final class BraceNodeTests: XCTestCase {
    func testUnderbraceLayoutNonEmpty() {
        let node = BraceNode(isOver: false, targetWidth: 200, fontSize: 16)
        let box = node.getBox(options: FormulaKit.Options(style: .display, fontSize: 16))
        XCTAssertGreaterThan(box.width, 0)
        XCTAssertGreaterThan(box.height + box.depth, 0)
    }

    /// STIX Two Math ships ``uni23DF``…``.s5``; when installed, `\underbrace` should emit a text run instead of only vector ink.
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
