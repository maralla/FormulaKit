import CoreGraphics
import CoreText
import Foundation

private enum RendererSymbolSets {
    static let largeOperators: Set<String> = [
        "∑", "∏", "∫", "∐", "⋂", "⋃", "⨀", "⨁", "⨂", "⨄", "⨆", "⋀", "⋁",
    ]

    static let limitsOperators: Set<String> = [
        "lim", "max", "min", "sup", "inf", "det", "gcd", "Pr",
    ]
}

/// Logical font slots for stretchy delimiters (step through at body ``fontSize`` before any point-size scaling).
private enum RendererDelimiterTiers {
    static let logicalFontNames: [String] = [
        MathLogicalFontNames.mainRegular,
        MathLogicalFontNames.size1Regular,
        MathLogicalFontNames.size2Regular,
        MathLogicalFontNames.size3Regular,
        MathLogicalFontNames.size4Regular,
    ]
}

/// Renders a parse tree into an attributed string representation.
public struct Renderer {
    /// The rendering options.
    private let options: FormulaKit.Options

    /// Initialize a renderer with options.
    /// - Parameter options: Rendering options.
    public init(options: FormulaKit.Options) {
        var o = options
        if o.symbolRenderScratch == nil {
            o.symbolRenderScratch = SymbolRenderScratch()
        }
        self.options = o
    }

    /// Text runs (Core Text) plus vector decorations (fraction bars, braces, etc.) and root ``Box`` metrics.
    public func render(node: ParseNode) -> MathCompositeLayout {
        let layoutNode = buildLayoutNode(node, options: options)
        let rootBox = layoutNode.getBox(options: options)
        let decoration = layoutNode.renderDecoration(at: .zero, options: options)
        let runs = layoutNode.collectTextRuns(at: .zero, options: options)
        return MathCompositeLayout(
            decorationPath: decoration,
            textRuns: runs,
            rootBox: rootBox,
            symbolRenderScratch: options.symbolRenderScratch,
            mathFont: options.mathFont
        )
    }

