import Foundation

/// FormulaKit is a Swift TeX math typesetting library (layout and rendering in native code).
public struct FormulaKit {
    /// The current version of FormulaKit.
    public static let version = "0.1.0"

    /// TeX mathematical styles.
    public enum MathStyle: Sendable {
        case display
        case displayCramped
        case text
        case textCramped
        case script
        case scriptCramped
        case scriptScript
        case scriptScriptCramped

        public var isCramped: Bool {
            switch self {
            case .displayCramped, .textCramped, .scriptCramped, .scriptScriptCramped: return true
            default: return false
            }
        }

        public func cramped() -> MathStyle {
            switch self {
            case .display: return .displayCramped
            case .text: return .textCramped
            case .script: return .scriptCramped
            case .scriptScript: return .scriptScriptCramped
            default: return self
            }
        }

        public func sup() -> MathStyle {
            switch self {
            case .display, .text: return .script
            case .displayCramped, .textCramped: return .scriptCramped
            case .script, .scriptScript: return .scriptScript
            case .scriptCramped, .scriptScriptCramped: return .scriptScriptCramped
            }
        }

        public func sub() -> MathStyle {
            switch self {
            case .display, .text, .displayCramped, .textCramped: return .scriptCramped
            case .script, .scriptScript, .scriptCramped, .scriptScriptCramped: return .scriptScriptCramped
            }
        }

        public func fracNum() -> MathStyle {
            switch self {
            case .display: return .text
            case .displayCramped: return .textCramped
            case .text: return .script
            case .textCramped: return .scriptCramped
            default: return .scriptScriptCramped
            }
        }

        public func fracDenom() -> MathStyle {
            switch self {
            case .display, .displayCramped: return .textCramped
            case .text, .textCramped: return .scriptCramped
            default: return .scriptScriptCramped
            }
        }

        public var sizeIndex: Int {
            switch self {
            case .display, .displayCramped: return 0
            case .text, .textCramped: return 1
            case .script, .scriptCramped: return 2
            case .scriptScript, .scriptScriptCramped: return 3
            }
        }
    }

    /// Options for controlling the rendering behavior.
    /// `@unchecked Sendable` because ``symbolRenderScratch`` is a class reference used only on one thread per render.
    public struct Options: @unchecked Sendable {
        /// Whether to throw errors or return formatted error messages.
        public var throwOnError: Bool

        /// Color used for error text.
        public var errorColor: String

        /// The current math style.
        public var style: MathStyle

        /// The current font size.
        public var fontSize: CGFloat

        /// When non-nil, ``Renderer`` reuses this for one render to dedupe glyph measurement and symbol boxes.
        /// Leave nil to let ``Renderer`` allocate a fresh ``SymbolRenderScratch`` automatically.
        public var symbolRenderScratch: SymbolRenderScratch?

        /// When true, plain `(`…`)` pairs are parsed like ``\left(…\right)`` so delimiters grow with tall
        /// content (e.g. sums). Standard TeX keeps bare parentheses at fixed size; set to ``false`` for that behavior.
        public var autoStretchDelimiters: Bool

        /// Math font backend (must be registered via ``MathFont/register(_:)``). Defaults to ``MathFontIdentifier/stix``.
        public var mathFont: MathFontIdentifier

        /// Default rendering options.
        public static let `default` = Options(
            throwOnError: false,
            errorColor: "#cc0000",
            style: .display,
            fontSize: 16.0,
            symbolRenderScratch: nil,
            autoStretchDelimiters: true,
            mathFont: .stix
        )

        /// Initialize rendering options.
        public init(
            throwOnError: Bool = false,
            errorColor: String = "#cc0000",
            style: MathStyle = .display,
            fontSize: CGFloat = 16.0,
            symbolRenderScratch: SymbolRenderScratch? = nil,
            autoStretchDelimiters: Bool = true,
            mathFont: MathFontIdentifier = .stix
        ) {
            self.throwOnError = throwOnError
            self.errorColor = errorColor
            self.style = style
            self.fontSize = fontSize
            self.symbolRenderScratch = symbolRenderScratch
            self.autoStretchDelimiters = autoStretchDelimiters
            self.mathFont = mathFont
        }

        public func withStyle(_ newStyle: MathStyle) -> Options {
            var newOptions = self
            newOptions.style = newStyle

            // Adjust font size based on style change
            // sizeIndex 0: display (1.0)
            // sizeIndex 1: text (1.0)
            // sizeIndex 2: script (0.7)
            // sizeIndex 3: scriptscript (0.5)
            let oldSize = self.style.sizeIndex
            let newSize = newStyle.sizeIndex

            let multipliers = [1.0, 1.0, 0.7, 0.5]
            newOptions.fontSize = (self.fontSize / multipliers[oldSize]) * multipliers[newSize]

            return newOptions
        }
    }

    /// Error thrown during parsing or rendering.
    public struct ParseError: Error, CustomStringConvertible {
        /// Error message.
        public let message: String

        /// Create a new parsing error.
        /// - Parameter message: Error message.
        public init(_ message: String) {
            self.message = message
        }

        public var description: String {
            return "TeX parse error: \(message)"
        }
    }

    /// Render a LaTeX math expression: text runs for glyphs plus a vector path for rules, braces, etc.,
    /// and the root ``Box`` for sizing—built in one layout pass.
    /// - Parameters:
    ///   - expression: The LaTeX math expression to render.
    ///   - options: Options for controlling the rendering.
    /// - Returns: Drawable layout (see ``MathCompositeLayout/drawMath(in:textColor:)``).
    /// - Throws: ParseError if the expression couldn't be parsed.
    public static func render(
        _ expression: String,
        options: Options = .default
    ) throws -> MathCompositeLayout {
        if expression.isEmpty {
            return MathCompositeLayout(
                decorationPath: MathPath(),
                textRuns: [],
                rootBox: Box(),
                symbolRenderScratch: nil,
                mathFont: options.mathFont
            )
        }

        let parseTree = try parse(expression, options: options)
        let renderer = Renderer(options: options)
        return renderer.render(node: parseTree)
    }

    /// Parse a LaTeX math expression to a parse tree.
    /// - Parameters:
    ///   - expression: The LaTeX math expression to parse.
    ///   - options: Options for controlling the parsing.
    /// - Returns: The root node of the parse tree.
    /// - Throws: ParseError if the expression couldn't be parsed.
    public static func parse(
        _ expression: String,
        options: Options = .default
    ) throws -> ParseNode {
        if expression.isEmpty {
            return ParseNode(type: .root, value: "", children: [])
        }

        var parser = Parser(input: expression, options: options)
        return try parser.parse()
    }
}
