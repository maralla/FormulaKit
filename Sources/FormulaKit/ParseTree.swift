import Foundation

// MARK: - ParseNode
/// The base node in the math parse tree.
public struct ParseNode {
    /// Type of node in the parse tree.
    public enum NodeType: String {
        case root
        case number
        case `operator`
        case symbol
        case function
        case group
        case array
        case text
        case accent
        case tag
        case style
        case horizBrace
    }

    /// The type of this node.
    public let type: NodeType

    /// The value associated with this node.
    public let value: String

    /// Child nodes, if any.
    public var children: [ParseNode] = []

    /// Create a new parse node.
    /// - Parameters:
    ///   - type: The type of node.
    ///   - value: The value associated with this node.
    ///   - children: Child nodes, if any.
    public init(type: NodeType, value: String, children: [ParseNode] = []) {
        self.type = type
        self.value = value
        self.children = children
    }
}

// MARK: - MathSymbols
/// Mathematical symbols and their Unicode representations.
public struct MathSymbols {
    /// Maps TeX command names to their Unicode symbols.
    public static let commands: [String: String] = [
        // Greek letters
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε",
        "zeta": "ζ", "eta": "η", "theta": "θ", "iota": "ι", "kappa": "κ",
        "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ", "omicron": "ο",
        "pi": "π", "rho": "ρ", "sigma": "σ", "tau": "τ", "upsilon": "υ",
        "phi": "φ", "chi": "χ", "psi": "ψ", "omega": "ω",
        "varepsilon": "\u{03F5}", "vartheta": "ϑ", "varpi": "ϖ", "varrho": "ϱ",
        "varsigma": "ς", "varphi": "\u{03D5}", "varkappa": "ϰ", "digamma": "ϝ",

        // Capital Greek letters
        "Alpha": "Α", "Beta": "Β", "Gamma": "Γ", "Delta": "Δ", "Epsilon": "Ε",
        "Zeta": "Ζ", "Eta": "Η", "Theta": "Θ", "Iota": "Ι", "Kappa": "Κ",
        "Lambda": "Λ", "Mu": "Μ", "Nu": "Ν", "Xi": "Ξ", "Omicron": "Ο",
        "Pi": "Π", "Rho": "Ρ", "Sigma": "Σ", "Tau": "Τ", "Upsilon": "Υ",
        "Phi": "Φ", "Chi": "Χ", "Psi": "Ψ", "Omega": "Ω",

        // Binary operators
        "pm": "±", "mp": "∓", "times": "×", "div": "÷", "cdot": "\u{22C5}", "centerdot": "\u{22C5}",
        "odot": "\u{2299}", "ast": "∗", "star": "⋆", "circ": "∘", "bullet": "•",
        "wedge": "∧", "vee": "∨", "land": "∧", "lor": "∨", "cap": "∩", "cup": "∪",
        "uplus": "⊎", "sqcap": "⊓", "sqcup": "⊔", "ominus": "⊖", "bigcirc": "◯",
        "wr": "≀", "amalg": "⨿", "And": "&", "oplus": "⊕", "otimes": "⊗", "oslash": "⊘",
        "setminus": "∖", "smallsetminus": "∖",
        "boxplus": "⊞", "boxminus": "⊟", "boxtimes": "⊠", "boxdot": "⊡",
        "triangleleft": "◁", "triangleright": "▷", "ltimes": "⋉", "rtimes": "⋊",
        "divideontimes": "⋇", "intercal": "⊺", "veebar": "⊻", "barwedge": "⊼",
        "dagger": "†", "ddagger": "‡", "Cap": "⋒", "Cup": "⋓",

        // Relation operators
        "approx": "≈", "napprox": "≉", "equiv": "≡", "nequiv": "≢", "propto": "∝", "varpropto": "∝",
        "ne": "≠", "neq": "≠", "le": "≤", "leq": "≤", "ge": "≥", "geq": "≥",
        "leqslant": "⩽", "geqslant": "⩾", "nleq": "≰", "ngeq": "≱", "nless": "≮", "ngtr": "≯",
        "sim": "∼", "nsim": "≁", "cong": "≅", "ncong": "≇", "simeq": "≃", "asymp": "≍",
        "prec": "≺", "succ": "≻", "preceq": "⪯", "succeq": "⪰",
        "ll": "≪", "gg": "≫", "lll": "⋘", "ggg": "⋙", "lesssim": "≲", "gtrsim": "≳",
        "mid": "∣", "nmid": "∤", "parallel": "∥", "nparallel": "∦", "perp": "⊥", "bowtie": "⋈", "Join": "⋈",
        "smile": "⌣", "frown": "⌢", "ni": "∋", "owns": "∋",
        "vdash": "⊢", "dashv": "⊣", "Vdash": "⊩", "nvdash": "⊬", "nvDash": "⊭",
        "doteq": "≐", "triangleq": "≜", "circeq": "≗",
        "sqsubset": "⊏", "sqsupset": "⊐", "sqsubseteq": "⊑", "sqsupseteq": "⊒",
        "subseteq": "⊆", "supseteq": "⊇", "subseteqq": "⫅", "supseteqq": "⫆",
        "nsubseteq": "⊈", "nsupseteq": "⊉", "subsetneq": "⊊", "supsetneq": "⊋",
        "models": "⊨", "therefore": "∴", "because": "∵",
        "implies": "⟹", "impliedby": "⟸", "iff": "⟺",
        "colon": "\u{2236}",
        "ldots": "\u{2026}", "dots": "\u{2026}", "cdots": "\u{22EF}", "vdots": "\u{22EE}", "ddots": "\u{22F1}",

        // Arrows
        "leftarrow": "←", "Leftarrow": "⇐", "rightarrow": "→", "Rightarrow": "⇒",
        "to": "→", "gets": "←",
        "leftrightarrow": "↔", "Leftrightarrow": "⇔", "uparrow": "↑", "Uparrow": "⇑",
        "downarrow": "↓", "Downarrow": "⇓", "updownarrow": "↕", "Updownarrow": "⇕",
        "longleftarrow": "⟵", "Longleftarrow": "⟸", "longrightarrow": "⟶", "Longrightarrow": "⟹",
        "longleftrightarrow": "⟷", "Longleftrightarrow": "⟺",
        "mapsto": "↦", "longmapsto": "⟼",
        "nearrow": "↗", "searrow": "↘", "swarrow": "↙", "nwarrow": "↖",
        "hookleftarrow": "↩", "hookrightarrow": "↪",
        "leftharpoonup": "↼", "rightharpoonup": "⇀", "leftharpoondown": "↽", "rightharpoondown": "⇁",
        "upharpoonleft": "↿", "upharpoonright": "↾", "downharpoonleft": "⇃", "downharpoonright": "⇂",
        "rightleftharpoons": "⇌", "leftrightharpoons": "⇋",
        "leadsto": "⇝", "rightsquigarrow": "⇝", "leftrightsquigarrow": "↭",
        "twoheadleftarrow": "↞", "twoheadrightarrow": "↠",
        "leftarrowtail": "↢", "rightarrowtail": "↣",
        "curvearrowleft": "↶", "curvearrowright": "↷",
        "circlearrowleft": "↺", "circlearrowright": "↻",
        "upuparrows": "⇈", "downdownarrows": "⇊", "leftleftarrows": "⇇", "rightrightarrows": "⇉",
        "leftrightarrows": "⇆", "rightleftarrows": "⇄", "multimap": "⊸",

        // Miscellaneous symbols
        "infty": "∞", "nabla": "∇", "partial": "∂", "forall": "∀", "exists": "∃",
        "nexists": "∄", "emptyset": "∅", "varnothing": "∅", "complement": "∁",
        "neg": "¬", "lnot": "¬", "top": "⊤", "bot": "⊥",
        "in": "∈", "notin": "∉", "subset": "⊂", "supset": "⊃",
        "aleph": "ℵ", "beth": "ℶ", "gimel": "ℷ", "daleth": "ℸ",
        "hbar": "ℏ", "hslash": "ℏ", "ell": "ℓ", "wp": "℘", "Re": "ℜ", "Im": "ℑ", "mho": "℧",
        "prime": "′", "backprime": "‵", "surd": "√",
        "angle": "∠", "measuredangle": "∡", "sphericalangle": "∢",
        "triangle": "△", "vartriangle": "△", "triangledown": "▽",
        "blacktriangle": "▲", "blacktriangledown": "▼",
        "square": "□", "Box": "□", "blacksquare": "■", "lozenge": "◊", "Diamond": "◊",
        "bigstar": "★", "clubsuit": "♣", "diamondsuit": "♢", "heartsuit": "♡", "spadesuit": "♠",
        "flat": "♭", "natural": "♮", "sharp": "♯", "checkmark": "✓", "degree": "°",

        // Dotless letters
        "i": "ı", "j": "ȷ", "imath": "ı", "jmath": "ȷ",

        // Operators with limits
        "sum": "∑", "prod": "∏", "coprod": "∐",
        "int": "∫", "oint": "∮", "iint": "∬", "iiint": "∭", "oiint": "∯", "oiiint": "∰",
        "bigcap": "⋂", "bigcup": "⋃", "bigsqcup": "⨆", "bigvee": "⋁", "bigwedge": "⋀",
        "bigodot": "⨀", "bigoplus": "⨁", "bigotimes": "⨂", "biguplus": "⨄",

        // Common functions
        "sin": "sin", "cos": "cos", "tan": "tan", "cot": "cot", "sec": "sec", "csc": "csc",
        "sinh": "sinh", "cosh": "cosh", "tanh": "tanh", "coth": "coth", "sech": "sech", "csch": "csch",
        "arcsin": "arcsin", "arccos": "arccos", "arctan": "arctan", "arccot": "arccot",
        "arcsec": "arcsec", "arccsc": "arccsc", "arsinh": "arsinh", "arcosh": "arcosh", "artanh": "artanh",
        "ln": "ln", "log": "log", "lg": "lg", "exp": "exp",
        "lim": "lim", "limsup": "limsup", "liminf": "liminf",
        "sup": "sup", "inf": "inf", "max": "max", "min": "min", "argmin": "argmin", "argmax": "argmax",
        "det": "det", "dim": "dim", "ker": "ker", "hom": "hom", "im": "im", "deg": "deg",
        "arg": "arg", "gcd": "gcd", "lcm": "lcm", "Pr": "Pr",
        "sgn": "sgn", "tr": "tr", "trace": "trace", "rank": "rank", "diag": "diag", "erf": "erf",

        // Delimiters
        "lbrace": "{", "rbrace": "}", "vert": "|", "Vert": "‖", "langle": "⟨", "rangle": "⟩",
        "lfloor": "⌊", "rfloor": "⌋", "lceil": "⌈", "rceil": "⌉",
        "lbrack": "[", "rbrack": "]", "lgroup": "⟮", "rgroup": "⟯",
        "lmoustache": "⎰", "rmoustache": "⎱", "llbracket": "⟦", "rrbracket": "⟧",
    ]

