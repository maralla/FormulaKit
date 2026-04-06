import XCTest

@testable import FormulaKit

/// Swift analogue of the reference JS test harness `expect`…`.toBuild()` (`test/setup.js` + parser spec tests):
/// if the reference stack can build HTML for the expression, FormulaKit should produce non-empty drawable output.
final class RendererTests: XCTestCase {

    private let scriptSmokeExpressions = [
        "x^2",
        "x_3",
        "x^2_3",
        "x_2^3",
        "x^{2+3}",
        "x_{3-2}",
    ]

    func test_referenceBuild_basicScripts() throws {
        let options = FormulaKit.Options.default
        for expr in scriptSmokeExpressions {
            let tree = try FormulaKit.parse(expr, options: options)
            let layout = Renderer(options: options).render(node: tree)
            let hasInk = !layout.textRuns.isEmpty || !layout.decorationPath.boundingBoxOfPath.isEmpty
            XCTAssertTrue(hasInk || layout.rootBox.width > 0, "build parity: \(expr)")
        }
    }

    func test_referenceBuild_x() throws {
        let options = FormulaKit.Options.default
        let layout = try FormulaKit.render("x", options: options)
        XCTAssertFalse(layout.textRuns.isEmpty)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
    }
}
