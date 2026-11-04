import XCTest

@testable import FormulaKit

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

    func testExternalMathRenderBackend() throws {
        struct RecordingMathRenderer: MathRenderBackend {
            var rootWidth: CGFloat = 0
            var pathCount = 0
            var runs: [MathTextRun] = []

            mutating func beginMath(rootBox: Box, mathFont: MathFontIdentifier) {
                rootWidth = rootBox.width
            }
            mutating func fillMathPath(_ path: MathPath) {
                pathCount += 1
            }
            mutating func drawMathTextRun(_ run: MathTextRun, mathFont: MathFontIdentifier) {
                runs.append(run)
            }
        }

        var backend = RecordingMathRenderer()
        try FormulaKit.render(#"\frac{x^2 + 1}{\sqrt{y}}"#, into: &backend)
        XCTAssertGreaterThan(backend.rootWidth, 0)
        XCTAssertEqual(backend.pathCount, 1)
        XCTAssertFalse(backend.runs.isEmpty)
    }
}