    public static let negatedRelations: [String: String] = [
        "=": "≠", "<": "≮", ">": "≯", "≤": "≰", "≥": "≱", "⩽": "≰", "⩾": "≱",
        "∈": "∉", "∋": "∌", "≡": "≢", "∼": "≁", "≈": "≉", "≅": "≇", "≃": "≄",
        "⊂": "⊄", "⊃": "⊅", "⊆": "⊈", "⊇": "⊉", "⊑": "⋢", "⊒": "⋣",
        "∣": "∤", "∥": "∦", "⊢": "⊬", "⊨": "⊭", "∃": "∄", "≺": "⊀", "≻": "⊁",
    ]

    /// Maps special LaTeX symbols to their Unicode equivalents.
    public static let specialSymbols: [String: String] = [
        "\\": "\\", "{": "{", "}": "}", "_": "_", "^": "^", "#": "#", "&": "&", "$": "$", "%": "%",
    ]

    /// Get the Unicode representation of a TeX command.
    public static func getSymbolForCommand(_ command: String) -> String? {
        return commands[command]
    }

    /// Get the Unicode representation of a special LaTeX symbol.
    public static func getSpecialSymbol(_ symbol: String) -> String? {
        return specialSymbols[symbol]
    }
}

// MARK: - Parser
/// The Parser transforms TeX strings into a parse tree of expressions.
public struct Parser {
    private let input: String
    private var position: String.Index
    private let options: FormulaKit.Options

