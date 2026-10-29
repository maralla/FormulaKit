import XCTest

@testable import FormulaKit

final class ReferenceParserSpecTests: XCTestCase {

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

    func test_referenceParser_ord_doesNotFail() throws {
        let expression = "1234|/@.\"`abcdefgzABCDEFGZ"
        XCTAssertNoThrow(try FormulaKit.parse(expression))
    }

    func test_referenceParser_ord_parseProducesNonEmptyTree() throws {
        let expression = "1234|/@.\"`abcdefgzABCDEFGZ"
        let root = try FormulaKit.parse(expression)
        let leaves = Self.symbolAndNumberChildren(of: root)
        XCTAssertFalse(leaves.isEmpty)
    }

    func test_referenceParser_bin_doesNotFail() throws {
        let expression = "+-*\\cdot\\pm\\div"
        XCTAssertNoThrow(try FormulaKit.parse(expression))
    }

    func test_referenceParser_rel_doesNotFail() throws {
        let expression = "=<>\\leq\\geq\\neq\\nleq\\ngeq\\cong"
        let notExpression = "\\not=\\not<\\not>\\not\\leq\\not\\geq\\not\\in"
        XCTAssertNoThrow(try FormulaKit.parse(expression))
        XCTAssertNoThrow(try FormulaKit.parse(notExpression))
    }

    func test_referenceParser_mathinner_doesNotFail() throws {
        XCTAssertNoThrow(try FormulaKit.parse("\\mathinner{\\langle{\\psi}\\rangle}"))
        XCTAssertNoThrow(try FormulaKit.parse("\\frac 1 {\\mathinner{\\langle{\\psi}\\rangle}}"))
    }

    func test_referenceParser_punct_doesNotFail() throws {
        XCTAssertNoThrow(try FormulaKit.parse(",;"))
    }

    func test_referenceParser_open_doesNotFail() throws {
        XCTAssertNoThrow(try FormulaKit.parse("(["))
    }

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
