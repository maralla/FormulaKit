import XCTest

@testable import FormulaKit

/// Parser parity checks aligned with the reference JavaScript math parser test suite (same strings / intent).
/// Where Swift’s `ParseNode` shape differs from the JS tree, we only assert parse success or structural checks
/// called out in those tests.
final class ReferenceParserSpecTests: XCTestCase {

    // MARK: - describe("A parser") — lines 22–33

    func test_referenceParser_emptyStringDoesNotFail() throws {
        let root = try FormulaKit.parse("")
        XCTAssertEqual(root.type, .root)
        XCTAssertTrue(root.children.isEmpty)
    }

    func test_referenceParser_ignoresWhitespace() throws {
        let a = try FormulaKit.parse("    x    y    ")
        let b = try FormulaKit.parse("xy")
        XCTAssertEqual(Self.flattenSymbolLikeText(a), Self.flattenSymbolLikeText(b))
    }

    func test_referenceParser_ignoresWhitespaceInAtom() throws {
        let a = try FormulaKit.parse("    x   ^ y    ")
        let b = try FormulaKit.parse("x^y")
        XCTAssertEqual(Self.flattenSymbolLikeText(a), Self.flattenSymbolLikeText(b))
    }

    // MARK: - describe("An ord parser") — lines 36–56

    func test_referenceParser_ord_doesNotFail() throws {
        let expression = "1234|/@.\"`abcdefgzABCDEFGZ"
        XCTAssertNoThrow(try FormulaKit.parse(expression))
    }

    /// JS: `expect(parse).toHaveLength(expression.length)` — one parse node per character in the reference tree.
    /// Swift’s parser groups letter runs; finer parity is tracked separately.
    func test_referenceParser_ord_parseProducesNonEmptyTree() throws {
        let expression = "1234|/@.\"`abcdefgzABCDEFGZ"
        let root = try FormulaKit.parse(expression)
        let leaves = Self.symbolAndNumberChildren(of: root)
        XCTAssertFalse(leaves.isEmpty)
    }

    // MARK: - describe("A bin parser") — lines 59–74

    func test_referenceParser_bin_doesNotFail() throws {
        let expression = "+-*\\cdot\\pm\\div"
        XCTAssertNoThrow(try FormulaKit.parse(expression))
    }

    // MARK: - describe("A rel parser") — lines 77–103

    func test_referenceParser_rel_doesNotFail() throws {
        let expression = "=<>\\leq\\geq\\neq\\nleq\\ngeq\\cong"
        let notExpression = "\\not=\\not<\\not>\\not\\leq\\not\\geq\\not\\in"
        XCTAssertNoThrow(try FormulaKit.parse(expression))
        XCTAssertNoThrow(try FormulaKit.parse(notExpression))
    }

    // MARK: - describe("A mathinner parser") — lines 105–115

    func test_referenceParser_mathinner_doesNotFail() throws {
        XCTAssertNoThrow(try FormulaKit.parse("\\mathinner{\\langle{\\psi}\\rangle}"))
        XCTAssertNoThrow(try FormulaKit.parse("\\frac 1 {\\mathinner{\\langle{\\psi}\\rangle}}"))
    }

    // MARK: - describe("A punct parser") — lines 118–133

    func test_referenceParser_punct_doesNotFail() throws {
        XCTAssertNoThrow(try FormulaKit.parse(",;"))
    }

    // MARK: - describe("An open parser") — lines 136–150

    func test_referenceParser_open_doesNotFail() throws {
        XCTAssertNoThrow(try FormulaKit.parse("(["))
    }

    // MARK: - Helpers (Swift parse tree — not part of reference JS)

    private static func flattenSymbolLikeText(_ node: ParseNode) -> String {
        symbolAndNumberChildren(of: node).map(\.value).joined()
    }

    private static func symbolAndNumberChildren(of node: ParseNode) -> [ParseNode] {
        var out: [ParseNode] = []
        func walk(_ n: ParseNode) {
            switch n.type {
            case .symbol, .number, .operator:
                out.append(n)
            default:
                for c in n.children { walk(c) }
            }
        }
        walk(node)
        return out
    }
}