    public init(input: String, options: FormulaKit.Options) {
        self.input = input
        self.position = input.startIndex
        self.options = options
    }

    public mutating func parse() throws -> ParseNode {
        let nodes = try parseExpression()
        return ParseNode(type: .root, value: "", children: nodes)
    }

    private mutating func parseExpression(
        until delimiters: String = "",
        stopOnRowEnd: Bool = false,
        stopOnRight: Bool = false,
        stopOnMiddle: Bool = false
    ) throws -> [ParseNode] {
        var nodes: [ParseNode] = []
        while !isAtEnd {
            skipWhitespace()
            if isAtEnd { break }

            if !delimiters.isEmpty && delimiters.contains(input[position]) {
                break
            }

            if isEndCommand { break }
            if stopOnRowEnd && isRowDelimiter { break }
            if stopOnMiddle && isMiddleCommand { break }
            if stopOnRight && isRightCommand { break }

            var node = try parseAtom()

            if node.type == .function && (node.value == "over" || node.value == "choose" || node.value == "atop") {
                let op = node.value
                let numerator = ParseNode(type: .group, value: "", children: nodes)
                let denominator = try parseExpression(
                    until: delimiters,
                    stopOnRowEnd: stopOnRowEnd,
                    stopOnRight: stopOnRight,
                    stopOnMiddle: stopOnMiddle
                )
                return [
                    makeInfixFractionNode(
                        op: op,
                        numerator: numerator,
                        denominator: ParseNode(type: .group, value: "", children: denominator)
                    )
                ]
            }

            node = try parseAttachedScriptsAndPrimes(base: node)
            nodes.append(node)
        }
        return nodes
    }

    private func makeInfixFractionNode(op: String, numerator: ParseNode, denominator: ParseNode) -> ParseNode {
        if op == "choose" {
            let frac = ParseNode(type: .function, value: "atop", children: [numerator, denominator])
            return ParseNode(
                type: .function,
                value: "leftright",
                children: [ParseNode(type: .symbol, value: "("), frac, ParseNode(type: .symbol, value: ")")]
            )
        }
        let fnName = (op == "atop") ? "atop" : "frac"
        return ParseNode(type: .function, value: fnName, children: [numerator, denominator])
    }

    private mutating func parseAttachedScriptsAndPrimes(base: ParseNode) throws -> ParseNode {
        var node = base
        var limitsMode: String?
        while true {
            skipWhitespace()
            if checkCommand("limits") {
                try consumeCommand(named: "limits")
                limitsMode = "limits"
            } else if checkCommand("nolimits") {
                try consumeCommand(named: "nolimits")
                limitsMode = "nolimits"
            } else {
                break
            }
        }
        var scripts: [ParseNode] = []
        var primeCount = 0
        while !isAtEnd && input[position] == "'" {
            advance()
            primeCount += 1
        }
        var primeNodes: [ParseNode] = []
        while primeCount > 0 {
            if primeCount >= 3 {
                primeNodes.append(ParseNode(type: .symbol, value: "‴"))
                primeCount -= 3
            } else if primeCount == 2 {
                primeNodes.append(ParseNode(type: .symbol, value: "″"))
                primeCount -= 2
            } else {
                primeNodes.append(ParseNode(type: .symbol, value: "′"))
                primeCount -= 1
            }
        }
        while !isAtEnd && (input[position] == "^" || input[position] == "_") {
            let sc = try parseScript()
            if sc.value == "sup" && !primeNodes.isEmpty {
                let combined = primeNodes + sc.children
                primeNodes.removeAll()
                scripts.append(
                    ParseNode(type: .function, value: "sup", children: [ParseNode(type: .group, value: "", children: combined)])
                )
            } else {
                scripts.append(sc)
            }
        }
        if !primeNodes.isEmpty {
            scripts.insert(
                ParseNode(type: .function, value: "sup", children: [ParseNode(type: .group, value: "", children: primeNodes)]),
                at: 0
            )
        }
        if !scripts.isEmpty {
            let fnVal = limitsMode.map { "supsub:\($0)" } ?? "supsub"
            node = ParseNode(type: .function, value: fnVal, children: [node] + scripts)
        }
        return node
    }