    /// Build a LayoutNode tree from a ParseNode tree.
    /// - Parameter node: Parse node.
    /// - Parameter options: Rendering options.
    /// - Returns: Corresponding LayoutNode.
    private func buildLayoutNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        switch node.type {
        case .root:
            return HorizontalBox(children: buildNodesWithSpacing(node.children, options: options))
        case .number:
            return buildNumberNode(node, options: options)
        case .operator:
            let type = getAtomType(for: node.value)
            return SymbolNode(
                character: node.value,
                type: type,
                fontName: MathLogicalFontNames.mainRegular,
                fontSize: options.fontSize
            )
        case .symbol:
            return buildSymbolNode(node, options: options)
        case .function:
            if node.value == "leftright" {
                return buildLeftRightNode(node, options: options)
            }
            if node.value == "middledelim" {
                // Only valid inside `\left...\right`; stray `\middle` fragments should not crash.
                guard let inner = node.children.first else { return SpaceNode(width: 0) }
                return buildLayoutNode(inner, options: options)
            }
            if node.value == "nonumber" {
                return SpaceNode(width: 0)
            }
            return buildFunctionNode(node, options: options)
        case .group:
            return HorizontalBox(children: buildNodesWithSpacing(node.children, options: options))
        case .array:
            return buildArrayNode(node, options: options)
        case .text:
            return buildTextNode(node, options: options)
        case .accent:
            return buildAccentNode(node, options: options)
        case .tag:
            return buildTagNode(node, options: options)
        case .style:
            return buildStyleNode(node, options: options)
        case .horizBrace:
            return buildHorizBraceNode(node, options: options)
        }
    }

    private func buildNumberNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        var children: [LayoutNode] = []
        for char in node.value {
            children.append(
                SymbolNode(
                    character: String(char),
                    type: .mord,
                    fontName: MathLogicalFontNames.mainRegular,
                    fontSize: options.fontSize
                )
            )
        }

        if children.count == 1 {
            return children[0]
        }
        return HorizontalBox(children: children, type: .mord)
    }

    private func buildSymbolNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        let type = getAtomType(for: node.value)

        // Large operators in display style
        if type == .mop && options.style == .display && RendererSymbolSets.largeOperators.contains(node.value) {
            return SymbolNode(
                character: node.value,
                type: type,
                fontName: MathLogicalFontNames.size2Regular,
                fontSize: options.fontSize * 1.2
            )
        }

        if node.value.count > 1 {
            // Multi-character operator like \tanh, \sin, etc.
            var children: [LayoutNode] = []
            for char in node.value {
                children.append(
                    SymbolNode(
                        character: String(char),
                        type: .mord,
                        fontName: MathLogicalFontNames.mainRegular,
                        fontSize: options.fontSize
                    )
                )
            }
            return HorizontalBox(children: children, type: type)
        }

        // Single character symbol
        let s = node.value
        let isLetter = s.rangeOfCharacter(from: .letters) != nil
        let fontName = isLetter ? MathLogicalFontNames.mathItalic : MathLogicalFontNames.mainRegular
        return SymbolNode(character: s, type: type, fontName: fontName, fontSize: options.fontSize)
    }

    private func getAtomType(for value: String) -> AtomType {
        let operators = [
            "sin", "cos", "tan", "cot", "sec", "csc", "sinh", "cosh", "tanh", "arcsin", "arccos", "arctan", "ln", "log",
            "exp", "lim", "sup", "inf", "max", "min", "det", "arg", "gcd", "Pr",
        ]

        if [
            "+", "-", "±", "×", "÷", "*", "\u{22C5}", "\u{2299}", "∧", "∨", "∩", "∪", "⊎", "⊓", "⊔", "⊖", "◯", "≀", "⨿",
            "&", "⊕", "⊗",
        ].contains(value) {
            return .mbin
        } else if [
            "=", "<", ">", "≤", "≥", "≈", "≠", "←", "→", "⇐", "⇒", "↔", "⇔",
            "↑", "↓", "⇑", "⇓",
            "⟵", "⟶", "⟷", "⟸", "⟹", "⟺", "↦", "⟼",
            "↗", "↘", "↙", "↖", "↩", "↪", "↼", "⇀", "↽", "⇁", "⇌",
            "∈", "∉", "⊂", "⊃", "⊆", "⊇", "⫅", "⫆",
            "≡", "∼", "≅", "≺", "≻", "⪯", "⪰", "≃", "≍", "≪", "≫", "⩽", "⩾",
            "∣", "∥", "⊥", "⋈", "⌣", "⌢", "∋", "⊢", "⊣", "≐", "⊑", "⊒", "⊨", "∴", "∵", "\u{2236}",
        ].contains(value) {
            return .mrel
        } else if [",", ";", "\u{2026}", "\u{22EF}", "\u{22EE}", "\u{22F1}"].contains(value) {
            return .mpunct
        } else if ["(", "[", "{", "|"].contains(value) {
            return .mopen
        } else if [")", "]", "}", "|"].contains(value) {
            return .mclose
        } else if RendererSymbolSets.largeOperators.contains(value) || operators.contains(value) {
            return .mop
        }
        return .mord
    }

    private static let spacingTable: [AtomType: [AtomType: Int]] = [
        .mord: [.mop: 3, .mbin: 4, .mrel: 5, .minner: 3],
        .mop: [.mord: 3, .mop: 3, .mrel: 5, .minner: 3],
        .mbin: [.mord: 4, .mop: 4, .mopen: 4, .minner: 4],
        // Rel–rel: classic TeX uses no glue; STIX relations often extend past the advance, so add extra muskip when needed.
        .mrel: [.mord: 5, .mop: 5, .mopen: 5, .minner: 5, .mrel: 10],
        .mclose: [.mop: 3, .mbin: 4, .mrel: 5, .minner: 3],
        .mpunct: [.mord: 3, .mop: 3, .mrel: 5, .mopen: 3, .mclose: 3, .mpunct: 3, .minner: 3],
        .minner: [.mord: 3, .mop: 3, .mbin: 4, .mrel: 5, .mopen: 3, .mpunct: 3, .minner: 3],
    ]

    private func buildNodesWithSpacing(_ nodes: [ParseNode], options: FormulaKit.Options) -> [LayoutNode] {
        let builtNodes: [LayoutNode] = nodes.map { buildLayoutNode($0, options: options) }
        var layoutNodes: [LayoutNode] = []

        var effectiveTypes: [AtomType] = builtNodes.map { $0.type }
        for i in 0..<effectiveTypes.count {
            if effectiveTypes[i] == .mbin {
                let isFirst = (i == 0)
                let isLast = (i == effectiveTypes.count - 1)

                var prevIsNonOp = false
                if i > 0 {
                    let prev = effectiveTypes[i - 1]
                    if prev == .mbin || prev == .mrel || prev == .mopen || prev == .mpunct {
                        prevIsNonOp = true
                    }
                }

                if isFirst || isLast || prevIsNonOp {
                    effectiveTypes[i] = .mord
                }
            }
        }

        // In script / scriptscript, omit mu-glue so subscripts like $t{-1}$ stay tight (TeX-style).
        let isScripty = options.style.sizeIndex >= 2

        for (index, node) in builtNodes.enumerated() {
            if index > 0, !isScripty {
                // Italic correction after the previous atom (math-italic letters, etc.) — TeX inserts
                // this kern before inter-atom glue so slanted glyphs don’t collide with the next symbol.
                let prevType = effectiveTypes[index - 1]
                let prevBox = builtNodes[index - 1].getBox(options: options)
                // Delimiter LSB hang: room for `(` ink left of its origin. After `.mop` we must still add
                // hang (otherwise overlaps, e.g. `\tanh(`), but full hang reads too loose vs TeX once `.mop`
                // italic correction is already zeroed — shave µ (``MathFontProviding/layout``).
                let rawHang = openingDelimiterLeftHangPt(parseNode: nodes[index], options: options)
                let fm = FontMetrics.getMetrics(for: options)
                let mopRoundOpenShave =
                    fm.cssEmPerMu * options.fontSize * options.resolvedMathFont.layout.mopRoundOpenParenHangShaveMu
                let delimHang: CGFloat
                switch prevType {
                case .mord, .minner, .mclose, .mpunct:
                    delimHang = rawHang
                case .mop:
                    if rawHang > 0, parseNodeStartsWithRoundOpenDelimiter(nodes[index]) {
                        delimHang = max(0, rawHang - mopRoundOpenShave)
                    } else {
                        delimHang = rawHang
                    }
                case .mbin, .mrel, .mopen:
                    delimHang = 0
                }
                // Multi-letter `\tanh` / `\sin`: last letter may still report serif ic; never use it before `(`.
                let prevItalic: CGFloat = (prevType == .mop) ? 0 : prevBox.italicCorrection
                let currType = effectiveTypes[index]
                let kernAfterPrev = prevItalic + delimHang
                if abs(kernAfterPrev) > 0.000_5 {
                    layoutNodes.append(SpaceNode(width: kernAfterPrev))
                }
                let spaceMu = Renderer.spacingTable[prevType]?[currType] ?? 0
                if spaceMu > 0 {
                    let spaceWidth = CGFloat(spaceMu) * fm.cssEmPerMu * options.fontSize
                    layoutNodes.append(SpaceNode(width: spaceWidth))
                }
            }
            layoutNodes.append(node)
        }

        return layoutNodes
    }

    /// Extra kern before an opening delimiter: ``CTLineDraw`` can extend ink **left** of the baseline origin (negative LSB).
    private func openingDelimiterLeftHangPt(parseNode: ParseNode, options: FormulaKit.Options) -> CGFloat {
        let delim: String?
        switch parseNode.type {
        case .symbol:
            switch parseNode.value {
            case "(", "[", "{", "⌊", "⌈", "⟨", "⟮":
                delim = parseNode.value
            default:
                delim = nil
            }
        case .function where parseNode.value == "leftright":
            guard let raw = parseNode.children.first?.value else { return 0 }
            let ch = cleanDelimiter(raw)
            if ["(", "[", "{", "⌊", "⌈", "⟨", "⟮"].contains(ch) {
                delim = ch
            } else {
                delim = nil
            }
        default:
            delim = nil
        }
        guard let d = delim, !d.isEmpty else { return 0 }
        // Short fences use ``MathLogicalFontNames/mainRegular`` at body size; matches ``buildLeftRightNode`` for small inner height.
        return SymbolNode.ctLineDrawingLeftHangPt(
            character: d,
            fontName: MathLogicalFontNames.mainRegular,
            fontSize: options.fontSize,
            mathFont: options.mathFont
        )
    }

    private func parseNodeStartsWithRoundOpenDelimiter(_ node: ParseNode) -> Bool {
        switch node.type {
        case .symbol:
            return node.value == "("
        case .function where node.value == "leftright":
            guard let raw = node.children.first?.value else { return false }
            return cleanDelimiter(raw) == "("
        default:
            return false
        }
    }

    /// Math-mode glue from reference `macros.js` (`\tmspace` uses `cssEmPerMu` × `fontSize`).
    private func spaceWidthMu(_ signedMu: CGFloat, options: FormulaKit.Options) -> CGFloat {
        let fm = FontMetrics.getMetrics(for: options)
        return signedMu * fm.cssEmPerMu * options.fontSize
    }

    /// Parse a TeX-style dimension string (`0.5em`, `-3mu`, `12pt`) into horizontal width (points).
    private func layoutWidth(fromDimensionString raw: String, options: FormulaKit.Options) -> CGFloat {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !t.isEmpty else { return 0 }
        var s = String(t)
        var neg = false
        if s.first == "-" {
            neg = true
            s.removeFirst()
        } else if s.first == "+" {
            s.removeFirst()
        }
        s = s.trimmingCharacters(in: .whitespaces)
        var numStr = ""
        for ch in s {
            if ch.isNumber || ch == "." {
                numStr.append(ch)
            } else {
                break
            }
        }
        guard let mag = Double(numStr), !numStr.isEmpty else { return 0 }
        var v = CGFloat(mag)
        if neg { v = -v }
        let rest = String(s.dropFirst(numStr.count)).trimmingCharacters(in: .whitespaces)
        let unit: String
        if rest.isEmpty {
            unit = "pt"
        } else {
            unit = rest
        }
        let fm = FontMetrics.getMetrics(for: options)
        switch unit {
        case "em":
            return v * options.fontSize
        case "ex":
            return v * fm.xHeight * options.fontSize
        case "mu":
            return v * fm.cssEmPerMu * options.fontSize
        case "pt":
            return v
        case "px":
            return v * (72.0 / 96.0)
        default:
            return v * options.fontSize
        }
    }

    private func flattenedMathText(_ node: ParseNode) -> String {
        switch node.type {
        case .symbol, .number, .text:
            return node.value
        case .group:
            return node.children.map { flattenedMathText($0) }.joined()
        case .function:
            if ["frac", "sqrt", "supsub", "sup", "sub", "leftright"].contains(node.value) {
                return ""
            }
            return node.children.map { flattenedMathText($0) }.joined()
        default:
            return ""
        }
    }

    private func buildOperatorNameNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        guard let arg = node.children.first else { return SpaceNode(width: 0) }
        let text = flattenedMathText(arg)
        if text.isEmpty { return SpaceNode(width: 0) }
        var glyphs: [LayoutNode] = []
        for ch in text {
            glyphs.append(
                SymbolNode(
                    character: String(ch),
                    type: .mop,
                    fontName: MathLogicalFontNames.mainRegular,
                    fontSize: options.fontSize,
                    metricsTextMode: true
                )
            )
        }
        return HorizontalBox(children: glyphs, type: .mop)
    }

    /// `\overset` / `\underset` / `\stackrel` (parser maps stackrel → overset).
    private func buildOversetUndersetNode(_ node: ParseNode, options: FormulaKit.Options, under: Bool) -> LayoutNode {
        guard node.children.count >= 2 else { return SpaceNode(width: 0) }
        let labelNode = node.children[0]
        let baseNode = node.children[1]
        let scriptOpts = options.withStyle(options.style.sup())
        let label = buildLayoutNode(labelNode, options: scriptOpts)
        let base = buildLayoutNode(baseNode, options: options)
        let lb = label.getBox(options: scriptOpts)
        let bb = base.getBox(options: options)
        let gap: CGFloat = 0.08 * options.fontSize
        let w = max(lb.width, bb.width)
        func pad(_ n: LayoutNode, _ innerW: CGFloat, opt: FormulaKit.Options) -> LayoutNode {
            let p = max(0, (w - innerW) / 2)
            return HorizontalBox(children: [SpaceNode(width: p), n, SpaceNode(width: p)])
        }
        let basePadded = pad(base, bb.width, opt: options)
        let labelPadded = pad(label, lb.width, opt: scriptOpts)
        if under {
            return VerticalBox(
                elements: [
                    VerticalBox.Element(node: basePadded, shift: 0),
                    VerticalBox.Element(node: labelPadded, shift: -(bb.depth + gap + lb.height)),
                ],
                position: .individualShift,
                type: .mrel
            )
        }
        return VerticalBox(
            elements: [
                VerticalBox.Element(node: basePadded, shift: 0),
                VerticalBox.Element(node: labelPadded, shift: bb.height + gap + lb.depth),
            ],
            position: .individualShift,
            type: .mrel
        )
    }

    private func bigDelimiterFontName(for sizeToken: String) -> String {
        switch sizeToken {
        case "big": return MathLogicalFontNames.size1Regular
        case "Big": return MathLogicalFontNames.size2Regular
        case "bigg": return MathLogicalFontNames.size3Regular
        case "Bigg": return MathLogicalFontNames.size4Regular
        default: return MathLogicalFontNames.size1Regular
        }
    }

    /// `\big` / `\Big` / `\bigg` / `\Bigg` (and `l` / `r` / `m` variants): discrete Size* slot + mild scale cap so strokes stay near text weight.
    private func scaledBigDelimiterNode(
        character: String,
        type: AtomType,
        sizeToken: String,
        options: FormulaKit.Options
    ) -> LayoutNode {
        let fontName = bigDelimiterFontName(for: sizeToken)
        let sizing = options.resolvedMathFont.delimiterSizing
        guard let minMult = sizing.bigDelimiterMinHeightMultiples[sizeToken] else {
            return SymbolNode(character: character, type: type, fontName: fontName, fontSize: options.fontSize)
        }
        let required = options.fontSize * minMult
        let base = SymbolNode(character: character, type: type, fontName: fontName, fontSize: options.fontSize)
        let h = base.getBox(options: options).totalHeight
        if h >= required * 0.995 {
            return SymbolNode(character: character, type: type, fontName: fontName, fontSize: options.fontSize)
        }
        guard h > 0 else {
            return SymbolNode(character: character, type: type, fontName: fontName, fontSize: options.fontSize)
        }
        let scale = min(required / h, sizing.bigDelimiterMaxExtraScale)
        return SymbolNode(character: character, type: type, fontName: fontName, fontSize: options.fontSize * scale)
    }

    private func buildBigDelimiterNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        guard let delimNode = node.children.first else { return SpaceNode(width: 0) }
        let v = node.value
        let sizeToken: String
        let atom: AtomType
        if v.hasPrefix("bigopen:") {
            sizeToken = String(v.dropFirst(8))
            atom = .mopen
        } else if v.hasPrefix("bigclose:") {
            sizeToken = String(v.dropFirst(9))
            atom = .mclose
        } else if v.hasPrefix("bigrel:") {
            sizeToken = String(v.dropFirst(7))
            atom = .mrel
        } else if v.hasPrefix("big:") {
            let st = String(v.dropFirst(4))
            let ch0 = cleanDelimiter(delimNode.value)
            if ch0.isEmpty { return SpaceNode(width: 0) }
            let inferred: AtomType
            if ["(", "[", "{", "⌊", "⌈", "⟨", "⟮"].contains(ch0) {
                inferred = .mopen
            } else if [")", "]", "}", "⌋", "⌉", "⟩", "⟯"].contains(ch0) {
                inferred = .mclose
            } else {
                inferred = .mrel
            }
            return scaledBigDelimiterNode(character: ch0, type: inferred, sizeToken: st, options: options)
        } else {
            return SpaceNode(width: 0)
        }
        let ch = cleanDelimiter(delimNode.value)
        if ch.isEmpty { return SpaceNode(width: 0) }
        return scaledBigDelimiterNode(character: ch, type: atom, sizeToken: sizeToken, options: options)
    }

    private func verticallyCenterDelimiter(
        _ layout: LayoutNode,
        axisHeight: CGFloat,
        options: FormulaKit.Options
    ) -> LayoutNode {
        let box = layout.getBox(options: options)
        let shift = axisHeight - (box.height - box.totalHeight / 2)
        return VerticalBox(elements: [VerticalBox.Element(node: layout, shift: shift)], position: .individualShift)
    }

    /// Picks delimiter coverage: **OpenType math** ``.s*`` masters on the primary face when available, else Main → Size4 + capped scale.
    private func leftRightDelimiterFontAndScale(
        probeCharacter: String,
        requiredTotalHeight: CGFloat,
        bodyFontSize: CGFloat,
        sizing: DelimiterSizing,
        options: FormulaKit.Options
    ) -> (fontName: String, scale: CGFloat, openTypeMathGlyphName: String?) {
        let tiers = RendererDelimiterTiers.logicalFontNames
        let mainRegular = MathLogicalFontNames.mainRegular
        guard !probeCharacter.isEmpty, requiredTotalHeight > 0 else {
            return (tiers[0], 1.0, nil)
        }

        let rawOTNames = options.resolvedMathFont.openTypeMathStretchDelimiterGlyphNames(for: probeCharacter)
        if !rawOTNames.isEmpty {
            let ctFont = SymbolNode.ctFontForMathGlyph(
                fontName: mainRegular,
                character: probeCharacter,
                fontSize: bodyFontSize,
                mathFont: options.mathFont
            )
            let otNames = rawOTNames.filter { CTFontGetGlyphWithName(ctFont, $0 as CFString) != 0 }
            if !otNames.isEmpty {
                var bestName = otNames[0]
                var bestH: CGFloat = 0
                for gn in otNames {
                    let probe = SymbolNode(
                        character: probeCharacter,
                        type: .mopen,
                        fontName: mainRegular,
                        fontSize: bodyFontSize,
                        openTypeMathGlyphName: gn
                    )
                    let h = probe.getBox(options: options).totalHeight
                    guard h > 0 else { continue }
                    bestName = gn
                    bestH = h
                    if h >= requiredTotalHeight * 0.995 {
                        return (mainRegular, 1.0, gn)
                    }
                }
                if bestH > 0 {
                    let raw = requiredTotalHeight / bestH
                    let scale = min(max(raw, 1.0), sizing.leftRightMaxExtraScale)
                    return (mainRegular, scale, bestName)
                }
            }
        }

        for fontName in tiers {
            let probe = SymbolNode(
                character: probeCharacter,
                type: .mopen,
                fontName: fontName,
                fontSize: bodyFontSize
            )
            let h = probe.getBox(options: options).totalHeight
            if h >= requiredTotalHeight * 0.995 {
                return (fontName, 1.0, nil)
            }
        }
        let fontName = tiers[4]
        let baseProbe = SymbolNode(
            character: probeCharacter,
            type: .mopen,
            fontName: fontName,
            fontSize: bodyFontSize
        )
        let baseH = baseProbe.getBox(options: options).totalHeight
        guard baseH > 0 else { return (fontName, 1.0, nil) }
        let raw = requiredTotalHeight / baseH
        let scale = min(max(raw, 1.0), sizing.leftRightMaxExtraScale)
        return (fontName, scale, nil)
    }

    private func buildFunctionNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        switch node.value {
        case let v where v.hasPrefix("kern:"):
            return SpaceNode(width: layoutWidth(fromDimensionString: String(v.dropFirst(5)), options: options))
        case let v where v.hasPrefix("hskip:"):
            return SpaceNode(width: layoutWidth(fromDimensionString: String(v.dropFirst(6)), options: options))
        case let v where v.hasPrefix("mskip:"):
            return SpaceNode(width: layoutWidth(fromDimensionString: String(v.dropFirst(6)), options: options))
        case let v where v.hasPrefix("hspace:"):
            return SpaceNode(width: layoutWidth(fromDimensionString: String(v.dropFirst(7)), options: options))
        case let v
        where v.hasPrefix("bigopen:") || v.hasPrefix("bigclose:") || v.hasPrefix("bigrel:") || v.hasPrefix("big:"):
            return buildBigDelimiterNode(node, options: options)
        case "operatorname", "operatorname*":
            return buildOperatorNameNode(node, options: options)
        case "mathchoice":
            guard node.children.count >= 4 else { return SpaceNode(width: 0) }
            let idx = min(3, max(0, options.style.sizeIndex))
            return buildLayoutNode(node.children[idx], options: options)
        case "overset":
            return buildOversetUndersetNode(node, options: options, under: false)
        case "underset":
            return buildOversetUndersetNode(node, options: options, under: true)
        case "phantom":
            guard let c = node.children.first else { return SpaceNode(width: 0) }
            let ghost = buildLayoutNode(c, options: options)
            let box = ghost.getBox(options: options)
            return OpaqueStrutNode(width: box.width, height: box.height, depth: box.depth)
        case "hphantom":
            guard let c = node.children.first else { return SpaceNode(width: 0) }
            let ghost = buildLayoutNode(c, options: options)
            let box = ghost.getBox(options: options)
            return OpaqueStrutNode(width: box.width, height: 0, depth: 0)
        case "vphantom":
            guard let c = node.children.first else { return SpaceNode(width: 0) }
            let ghost = buildLayoutNode(c, options: options)
            let box = ghost.getBox(options: options)
            return OpaqueStrutNode(width: 0, height: box.height, depth: box.depth)
        case "smash":
            guard let c = node.children.first else { return SpaceNode(width: 0) }
            return SmashNode(content: buildLayoutNode(c, options: options))
        case "thinspace":
            return SpaceNode(width: spaceWidthMu(3, options: options))
        case "negthinspace":
            return SpaceNode(width: spaceWidthMu(-3, options: options))
        case "medspace":
            return SpaceNode(width: spaceWidthMu(4, options: options))
        case "thickspace":
            return SpaceNode(width: spaceWidthMu(5, options: options))
        case "negmedspace":
            return SpaceNode(width: spaceWidthMu(-4, options: options))
        case "negthickspace":
            return SpaceNode(width: spaceWidthMu(-5, options: options))
        case "enspace", "enskip":
            return SpaceNode(width: 0.5 * options.fontSize)
        case "quad", "qquad":
            // TeX horizontal space (`\quad` = 1em, `\qquad` = 2em). Without this, the default
            // branch drew the letters "quad" / "qquad" as `.mop` glyphs.
            let fm = FontMetrics.getMetrics(for: options)
            let em = options.fontSize
            let w = (node.value == "qquad" ? 2 : 1) * fm.quad * em
            return SpaceNode(width: w)
        case "frac", "dfrac":
            return buildFractionNode(node, options: options)
        case "sqrt":
            return buildSqrtNode(node, options: options)
        case "supsub":
            return buildSupSubNode(node, options: options)
        case "sup":
            return buildSupSubNode(
                ParseNode(
                    type: .function,
                    value: "supsub",
                    children: [ParseNode(type: .symbol, value: ""), node]
                ),
                options: options
            )
        case "sub":
            return buildSupSubNode(
                ParseNode(
                    type: .function,
                    value: "supsub",
                    children: [ParseNode(type: .symbol, value: ""), node]
                ),
                options: options
            )
        default:
            // Multi-letter commands (\tanh, \sin, …) must be one glyph per character with .mop
            let name = node.value
            let nameNodes: [LayoutNode] =
                name.isEmpty
                ? []
                : name.map { ch in
                    SymbolNode(
                        character: String(ch),
                        type: .mop,
                        fontName: MathLogicalFontNames.mainRegular,
                        fontSize: options.fontSize
                    )
                }
            return HorizontalBox(
                children: nameNodes + buildNodesWithSpacing(node.children, options: options),
                type: .mop
            )
        }
    }

    private func buildTextNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        var children: [LayoutNode] = []
        for char in node.value {
            children.append(
                SymbolNode(
                    character: String(char),
                    type: .mord,
                    fontName: MathLogicalFontNames.mainRegular,
                    fontSize: options.fontSize,
                    metricsTextMode: true
                )
            )
        }
        return HorizontalBox(children: children)
    }

    private func buildStyleNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        guard !node.children.isEmpty else { return SpaceNode(width: 0) }
        let styleName = node.value
        let content = node.children[0]
        switch styleName {
        case "displaystyle":
            return buildLayoutNode(content, options: options.withStyle(.display))
        case "textstyle":
            return buildLayoutNode(content, options: options.withStyle(.text))
        case "scriptstyle":
            return buildLayoutNode(content, options: options.withStyle(.script))
        case "scriptscriptstyle":
            return buildLayoutNode(content, options: options.withStyle(.scriptScript))
        default:
            return applyStyle(styleName, to: content, options: options)
        }
    }

    private func applyStyle(_ styleName: String, to node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        if node.type == .symbol || node.type == .number || node.type == .operator {
            let fontName: String
            switch styleName {
            case "mathbb": fontName = MathLogicalFontNames.amsRegular
            case "mathbf": fontName = MathLogicalFontNames.mainBold
            case "mathit": fontName = MathLogicalFontNames.mainItalic
            case "mathrm": fontName = MathLogicalFontNames.mainRegular
            case "mathsf": fontName = MathLogicalFontNames.sansSerifRegular
            case "mathtt": fontName = MathLogicalFontNames.typewriterRegular
            case "mathcal": fontName = MathLogicalFontNames.caligraphicRegular
            case "boldsymbol": fontName = MathLogicalFontNames.mainBold
            default: fontName = MathLogicalFontNames.mainRegular
            }
            let atom: AtomType
            if styleName == "boldsymbol", node.type == .symbol, node.value.count == 1,
                node.value.rangeOfCharacter(from: .letters) != nil
            {
                atom = .mord
            } else {
                atom = node.type == .operator ? .mop : .mord
            }
            // `\mathcal` / `\mathbb`: optional Unicode substitution via ``MathFontProviding``; `nil` keeps ASCII + logical font.
            if styleName == "mathcal", node.type == .symbol, node.value.count == 1, let ch = node.value.first,
                let script = options.resolvedMathFont.mathcalMappedLetter(ch)
            {
                return SymbolNode(
                    character: script,
                    type: .mord,
                    fontName: MathLogicalFontNames.mainRegular,
                    fontSize: options.fontSize
                )
            }
            if styleName == "mathbb", node.type == .symbol, node.value.count == 1, let ch = node.value.first,
                let bb = options.resolvedMathFont.mathbbMappedLetter(ch)
            {
                return SymbolNode(
                    character: bb,
                    type: .mord,
                    fontName: MathLogicalFontNames.mainRegular,
                    fontSize: options.fontSize
                )
            }
            return SymbolNode(character: node.value, type: atom, fontName: fontName, fontSize: options.fontSize)
        } else if node.type == .group {
            let children = node.children.map { applyStyle(styleName, to: $0, options: options) }
            return HorizontalBox(children: children)
        } else {
            return buildLayoutNode(node, options: options)
        }
    }

    private func buildTagNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        guard !node.children.isEmpty else { return SpaceNode(width: 0) }
        let tagContent = buildLayoutNode(node.children[0], options: options)
        let leftParen = SymbolNode(
            character: "(",
            type: .mopen,
            fontName: MathLogicalFontNames.mainRegular,
            fontSize: options.fontSize
        )
        let rightParen = SymbolNode(
            character: ")",
            type: .mclose,
            fontName: MathLogicalFontNames.mainRegular,
            fontSize: options.fontSize
        )
        let tagBox = HorizontalBox(children: [leftParen, tagContent, rightParen])
        return HorizontalBox(children: [SpaceNode(width: 50), tagBox])
    }

    private func buildAccentNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        guard !node.children.isEmpty else { return SymbolNode(character: "?") }
        let base = buildLayoutNode(node.children[0], options: options)
        let baseBox = base.getBox(options: options)
        let accentSymbol = getAccentSymbol(for: node.value)
        let accent = SymbolNode(
            character: accentSymbol,
            type: .mord,
            fontName: MathLogicalFontNames.mainRegular,
            fontSize: options.fontSize
        )
        let accentBox = accent.getBox(options: options)
        let metrics = FontMetrics.getMetrics(for: options.fontSize)
        let clearance = min(baseBox.height, metrics.xHeight * options.fontSize)
        let shift = (baseBox.width - accentBox.width) / 2
        let centeredAccent = HorizontalBox(children: [SpaceNode(width: shift), accent])
        return VerticalBox(
            elements: [
                VerticalBox.Element(node: base, shift: 0),
                VerticalBox.Element(node: centeredAccent, shift: baseBox.height - clearance + accentBox.height * 0.2),
            ],
            position: .individualShift
        )
    }

    private func getAccentSymbol(for label: String) -> String {
        let mappings: [String: String] = [
            "\\vec": "→", "\\bar": "ˉ", "\\hat": "ˆ", "\\tilde": "˜", "\\dot": "˙", "\\ddot": "¨", "\\acute": "´",
            "\\grave": "`", "\\check": "ˇ", "\\breve": "˘",
        ]
        return mappings[label] ?? "?"
    }

    private func buildLeftRightNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        guard node.children.count >= 3 else { return SymbolNode(character: "?") }
        let leftDelimStr = node.children[0].value
        let rightDelimStr = node.children[node.children.count - 1].value

        var bodyLayouts: [LayoutNode] = []
        var middleDelimStrs: [String] = []
        var idx = 1
        while idx < node.children.count - 1 {
            let child = node.children[idx]
            if child.type == .function && child.value == "middledelim" {
                return SymbolNode(character: "?")
            }
            bodyLayouts.append(buildLayoutNode(child, options: options))
            idx += 1
            if idx < node.children.count - 1 {
                let midNode = node.children[idx]
                if midNode.type == .function && midNode.value == "middledelim", let sym = midNode.children.first {
                    middleDelimStrs.append(sym.value)
                    idx += 1
                }
            }
        }

        let innerRow = HorizontalBox(
            children: {
                var parts: [LayoutNode] = []
                for i in 0..<bodyLayouts.count {
                    parts.append(bodyLayouts[i])
                    if i < middleDelimStrs.count {
                        let midCh = cleanDelimiter(middleDelimStrs[i])
                        if !midCh.isEmpty {
                            parts.append(
                                SymbolNode(
                                    character: midCh,
                                    type: .mrel,
                                    fontName: MathLogicalFontNames.mainRegular,
                                    fontSize: options.fontSize
                                )
                            )
                        }
                    }
                }
                return parts
            }()
        )
        let innerBox = innerRow.getBox(options: options)

        let metrics = FontMetrics.getMetrics(for: options.fontSize)
        let axisHeight = metrics.axisHeight * options.fontSize

        let heightAboveAxis = innerBox.height - axisHeight
        let depthBelowAxis = innerBox.depth + axisHeight
        let maxExtent = max(heightAboveAxis, depthBelowAxis)
        let totalExtent = maxExtent * 2

        let leftCh = cleanDelimiter(leftDelimStr)
        let rightCh = cleanDelimiter(rightDelimStr)
        let delimSizing = options.resolvedMathFont.delimiterSizing
        let slack = max(delimSizing.requiredHeightSlackMinPt, delimSizing.requiredHeightSlackEm * options.fontSize)
        // Only inflate the target when the inner is genuinely tall; modest inners (e.g. after `\mathcal{N}`)
        // should not pick up extra height that bleeds rasterized ink into delimiter kerns.
        let innerTall = innerBox.totalHeight > options.fontSize * 1.75
        let heightMult = innerTall ? max(1, delimSizing.leftRightTargetHeightMultiple) : 1
        let requiredDelimHeight = (totalExtent + slack) * heightMult
        let probeChar = leftCh.isEmpty ? rightCh : leftCh
        let (fontName, finalScale, otProbeGlyphName) = leftRightDelimiterFontAndScale(
            probeCharacter: probeChar,
            requiredTotalHeight: requiredDelimHeight,
            bodyFontSize: options.fontSize,
            sizing: delimSizing,
            options: options
        )
        let leftOT =
            leftCh.isEmpty
            ? nil
            : options.resolvedMathFont.openTypeMatchingStretchDelimiterGlyphName(
                character: leftCh,
                templateGlyphName: otProbeGlyphName
            )
        let rightOT =
            rightCh.isEmpty
            ? nil
            : options.resolvedMathFont.openTypeMatchingStretchDelimiterGlyphName(
                character: rightCh,
                templateGlyphName: otProbeGlyphName
            )

        let leftDelim = SymbolNode(
            character: leftCh,
            type: .mopen,
            fontName: fontName,
            fontSize: options.fontSize * finalScale,
            openTypeMathGlyphName: leftOT
        )
        let rightDelim = SymbolNode(
            character: rightCh,
            type: .mclose,
            fontName: fontName,
            fontSize: options.fontSize * finalScale,
            openTypeMathGlyphName: rightOT
        )

        let leftVBox = verticallyCenterDelimiter(leftDelim, axisHeight: axisHeight, options: options)
        let rightVBox = verticallyCenterDelimiter(rightDelim, axisHeight: axisHeight, options: options)

        var row: [LayoutNode] = [leftVBox]
        for i in 0..<bodyLayouts.count {
            row.append(bodyLayouts[i])
            if i < middleDelimStrs.count {
                let midCh = cleanDelimiter(middleDelimStrs[i])
                if !midCh.isEmpty {
                    let midNode = SymbolNode(
                        character: midCh,
                        type: .mrel,
                        fontName: fontName,
                        fontSize: options.fontSize * finalScale
                    )
                    row.append(verticallyCenterDelimiter(midNode, axisHeight: axisHeight, options: options))
                }
            }
        }
        row.append(rightVBox)
        // Delimited subformula is `\mathinner` in TeX — enables `mord`–`minner` mu-glue (e.g. before `\mathcal{N}(…)`).
        return HorizontalBox(children: row, type: .minner)
    }

    private func cleanDelimiter(_ delim: String) -> String {
        let mappings: [String: String] = [
            "\\{": "{", "\\}": "}", "\\lbrace": "{", "\\rbrace": "}", "\\lbrack": "[", "\\rbrack": "]",
            "\\vert": "|", "|": "|", "\\Vert": "‖", "\\|": "‖", "\\lVert": "‖", "\\rVert": "‖", "(": "(", ")": ")",
            "[": "[", "]": "]",
            "\\lfloor": "⌊", "\\rfloor": "⌋", "\\lceil": "⌈", "\\rceil": "⌉",
            ".": "", "\\left\\lfloor": "⌊", "\\right\\rfloor": "⌋",
        ]
        return mappings[delim] ?? delim.replacingOccurrences(of: "\\", with: "")
    }

    private func buildArrayNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        let parts = node.value.split(separator: ":", maxSplits: 1)
        let envStem = parts.isEmpty ? "" : String(parts[0])
        let colSpec = parts.count > 1 ? String(parts[1]) : ""

        var grid: [[LayoutNode]] = []
        var isHlineRow: [Bool] = []
        for rowNode in node.children {
            if rowNode.value == "hline" {
                isHlineRow.append(true)
                grid.append([])
            } else {
                isHlineRow.append(false)
                var rowLayout: [LayoutNode] = []
                for cellNode in rowNode.children {
                    rowLayout.append(buildLayoutNode(cellNode, options: options))
                }
                grid.append(rowLayout)
            }
        }
        if grid.isEmpty { return SpaceNode(width: 0) }

        var maxCols = 0
        for (r, row) in grid.enumerated() where !isHlineRow[r] {
            maxCols = max(maxCols, row.count)
        }
        let specColChars = colSpec.filter { "lcr".contains($0) }
        if maxCols < specColChars.count {
            maxCols = specColChars.count
        }
        if maxCols == 0 {
            let metrics = FontMetrics.getMetrics(for: options.fontSize)
            let ruleT = metrics.defaultRuleThickness * options.fontSize
            var elements: [VerticalBox.Element] = []
            var y: CGFloat = 0
            for i in (0..<grid.count).reversed() {
                if isHlineRow[i] {
                    let rule = RuleNode(width: ruleT * 4, height: ruleT)
                    elements.append(VerticalBox.Element(node: HorizontalBox(children: [rule]), shift: y))
                    y += ruleT * 2
                }
            }
            let axisHeight = metrics.axisHeight * options.fontSize
            let centered = elements.map { VerticalBox.Element(node: $0.node, shift: $0.shift - y / 2 + axisHeight) }
            return VerticalBox(elements: centered, position: .individualShift)
        }

        var alignments: [Character] = []
        if envStem == "aligned" || envStem == "alignedat" {
            alignments = (0..<maxCols).map { $0 % 2 == 0 ? "r" : "l" }
        } else if envStem == "gathered" || envStem == "split" {
            alignments = Array(repeating: "c", count: maxCols)
        } else {
            for char in colSpec { if "lcr".contains(char) { alignments.append(char) } }
            while alignments.count < maxCols { alignments.append("c") }
        }

        var colWidths = [CGFloat](repeating: 0, count: maxCols)
        var rowHeights = [CGFloat](repeating: 0, count: grid.count)
        var rowDepths = [CGFloat](repeating: 0, count: grid.count)
        let metrics0 = FontMetrics.getMetrics(for: options.fontSize)
        let pt = 1.0 / metrics0.ptPerEm
        let arraycolsep = 5.0 * pt * options.fontSize
        let arrayskip = 1.0 * 12.0 * pt * options.fontSize
        let arstrutHeight = 0.7 * arrayskip
        let arstrutDepth = 0.3 * arrayskip
        let ruleThickness = metrics0.defaultRuleThickness * options.fontSize
        let hlinePad = 0.2 * arrayskip

        for (r, row) in grid.enumerated() {
            if isHlineRow[r] {
                rowHeights[r] = ruleThickness + hlinePad
                rowDepths[r] = hlinePad
                continue
            }
            for (c, cell) in row.enumerated() where c < maxCols {
                let box = cell.getBox(options: options)
                colWidths[c] = max(colWidths[c], box.width)
                rowHeights[r] = max(rowHeights[r], box.height)
                rowDepths[r] = max(rowDepths[r], box.depth)
            }
        }

        let tableBodyWidth = colWidths.reduce(0, +) + (maxCols > 1 ? CGFloat(maxCols - 1) * arraycolsep * 2 : 0)

        var tableRows: [VerticalBox.Element] = []
        var totalHeight: CGFloat = 0
        for r in (0..<grid.count).reversed() {
            if isHlineRow[r] {
                let rule = RuleNode(width: max(tableBodyWidth, ruleThickness), height: ruleThickness)
                let h = rowHeights[r]
                let d = rowDepths[r]
                tableRows.append(VerticalBox.Element(node: HorizontalBox(children: [rule]), shift: totalHeight))
                totalHeight += h + d
            } else {
                let h = max(rowHeights[r], arstrutHeight)
                let d = max(rowDepths[r], arstrutDepth)
                var rowCells: [LayoutNode] = []
                for c in 0..<maxCols {
                    if c > 0 { rowCells.append(SpaceNode(width: arraycolsep * 2)) }
                    let cell = c < grid[r].count ? grid[r][c] : SpaceNode(width: 0)
                    let box = cell.getBox(options: options)
                    let alignment = alignments[c]
                    let totalPadding = colWidths[c] - box.width
                    let leftPadding = (alignment == "l") ? 0 : (alignment == "r" ? totalPadding : totalPadding / 2)
                    let rightPadding = totalPadding - leftPadding
                    rowCells.append(
                        HorizontalBox(children: [SpaceNode(width: leftPadding), cell, SpaceNode(width: rightPadding)])
                    )
                }
                tableRows.append(VerticalBox.Element(node: HorizontalBox(children: rowCells), shift: totalHeight))
                totalHeight += h + d
            }
        }
        let metrics = FontMetrics.getMetrics(for: options.fontSize)
        let axisHeight = metrics.axisHeight * options.fontSize
        let centeredRows = tableRows.map {
            VerticalBox.Element(node: $0.node, shift: $0.shift - totalHeight / 2 + axisHeight)
        }
        return VerticalBox(elements: centeredRows, position: .individualShift)
    }

    private func buildHorizBraceNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        guard !node.children.isEmpty else { return SpaceNode(width: 0) }
        let body = buildLayoutNode(node.children[0], options: options)
        let bodyBox = body.getBox(options: options)
        // Parser stores command name without the leading backslash.
        let isOver = node.value == "overbrace" || node.value == "\\overbrace"

        // `src/functions/horizBrace.js` + `stretchy.js` + `svgGeometry.js`
        let brace = BraceNode(
            isOver: isOver,
            targetWidth: bodyBox.width,
            fontSize: options.fontSize,
            mathFont: options.mathFont
        )
        let braceBox = brace.getBox(options: options)
        // Reference `horizBrace.js`: kern 0.1em between body and brace
        let kern = options.fontSize * 0.1

        var elements: [VerticalBox.Element] = []
        if isOver {
            // Body on baseline; brace sits above with small gap
            elements.append(VerticalBox.Element(node: body, shift: 0))
            elements.append(VerticalBox.Element(node: brace, shift: bodyBox.height + kern + braceBox.depth))
        } else {
            // Underbrace: draw **body first**, then brace. Filled glyph paths are opaque; if the brace
            // is added first, math ink covers its upper curves and only a horizontal bar reads (bug).
            // Same shifts as reference `horizBrace.js` vlist; only paint order differs for path compositing.
            elements.append(VerticalBox.Element(node: body, shift: 0))
            elements.append(
                VerticalBox.Element(
                    node: brace,
                    shift: -bodyBox.depth - kern - braceBox.height
                )
            )
        }

        return VerticalBox(elements: elements, position: .individualShift, type: .mord)
    }

    private func buildSupSubNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        guard !node.children.isEmpty else { return SymbolNode(character: "?", fontSize: options.fontSize) }
        let base = buildLayoutNode(node.children[0], options: options), baseBox = base.getBox(options: options)
        var supm: LayoutNode?, subm: LayoutNode?, supOptions: FormulaKit.Options?, subOptions: FormulaKit.Options?
        for i in 1..<node.children.count {
            let scriptNode = node.children[i]
            if scriptNode.value == "sup" {
                let opts = options.withStyle(options.style.sup()); supOptions = opts;
                supm = buildLayoutNode(scriptNode.children.first ?? ParseNode(type: .symbol, value: "?"), options: opts)
            } else {
                let opts = options.withStyle(options.style.sub()); subOptions = opts;
                subm = buildLayoutNode(scriptNode.children.first ?? ParseNode(type: .symbol, value: "?"), options: opts)
            }
        }

        let isLargeOp =
            base.type == .mop
            && (node.children[0].type == .symbol && RendererSymbolSets.largeOperators.contains(node.children[0].value))
        let isLimitsOp =
            base.type == .mop
            && (node.children[0].type == .symbol && RendererSymbolSets.limitsOperators.contains(node.children[0].value))
        let isHorizBrace = node.children[0].type == .horizBrace

        if (isLargeOp || isLimitsOp || isHorizBrace) && options.style == .display {
            // Reference HTML renderer: `.mover` / `.munder` use centered rows. The outer width is
            // max(base, sup, sub); each row is centered when narrower (fixes `\underbrace` with a
            // long subscript: the braced math must sit centered over the label, not left-aligned).
            var totalWidth = baseBox.width
            if let supm = supm, let supOpts = supOptions {
                totalWidth = max(totalWidth, supm.getBox(options: supOpts).width)
            }
            if let subm = subm, let subOpts = subOptions {
                totalWidth = max(totalWidth, subm.getBox(options: subOpts).width)
            }
            func hPadCenter(_ node: LayoutNode, _ innerWidth: CGFloat) -> LayoutNode {
                let pad = max(0, (totalWidth - innerWidth) / 2)
                guard pad > 0 else { return node }
                return HorizontalBox(children: [SpaceNode(width: pad), node, SpaceNode(width: pad)])
            }

            var elements: [VerticalBox.Element] = [
                VerticalBox.Element(node: hPadCenter(base, baseBox.width), shift: 0)
            ]
            let metrics = FontMetrics.getMetrics(for: options.fontSize)
            if let supm = supm, let supOpts = supOptions {
                let supBox = supm.getBox(options: supOpts)
                // Reference layout: kern 0.2em between brace and sup/sub stack
                let shift =
                    isHorizBrace
                    ? 0.2 * options.fontSize
                    : max(
                        metrics.bigOpSpacing1 * options.fontSize,
                        metrics.bigOpSpacing3 * options.fontSize - supBox.depth
                    )
                elements.append(
                    VerticalBox.Element(
                        node: hPadCenter(supm, supBox.width),
                        shift: baseBox.height + shift + supBox.depth
                    )
                )
            }
            if let subm = subm, let subOpts = subOptions {
                let subBox = subm.getBox(options: subOpts)
                let shift =
                    isHorizBrace
                    ? 0.2 * options.fontSize
                    : max(
                        metrics.bigOpSpacing2 * options.fontSize,
                        metrics.bigOpSpacing4 * options.fontSize - subBox.height
                    )
                elements.append(
                    VerticalBox.Element(
                        node: hPadCenter(subm, subBox.width),
                        shift: -(baseBox.depth + shift + subBox.height)
                    )
                )
            }
            return VerticalBox(elements: elements, position: .individualShift, type: isHorizBrace ? .mord : .mop)
        }

        let metrics = FontMetrics.getMetrics(for: options.fontSize); var supShift: CGFloat = 0, subShift: CGFloat = 0;
        let isChar = (node.children[0].type == .symbol || node.children[0].type == .number)
        if let _ = supm, let opts = supOptions {
            if !isChar {
                supShift = baseBox.height - FontMetrics.getMetrics(for: opts.fontSize).supDrop * opts.fontSize
            }
        }
        if let _ = subm, let opts = subOptions {
            if !isChar { subShift = baseBox.depth + FontMetrics.getMetrics(for: opts.fontSize).subDrop * opts.fontSize }
        }
        var minSup: CGFloat;
        if options.style == .display {
            minSup = metrics.sup1 * options.fontSize
        } else if options.style.isCramped {
            minSup = metrics.sup3 * options.fontSize
        } else {
            minSup = metrics.sup2 * options.fontSize
        }
        let scriptSpace = (0.5 / metrics.ptPerEm) * options.fontSize
        // `Box.italicCorrection` from Core Text is `max(0, inkMaxX - advance)`. Some math faces report
        // much larger ink past the advance than reference font metrics tables, so the TeX-style subscript
        // kern `-italic` would pull the subscript into the base (e.g. `f_t`). Cap in **em** (``MathFontProviding/layout``).
        // keeps layout usable while leaving full `baseBox.italicCorrection` on ``ScriptSpaceTrailingNode`` for the following atom.
        let scriptItalicKern = min(
            baseBox.italicCorrection,
            options.resolvedMathFont.layout.scriptItalicCorrectionCapEm * options.fontSize
        )
        let subscriptExtraGap = options.resolvedMathFont.layout.subscriptExtraGapEm * options.fontSize
        var supsub: LayoutNode
        if let supm = supm, let subm = subm {
            let supBox = supm.getBox(options: supOptions!)
            let subBox = subm.getBox(options: subOptions!)
            supShift = max(supShift, minSup, supBox.depth + 0.25 * metrics.xHeight * options.fontSize)
            subShift = max(subShift, metrics.sub2 * options.fontSize);
            let ruleWidth = metrics.defaultRuleThickness * options.fontSize, maxWidth = 4 * ruleWidth,
                supBottom = supShift - supBox.depth, subTop = subBox.height - subShift
            if supBottom - subTop < maxWidth {
                subShift = maxWidth - supBottom + subBox.height;
                let psi = 0.8 * metrics.xHeight * options.fontSize - supBottom;
                if psi > 0 { supShift += psi; subShift -= psi }
            }
            let italic = scriptItalicKern; let shiftedSup = HorizontalBox(children: [SpaceNode(width: italic), supm]);
            var subChildren: [LayoutNode] = [];
            if isChar && italic > 0 { subChildren.append(SpaceNode(width: -italic)) };
            subChildren.append(SpaceNode(width: subscriptExtraGap)); subChildren.append(subm)
            supsub = VerticalBox(
                elements: [
                    VerticalBox.Element(node: HorizontalBox(children: subChildren), shift: -subShift),
                    VerticalBox.Element(node: shiftedSup, shift: supShift),
                ],
                position: .individualShift
            )
        } else if let subm = subm {
            let subBox = subm.getBox(options: subOptions!);
            subShift = max(
                subShift,
                metrics.sub1 * options.fontSize,
                subBox.height - 0.8 * metrics.xHeight * options.fontSize
            ); let italic = scriptItalicKern; var subChildren: [LayoutNode] = [];
            if isChar && italic > 0 { subChildren.append(SpaceNode(width: -italic)) };
            subChildren.append(SpaceNode(width: subscriptExtraGap)); subChildren.append(subm);
            supsub = VerticalBox(
                elements: [VerticalBox.Element(node: HorizontalBox(children: subChildren), shift: 0)],
                position: .shift(subShift)
            )
        } else if let supm = supm {
            let supBox = supm.getBox(options: supOptions!);
            supShift = max(supShift, minSup, supBox.depth + 0.25 * metrics.xHeight * options.fontSize);
            let italic = scriptItalicKern; let shiftedSup = HorizontalBox(children: [SpaceNode(width: italic), supm]);
            supsub = VerticalBox(
                elements: [VerticalBox.Element(node: shiftedSup, shift: 0)],
                position: .shift(-supShift)
            )
        } else {
            return base
        }
        let trail = ScriptSpaceTrailingNode(width: scriptSpace, italicCorrection: baseBox.italicCorrection)
        return HorizontalBox(children: [base, supsub, trail])
    }

    private func buildFractionNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        guard node.children.count >= 2 else { return SymbolNode(character: "\\frac{?}{?}") }
        let numOpts = options.withStyle(options.style.fracNum()),
            denOpts = options.withStyle(options.style.fracDenom()),
            numerator = buildLayoutNode(node.children[0], options: numOpts),
            denominator = buildLayoutNode(node.children[1], options: denOpts),
            numBox = numerator.getBox(options: numOpts), denBox = denominator.getBox(options: denOpts),
            metrics = FontMetrics.getMetrics(for: options.fontSize),
            rule = metrics.defaultRuleThickness * options.fontSize, axis = metrics.axisHeight * options.fontSize
        let displayFrac = options.style == .display || node.value == "dfrac"
        var ns: CGFloat, ds: CGFloat, cl: CGFloat;
        if displayFrac {
            ns = metrics.num1 * options.fontSize; ds = metrics.denom1 * options.fontSize; cl = 3 * rule
        } else {
            ns = metrics.num2 * options.fontSize; ds = metrics.denom2 * options.fontSize; cl = rule
        }
        let nb = ns - numBox.depth, nc = nb - (axis + 0.5 * rule); if nc < cl { ns += (cl - nc) }
        let dt = denBox.height - ds, dc = (axis - 0.5 * rule) - dt; if dc < cl { ds += (cl - dc) }
        let rw = max(numBox.width, denBox.width) + (options.fontSize * 0.1), no = (rw - numBox.width) / 2,
            dof = (rw - denBox.width) / 2
        return VerticalBox(
            elements: [
                VerticalBox.Element(node: HorizontalBox(children: [SpaceNode(width: dof), denominator]), shift: -ds),
                VerticalBox.Element(node: RuleNode(width: rw, height: rule), shift: axis - 0.5 * rule),
                VerticalBox.Element(node: HorizontalBox(children: [SpaceNode(width: no), numerator]), shift: ns),
            ],
            position: .individualShift
        )
    }

    private func buildSqrtNode(_ node: ParseNode, options: FormulaKit.Options) -> LayoutNode {
        guard !node.children.isEmpty else { return SymbolNode(character: "√") }
        let
            innerOpts =
                options.style == .display
                ? options.withStyle(.textCramped) : options.withStyle(options.style.cramped()),
            content = buildLayoutNode(node.children.last!, options: innerOpts),
            contentBox = content.getBox(options: innerOpts), metrics = FontMetrics.getMetrics(for: options.fontSize),
            rule = metrics.sqrtRuleThickness * options.fontSize
        let font: String
        let th = contentBox.totalHeight
        if th > options.fontSize * 1.5 {
            font = MathLogicalFontNames.size4Regular
        } else if th > options.fontSize * 1.2 {
            font = MathLogicalFontNames.size2Regular
        } else if th > options.fontSize * 1.0 {
            font = MathLogicalFontNames.size1Regular
        } else {
            font = MathLogicalFontNames.mainRegular
        }
        let radical = SymbolNode(character: "√", type: .mord, fontName: font, fontSize: options.fontSize),
            radicalBox = radical.getBox(options: options), theta = rule
        ; var phi = theta; if options.style == .display { phi = metrics.xHeight * options.fontSize }
        var cl = theta + phi / 4.0; let dd = radicalBox.height - rule;
        if dd > contentBox.totalHeight + cl { cl = (cl + dd - contentBox.totalHeight) / 2.0 }
        let ishift = radicalBox.height - contentBox.height - cl - rule,
            overline = RuleNode(width: contentBox.width, height: rule), oshift = contentBox.height + cl
        return HorizontalBox(children: [
            VerticalBox(elements: [VerticalBox.Element(node: radical, shift: -ishift)], position: .individualShift),
            VerticalBox(
                elements: [
                    VerticalBox.Element(node: content, shift: 0), VerticalBox.Element(node: overline, shift: oshift),
                ],
                position: .individualShift
            ),
        ])
    }
}

/// TeX `\scriptspace` after super/subscripts. A plain ``SpaceNode`` would make the parent
/// ``HorizontalBox`` inherit zero ``Box/italicCorrection``, so the nucleus correction is lost
/// before the next atom (e.g. `f_t \to`).
private struct ScriptSpaceTrailingNode: LayoutNode {
    let width: CGFloat
    let italicCorrection: CGFloat
    var type: AtomType { .mord }

    func getBox(options: FormulaKit.Options) -> Box {
        Box(width: width, height: 0, depth: 0, italicCorrection: italicCorrection)
    }

    func renderDecoration(at origin: CGPoint, options: FormulaKit.Options) -> CGPath {
        CGMutablePath()
    }
}