    /// True if there is a `)` later that balances this `(`, using a raw character scan (same as nesting for plain TeX).
    private func hasMatchingClosingParenFromCurrentOpen() -> Bool {
        guard !isAtEnd, input[position] == "(" else { return false }
        var idx = input.index(after: position)
        var depth = 1
        while idx < input.endIndex {
            let c = input[idx]
            if c == "(" {
                depth += 1
            } else if c == ")" {
                depth -= 1
                if depth == 0 { return true }
            }
            idx = input.index(after: idx)
        }
        return false
    }

    /// True if there is a `]` later that balances this `[` (raw scan).
    private func hasMatchingClosingBracketFromCurrentOpen() -> Bool {
        guard !isAtEnd, input[position] == "[" else { return false }
        var idx = input.index(after: position)
        var depth = 1
        while idx < input.endIndex {
            let c = input[idx]
            if c == "[" {
                depth += 1
            } else if c == "]" {
                depth -= 1
                if depth == 0 { return true }
            }
            idx = input.index(after: idx)
        }
        return false
    }

    /// Math list until a matching ``closing`` delimiter (the closer is consumed).
    /// Used to treat plain `(`…`)` like ``\left(…\right)`` when ``Options/autoStretchDelimiters`` is true.
    private mutating func parseDelimitedBalanced(closing: Character) throws -> [ParseNode] {
        var nodes: [ParseNode] = []
        while true {
            skipWhitespace()
            if isAtEnd {
                throw FormulaKit.ParseError("Expected '\(closing)'")
            }
            if input[position] == closing {
                advance()
                return nodes
            }

            var node = try parseAtom()

            if node.type == .function && (node.value == "over" || node.value == "choose" || node.value == "atop") {
                let op = node.value
                let numerator = ParseNode(type: .group, value: "", children: nodes)
                let denominator = try parseDelimitedBalanced(closing: closing)
                return [
                    makeInfixFractionNode(
                        op: op,
                        numerator: numerator,
                        denominator: ParseNode(type: .group, value: "", children: denominator)
                    )
                ]
            }

            node = try parseAttachedScriptsAndPrimes(base: node)
            nodes.append(node)
        }
    }

    private var isRowDelimiter: Bool {
        if isAtEnd { return false }
        if input[position] == "&" { return true }
        if input[position] == "\\" {
            let nextPos = input.index(after: position)
            if nextPos < input.endIndex && input[nextPos] == "\\" { return true }
        }
        return false
    }

    private var isEndCommand: Bool {
        return checkCommand("end")
    }

    private var isRightCommand: Bool {
        return checkCommand("right")
    }

    private var isMiddleCommand: Bool {
        return checkCommand("middle")
    }

    private var isHlineCommand: Bool {
        return checkCommand("hline")
    }

    private func checkCommand(_ name: String) -> Bool {
        if isAtEnd { return false }
        if input[position] == "\\" {
            let nextPos = input.index(after: position)
            if nextPos < input.endIndex {
                let start = nextPos
                var end = nextPos
                while end < input.endIndex && isLetter(input[end]) {
                    end = input.index(after: end)
                }
                return String(input[start..<end]) == name
            }
        }
        return false
    }

    private mutating func parseAtom() throws -> ParseNode {
        skipWhitespace()
        if isAtEnd { throw FormulaKit.ParseError("Unexpected end of input") }
        let currentChar = input[position]
        switch currentChar {
        case "{": return try parseGroup()
        case "\\": return try parseCommand()
        case "&": advance(); return ParseNode(type: .symbol, value: "&")
        case "0"..."9", ".": return try parseNumber()
        case "+", "-", "=", "<", ">", "×", "÷", "±", "∓": return try parseOperator()
        case "^", "_": return try parseScript()
        case "(":
            if options.autoStretchDelimiters, hasMatchingClosingParenFromCurrentOpen() {
                advance()
                let inner = try parseDelimitedBalanced(closing: ")")
                return ParseNode(
                    type: .function,
                    value: "leftright",
                    children: [
                        ParseNode(type: .symbol, value: "("),
                        ParseNode(type: .group, value: "", children: inner),
                        ParseNode(type: .symbol, value: ")"),
                    ]
                )
            }
            advance()
            return ParseNode(type: .symbol, value: "(")
        case ")":
            advance()
            return ParseNode(type: .symbol, value: ")")
        case "[":
            if options.autoStretchDelimiters, hasMatchingClosingBracketFromCurrentOpen() {
                advance()
                let inner = try parseDelimitedBalanced(closing: "]")
                return ParseNode(
                    type: .function,
                    value: "leftright",
                    children: [
                        ParseNode(type: .symbol, value: "["),
                        ParseNode(type: .group, value: "", children: inner),
                        ParseNode(type: .symbol, value: "]"),
                    ]
                )
            }
            advance()
            return ParseNode(type: .symbol, value: "[")
        case "]":
            advance()
            return ParseNode(type: .symbol, value: "]")
        case "|":
            let s = String(currentChar); advance(); return ParseNode(type: .symbol, value: s)
        default:
            if isLetter(currentChar) {
                return try parseSymbol()
            }
            let s = String(currentChar); advance(); return ParseNode(type: .symbol, value: s)
        }
    }

    private mutating func parseGroup() throws -> ParseNode {
        advance()
        let contents = try parseExpression(until: "}")
        if isAtEnd || input[position] != "}" { throw FormulaKit.ParseError("Expected '}'") }
        advance()
        return ParseNode(type: .group, value: "", children: contents)
    }

    private mutating func parseCommand() throws -> ParseNode {
        advance()  // Skip \
        if isAtEnd { throw FormulaKit.ParseError("Expected command name") }

        let accents = [
            "acute", "grave", "ddot", "tilde", "bar", "breve", "check", "hat", "vec", "dot",
            "widehat", "widetilde", "widecheck", "overrightarrow", "overleftarrow", "overleftrightarrow",
        ]
        let textAccents = ["'", "`", "^", "~", "=", "u", ".", "\"", "c", "r", "H", "v"]

        if !isLetter(input[position]) {
            let cmd = String(input[position])
            if textAccents.contains(cmd) {
                advance()
                return try parseAccent(label: "\\" + cmd)
            }
        }

        let start = position
        while !isAtEnd && (isLetter(input[position]) || input[position] == "*") { advance() }

        if start == position {
            if !isAtEnd {
                switch input[position] {
                case ",":
                    advance()
                    return ParseNode(type: .function, value: "thinspace", children: [])
                case "!":
                    advance()
                    return ParseNode(type: .function, value: "negthinspace", children: [])
                case ":":
                    advance()
                    return ParseNode(type: .function, value: "medspace", children: [])
                case ";":
                    advance()
                    return ParseNode(type: .function, value: "thickspace", children: [])
                case ">":
                    advance()
                    return ParseNode(type: .function, value: "medspace", children: [])
                default:
                    break
                }
                let char = String(input[position]); advance()
                if let special = MathSymbols.getSpecialSymbol(char) { return ParseNode(type: .symbol, value: special) }
                return ParseNode(type: .symbol, value: char)
            } else {
                throw FormulaKit.ParseError("Expected character after '\\'")
            }
        }

        let name = String(input[start..<position])
        if let symbol = MathSymbols.getSymbolForCommand(name) { return ParseNode(type: .symbol, value: symbol) }

        switch name {
        case "frac", "dfrac", "tfrac", "cfrac": return try parseFraction(name: name)
        case "binom": return try parseBinom()
        case "tbinom":
            return ParseNode(type: .style, value: "textstyle", children: [try parseBinom()])
        case "dbinom":
            return ParseNode(type: .style, value: "displaystyle", children: [try parseBinom()])
        case "sqrt": return try parseSqrt()
        case "begin": return try parseEnvironment()
        case "left": return try parseLeftRight()
        case "text": return try parseText()
        case "textbf":
            return ParseNode(type: .style, value: "mathbf", children: [try parseText()])
        case "textit":
            return ParseNode(type: .style, value: "mathit", children: [try parseText()])
        case "textrm":
            return try parseText()
        case "textsf":
            return ParseNode(type: .style, value: "mathsf", children: [try parseText()])
        case "texttt":
            return ParseNode(type: .style, value: "mathtt", children: [try parseText()])
        case "tag": return try parseTag()
        case "mathbb", "Bbb": return try parseStyle(name: "mathbb")
        case "mathbf", "bf": return try parseStyle(name: "mathbf")
        case "mathit", "it": return try parseStyle(name: "mathit")
        case "mathrm", "rm": return try parseStyle(name: "mathrm")
        case "mathsf", "sf": return try parseStyle(name: "mathsf")
        case "mathtt", "tt": return try parseStyle(name: "mathtt")
        case "mathcal", "cal", "mathscr": return try parseStyle(name: "mathcal")
        case "mathfrak", "frak": return try parseStyle(name: "mathfrak")
        case "boldsymbol", "bm": return try parseStyle(name: "boldsymbol")
        case "displaystyle", "textstyle", "scriptstyle", "scriptscriptstyle":
            return try parseMathStyleSwitch(name: name)
        case "mathchoice":
            return ParseNode(
                type: .function,
                value: "mathchoice",
                children: [try parseArgument(), try parseArgument(), try parseArgument(), try parseArgument()]
            )
        case "overset", "underset", "stackrel":
            return try parseOversetUnderset(name: name == "stackrel" ? "overset" : name)
        case "xrightarrow": return try parseExtensibleArrow(arrow: "→")
        case "xleftarrow": return try parseExtensibleArrow(arrow: "←")
        case "xRightarrow": return try parseExtensibleArrow(arrow: "⇒")
        case "xLeftarrow": return try parseExtensibleArrow(arrow: "⇐")
        case "xleftrightarrow": return try parseExtensibleArrow(arrow: "↔")
        case "xLeftrightarrow": return try parseExtensibleArrow(arrow: "⇔")
        case "xhookrightarrow": return try parseExtensibleArrow(arrow: "↪")
        case "xhookleftarrow": return try parseExtensibleArrow(arrow: "↩")
        case "xmapsto": return try parseExtensibleArrow(arrow: "↦")
        case "xlongequal": return try parseExtensibleArrow(arrow: "=")
        case "overline", "underline", "boxed", "cancel", "bcancel", "xcancel":
            return ParseNode(type: .function, value: name, children: [try parseArgumentOrAtom()])
        case "substack":
            return try parseSubstack()
        case "pmod":
            let modArg = try parseArgumentOrAtom()
            return ParseNode(type: .function, value: "pmod", children: [modArg])
        case "bmod", "mod":
            return ParseNode(type: .function, value: "bmod", children: [])
        case "not":
            return try parseNotRelation()
        case "operatorname": return try parseOperatorName()
        case "kern", "mkern": return try parseKernLike(prefix: "kern")
        case "hskip": return try parseKernLike(prefix: "hskip")
        case "mskip": return try parseKernLike(prefix: "mskip")
        case "hspace": return try parseHspace()
        case "big", "Big", "bigg", "Bigg": return try parseBigDelimiter(size: name)
        case "bigl": return try parseBigDelimiter(size: "big", role: "open")
        case "Bigl": return try parseBigDelimiter(size: "Big", role: "open")
        case "biggl": return try parseBigDelimiter(size: "bigg", role: "open")
        case "Biggl": return try parseBigDelimiter(size: "Bigg", role: "open")
        case "bigr": return try parseBigDelimiter(size: "big", role: "close")
        case "Bigr": return try parseBigDelimiter(size: "Big", role: "close")
        case "biggr": return try parseBigDelimiter(size: "bigg", role: "close")
        case "Biggr": return try parseBigDelimiter(size: "Bigg", role: "close")
        case "bigm": return try parseBigDelimiter(size: "big", role: "rel")
        case "Bigm": return try parseBigDelimiter(size: "Big", role: "rel")
        case "biggm": return try parseBigDelimiter(size: "bigg", role: "rel")
        case "Biggm": return try parseBigDelimiter(size: "Bigg", role: "rel")
        case "phantom": return ParseNode(type: .function, value: "phantom", children: [try parseArgument()])
        case "hphantom": return ParseNode(type: .function, value: "hphantom", children: [try parseArgument()])
        case "vphantom": return ParseNode(type: .function, value: "vphantom", children: [try parseArgument()])
        case "smash": return ParseNode(type: .function, value: "smash", children: [try parseArgument()])
        case "overbrace", "underbrace": return try parseHorizBrace(name: name)
        case "nonumber", "notag": return ParseNode(type: .function, value: "nonumber")
        case "over", "choose", "atop": return ParseNode(type: .function, value: name)
        default: break
        }

        if accents.contains(name) { return try parseAccent(label: "\\" + name) }
        if name.count == 1 && textAccents.contains(name) {
            return try parseAccent(label: "\\" + name)
        }

        return ParseNode(type: .function, value: name)
    }

    private mutating func parseHorizBrace(name: String) throws -> ParseNode {
        let base = try parseArgumentOrAtom()
        return ParseNode(type: .horizBrace, value: name, children: [base])
    }

    private mutating func parseStyle(name: String) throws -> ParseNode {
        ParseNode(type: .style, value: name, children: [try parseArgumentOrAtom()])
    }

    private mutating func parseMathStyleSwitch(name: String) throws -> ParseNode {
        ParseNode(type: .style, value: name, children: [try parseArgumentOrAtom()])
    }

    private mutating func parseOversetUnderset(name: String) throws -> ParseNode {
        let over = try parseArgument()
        let base = try parseArgument()
        return ParseNode(type: .function, value: name, children: [over, base])
    }

    private mutating func parseExtensibleArrow(arrow: String) throws -> ParseNode {
        skipWhitespace()
        var below: ParseNode?
        if !isAtEnd && input[position] == "[" {
            below = ParseNode(type: .group, value: "", children: try parseBracketGroup())
        }
        let above = try parseArgument()
        let base = ParseNode(type: .symbol, value: arrow)
        if let below {
            let under = ParseNode(type: .function, value: "underset", children: [below, base])
            return ParseNode(type: .function, value: "overset", children: [above, under])
        }
        return ParseNode(type: .function, value: "overset", children: [above, base])
    }

    private mutating func parseSubstack() throws -> ParseNode {
        skipWhitespace()
        guard !isAtEnd && input[position] == "{" else {
            return ParseNode(type: .style, value: "scriptstyle", children: [try parseAtom()])
        }
        advance()
        var rows: [ParseNode] = []
        while !isAtEnd && input[position] != "}" {
            let cell = ParseNode(type: .group, value: "cell", children: try parseExpression(until: "}", stopOnRowEnd: true))
            rows.append(ParseNode(type: .group, value: "row", children: [cell]))
            skipWhitespace()
            if !isAtEnd && input[position] == "\\" {
                let next = input.index(after: position)
                if next < input.endIndex && input[next] == "\\" {
                    advance(); advance()
                }
            }
        }
        if !isAtEnd && input[position] == "}" { advance() }
        return ParseNode(type: .array, value: "substack", children: rows)
    }

    private mutating func parseNotRelation() throws -> ParseNode {
        skipWhitespace()
        if isAtEnd { return ParseNode(type: .symbol, value: "¬") }
        let target = try parseAtom()
        if let neg = MathSymbols.negatedRelations[target.value] {
            return ParseNode(type: .symbol, value: neg)
        }
        return ParseNode(type: .function, value: "cancel", children: [target])
    }

    private mutating func parseOperatorName() throws -> ParseNode {
        skipWhitespace()
        var starred = false
        if !isAtEnd && input[position] == "*" {
            starred = true
            advance()
        }
        let arg = try parseArgument()
        return ParseNode(type: .function, value: starred ? "operatorname*" : "operatorname", children: [arg])
    }

    /// Raw dimension like `0.5em`, `-3mu` (no surrounding braces).
    private mutating func parseDimensionAsRaw() throws -> String {
        skipWhitespace()
        var raw = ""
        if !isAtEnd && input[position] == "-" {
            raw.append("-")
            advance()
        } else if !isAtEnd && input[position] == "+" {
            advance()
        }
        let numStart = position
        while !isAtEnd && (isDigit(input[position]) || input[position] == ".") {
            advance()
        }
        if position == numStart { throw FormulaKit.ParseError("Expected dimension number") }
        raw.append(String(input[numStart..<position]))
        skipWhitespace()
        let unitStart = position
        while !isAtEnd && isLetter(input[position]) {
            advance()
        }
        if position > unitStart {
            raw.append(String(input[unitStart..<position]))
        }
        return raw
    }

    private mutating func parseKernLike(prefix: String) throws -> ParseNode {
        let dim = try parseDimensionAsRaw()
        return ParseNode(type: .function, value: "\(prefix):\(dim)", children: [])
    }

    private mutating func parseHspace() throws -> ParseNode {
        let inner = try parseRawBracedGroup()
        return ParseNode(type: .function, value: "hspace:\(inner)", children: [])
    }

    /// Contents between `{` and matching `}` without interpreting as math (for `\hspace{1em}`).
    private mutating func parseRawBracedGroup() throws -> String {
        skipWhitespace()
        guard !isAtEnd && input[position] == "{" else { throw FormulaKit.ParseError("Expected '{'") }
        advance()
        let start = position
        var depth = 1
        while !isAtEnd && depth > 0 {
            let ch = input[position]
            if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    let inner = String(input[start..<position])
                    advance()
                    return inner
                }
            }
            advance()
        }
        throw FormulaKit.ParseError("Unterminated '{' in dimension")
    }

    private mutating func parseBigDelimiter(size: String, role: String? = nil) throws -> ParseNode {
        skipWhitespace()
        let delim = try parseDelimiter()
        if let role {
            return ParseNode(
                type: .function,
                value: "big\(role):\(size)",
                children: [ParseNode(type: .symbol, value: delim)]
            )
        }
        return ParseNode(type: .function, value: "big:\(size)", children: [ParseNode(type: .symbol, value: delim)])
    }

    private mutating func consumeCommand(named name: String) throws {
        guard !isAtEnd && input[position] == "\\" else {
            throw FormulaKit.ParseError("Expected \\\(name)")
        }
        advance()
        let start = position
        while !isAtEnd && isLetter(input[position]) { advance() }
        guard String(input[start..<position]) == name else {
            throw FormulaKit.ParseError("Expected \\\(name)")
        }
    }

    private mutating func parseBinom() throws -> ParseNode {
        let num = try parseArgumentOrAtom()
        let den = try parseArgumentOrAtom()
        let frac = ParseNode(type: .function, value: "atop", children: [num, den])
        return ParseNode(
            type: .function,
            value: "leftright",
            children: [ParseNode(type: .symbol, value: "("), frac, ParseNode(type: .symbol, value: ")")]
        )
    }

    private mutating func parseArgument() throws -> ParseNode {
        skipWhitespace()
        if !isAtEnd && input[position] == "{" { return try parseGroup() }
        return try parseAtom()
    }

    /// Like `\frac12`, `\hat x`, `\sqrt2` — braced group or a single math atom.
    private mutating func parseArgumentOrAtom() throws -> ParseNode {
        skipWhitespace()
        if !isAtEnd && input[position] == "{" { return try parseGroup() }
        return try parseAtom()
    }

    private mutating func parseTag() throws -> ParseNode {
        return ParseNode(type: .tag, value: "tag", children: [try parseArgument()])
    }

    private mutating func parseAccent(label: String) throws -> ParseNode {
        return ParseNode(type: .accent, value: label, children: [try parseArgumentOrAtom()])
    }

    private mutating func parseText() throws -> ParseNode {
        skipWhitespace()
        if isAtEnd || input[position] != "{" { throw FormulaKit.ParseError("Expected '{' after \\text") }
        advance(); let start = position; var count = 1
        while !isAtEnd && count > 0 {
            if input[position] == "{" { count += 1 } else if input[position] == "}" { count -= 1 }
            if count > 0 { advance() }
        }
        let val = String(input[start..<position]);
        if isAtEnd && count > 0 { throw FormulaKit.ParseError("Unterminated \\text") }
        advance(); return ParseNode(type: .text, value: val)
    }

    private mutating func parseLeftRight() throws -> ParseNode {
        skipWhitespace()
        let left = try parseDelimiter()
        var children: [ParseNode] = [ParseNode(type: .symbol, value: left)]
        while true {
            let segment = try parseExpression(stopOnRight: true, stopOnMiddle: true)
            children.append(ParseNode(type: .group, value: "body", children: segment))
            skipWhitespace()
            if isAtEnd { throw FormulaKit.ParseError("Expected \\right") }
            guard input[position] == "\\" else { throw FormulaKit.ParseError("Expected \\right or \\middle") }
            advance()
            let cmdStart = position
            while !isAtEnd && isLetter(input[position]) { advance() }
            let cmd = String(input[cmdStart..<position])
            switch cmd {
            case "right":
                skipWhitespace()
                let right = try parseDelimiter()
                children.append(ParseNode(type: .symbol, value: right))
                return ParseNode(type: .function, value: "leftright", children: children)
            case "middle":
                skipWhitespace()
                let mid = try parseDelimiter()
                children.append(
                    ParseNode(type: .function, value: "middledelim", children: [ParseNode(type: .symbol, value: mid)])
                )
            default:
                throw FormulaKit.ParseError("Expected \\right or \\middle")
            }
        }
    }

    private mutating func parseDelimiter() throws -> String {
        if isAtEnd { throw FormulaKit.ParseError("Expected delimiter") }
        if input[position] == "\\" {
            advance(); let start = position; while !isAtEnd && isLetter(input[position]) { advance() }
            if start == position { let s = String(input[position]); advance(); return "\\" + s }
            return "\\" + String(input[start..<position])
        }
        let s = String(input[position]); advance(); return s
    }

    private mutating func parseEnvironment() throws -> ParseNode {
        skipWhitespace(); if isAtEnd || input[position] != "{" { throw FormulaKit.ParseError("Expected '{'") }
        let env = (try parseGroup()).children.map { $0.value }.joined()
        var cols = ""
        if env == "array" {
            skipWhitespace();
            if !isAtEnd && input[position] == "{" { cols = (try parseGroup()).children.map { $0.value }.joined() }
        }
        let node = try parseArray(envName: env, cols: cols)
        skipWhitespace(); if isAtEnd || input[position] != "\\" { throw FormulaKit.ParseError("Expected \\end") }
        advance(); let start = position;
        while !isAtEnd && (isLetter(input[position]) || input[position] == "*") { advance() }
        if String(input[start..<position]) != "end" { throw FormulaKit.ParseError("Expected \\end") }
        skipWhitespace(); if isAtEnd || input[position] != "{" { throw FormulaKit.ParseError("Expected '{'") }
        let endEnvName = (try parseGroup()).children.map { $0.value }.joined()
        if env != endEnvName { throw FormulaKit.ParseError("Environment mismatch") }

        let delimiters: [String: (String, String)] = [
            "pmatrix": ("(", ")"), "bmatrix": ("[", "]"), "Bmatrix": ("\\{", "\\}"),
            "vmatrix": ("|", "|"), "Vmatrix": ("\\Vert", "\\Vert"), "cases": ("\\{", "."),
            "dcases": ("\\{", "."), "rcases": (".", "\\}"),
        ]

        if let (left, right) = delimiters[env] {
            return ParseNode(
                type: .function,
                value: "leftright",
                children: [ParseNode(type: .symbol, value: left), node, ParseNode(type: .symbol, value: right)]
            )
        }
        return node
    }

    private mutating func parseArray(envName: String, cols: String) throws -> ParseNode {
        var rows: [ParseNode] = []
        while !isAtEnd {
            skipWhitespace()
            if isEndCommand { break }
            if isHlineCommand {
                try consumeCommand(named: "hline")
                rows.append(ParseNode(type: .group, value: "hline", children: []))
            } else {
                rows.append(ParseNode(type: .group, value: "row", children: try parseRow()))
            }
            skipWhitespace()
            if isEndCommand { break }
            if !isAtEnd && input[position] == "\\" {
                let next = input.index(after: position)
                if next < input.endIndex && input[next] == "\\" {
                    advance(); advance(); skipWhitespace()
                    if !isAtEnd && input[position] == "[" { _ = try parseBracketGroup() }
                } else {
                    break
                }
            } else if rows.last?.value == "hline" {
                // `\hline` is often followed by another row without an extra `\\`.
                continue
            } else {
                break
            }
        }
        return ParseNode(type: .array, value: envName + (cols.isEmpty ? "" : ":" + cols), children: rows)
    }

    private mutating func parseBracketGroup() throws -> [ParseNode] {
        advance(); var nodes: [ParseNode] = []
        while !isAtEnd && input[position] != "]" { nodes.append(try parseAtom()) }
        if !isAtEnd { advance() }; return nodes
    }

    private mutating func parseRow() throws -> [ParseNode] {
        var cells: [ParseNode] = []
        while !isAtEnd {
            cells.append(ParseNode(type: .group, value: "cell", children: try parseExpression(stopOnRowEnd: true)))
            skipWhitespace(); if !isAtEnd && input[position] == "&" { advance() } else { break }
        }
        return cells
    }

    private mutating func parseFraction(name: String = "frac") throws -> ParseNode {
        return ParseNode(
            type: .function,
            value: name,
            children: [try parseArgumentOrAtom(), try parseArgumentOrAtom()]
        )
    }

    private mutating func parseSqrt() throws -> ParseNode {
        var idx: ParseNode? = nil
        if !isAtEnd && input[position] == "[" {
            idx = ParseNode(type: .group, value: "", children: try parseBracketGroup())
        }
        let expr = try parseArgumentOrAtom(); var children = [expr]
        if let idx = idx { children.insert(idx, at: 0) }
        return ParseNode(type: .function, value: "sqrt", children: children)
    }

    private mutating func parseNumber() throws -> ParseNode {
        let start = position
        while !isAtEnd && isDigit(input[position]) { advance() }
        if !isAtEnd && input[position] == "." { advance(); while !isAtEnd && isDigit(input[position]) { advance() } }
        return ParseNode(type: .number, value: String(input[start..<position]))
    }

    private mutating func parseOperator() throws -> ParseNode {
        let s = String(input[position]); advance(); return ParseNode(type: .operator, value: s)
    }

    private mutating func parseSymbol() throws -> ParseNode {
        let s = String(input[position])
        advance()
        return ParseNode(type: .symbol, value: s)
    }

    private mutating func parseScript() throws -> ParseNode {
        let char = input[position]; advance(); let name = (char == "^") ? "sup" : "sub"
        return ParseNode(type: .function, value: name, children: [try parseArgument()])
    }

    private mutating func skipWhitespace() { while !isAtEnd && input[position].isWhitespace { advance() } }
    private mutating func advance() { position = input.index(after: position) }
    private func isLetter(_ char: Character) -> Bool { return char.isLetter }
    private func isDigit(_ char: Character) -> Bool { return char.isNumber }
    private var isAtEnd: Bool { return position >= input.endIndex }
}
