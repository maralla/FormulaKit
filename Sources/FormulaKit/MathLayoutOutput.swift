import Foundation

// MARK: - Vector Path

/// 2D vector path for rules and decorations.
public struct MathPath: Sendable, Equatable {
    public enum Element: Sendable, Equatable {
        case moveTo(CGPoint)
        case lineTo(CGPoint)
        case quadTo(CGPoint, CGPoint)
        case closeSubpath
    }

    public var elements: [Element]

    public init(elements: [Element] = []) {
        self.elements = elements
    }

    public init(rect: CGRect) {
        self.elements = [
            .moveTo(CGPoint(x: rect.minX, y: rect.minY)),
            .lineTo(CGPoint(x: rect.maxX, y: rect.minY)),
            .lineTo(CGPoint(x: rect.maxX, y: rect.maxY)),
            .lineTo(CGPoint(x: rect.minX, y: rect.maxY)),
            .closeSubpath,
        ]
    }

    public mutating func move(to p: CGPoint) {
        elements.append(.moveTo(p))
    }

    public mutating func addLine(to p: CGPoint) {
        elements.append(.lineTo(p))
    }

    public mutating func addQuadCurve(to p: CGPoint, control c: CGPoint) {
        elements.append(.quadTo(c, p))
    }

    public mutating func closeSubpath() {
        elements.append(.closeSubpath)
    }

    public mutating func addPath(_ other: MathPath) {
        elements.append(contentsOf: other.elements)
    }

    public var boundingBox: CGRect {
        boundingBoxOfPath
    }

    public var boundingBoxOfPath: CGRect {
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity
        var hasPoint = false
        var curr = CGPoint.zero

        func include(_ p: CGPoint) {
            hasPoint = true
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }

        for el in elements {
            switch el {
            case .moveTo(let p), .lineTo(let p):
                include(p)
                curr = p
            case .quadTo(let c, let p):
                include(p)
                let dx = curr.x - 2 * c.x + p.x
                if abs(dx) > 1e-9 {
                    let tx = (curr.x - c.x) / dx
                    if tx > 0 && tx < 1 {
                        let u = 1 - tx
                        let x = u * u * curr.x + 2 * u * tx * c.x + tx * tx * p.x
                        minX = min(minX, x)
                        maxX = max(maxX, x)
                    }
                }
                let dy = curr.y - 2 * c.y + p.y
                if abs(dy) > 1e-9 {
                    let ty = (curr.y - c.y) / dy
                    if ty > 0 && ty < 1 {
                        let u = 1 - ty
                        let y = u * u * curr.y + 2 * u * ty * c.y + ty * ty * p.y
                        minY = min(minY, y)
                        maxY = max(maxY, y)
                    }
                }
                curr = p
            case .closeSubpath:
                break
            }
        }
        return hasPoint ? CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY) : .zero
    }
}

// MARK: - Font metrics

/// TeX font metrics and related constants.
public struct FontMetrics {
    /// Font metrics parameters from TeX (sigmas and xis).
    public struct MetricsSet: Sendable {
        public let slant: CGFloat
        public let space: CGFloat
        public let stretch: CGFloat
        public let shrink: CGFloat
        public let xHeight: CGFloat
        public let quad: CGFloat
        public let extraSpace: CGFloat
        public let num1: CGFloat
        public let num2: CGFloat
        public let num3: CGFloat
        public let denom1: CGFloat
        public let denom2: CGFloat
        public let sup1: CGFloat
        public let sup2: CGFloat
        public let sup3: CGFloat
        public let sub1: CGFloat
        public let sub2: CGFloat
        public let supDrop: CGFloat
        public let subDrop: CGFloat
        public let delim1: CGFloat
        public let delim2: CGFloat
        public let axisHeight: CGFloat
        public let defaultRuleThickness: CGFloat
        public let bigOpSpacing1: CGFloat
        public let bigOpSpacing2: CGFloat
        public let bigOpSpacing3: CGFloat
        public let bigOpSpacing4: CGFloat
        public let bigOpSpacing5: CGFloat
        public let sqrtRuleThickness: CGFloat
        public let ptPerEm: CGFloat
        public let doubleRuleSep: CGFloat

        public var cssEmPerMu: CGFloat { quad / 18.0 }
    }

    /// Metrics for textstyle (sizeIndex 0)
    public static let textstyle = MetricsSet(
        slant: 0.250,
        space: 0.000,
        stretch: 0.000,
        shrink: 0.000,
        xHeight: 0.431,
        quad: 1.000,
        extraSpace: 0.000,
        num1: 0.677,
        num2: 0.394,
        num3: 0.444,
        denom1: 0.686,
        denom2: 0.345,
        sup1: 0.413,
        sup2: 0.363,
        sup3: 0.289,
        sub1: 0.150,
        sub2: 0.247,
        supDrop: 0.386,
        subDrop: 0.050,
        delim1: 2.390,
        delim2: 1.010,
        axisHeight: 0.250,
        defaultRuleThickness: 0.04,
        bigOpSpacing1: 0.111,
        bigOpSpacing2: 0.166,
        bigOpSpacing3: 0.2,
        bigOpSpacing4: 0.6,
        bigOpSpacing5: 0.1,
        sqrtRuleThickness: 0.04,
        ptPerEm: 10.0,
        doubleRuleSep: 0.2
    )

    /// Metrics for scriptstyle (sizeIndex 1)
    public static let scriptstyle = MetricsSet(
        slant: 0.250,
        space: 0.000,
        stretch: 0.000,
        shrink: 0.000,
        xHeight: 0.431,
        quad: 1.171,
        extraSpace: 0.000,
        num1: 0.732,
        num2: 0.384,
        num3: 0.471,
        denom1: 0.752,
        denom2: 0.344,
        sup1: 0.503,
        sup2: 0.431,
        sup3: 0.286,
        sub1: 0.143,
        sub2: 0.286,
        supDrop: 0.353,
        subDrop: 0.071,
        delim1: 1.700,
        delim2: 1.157,
        axisHeight: 0.250,
        defaultRuleThickness: 0.049,
        bigOpSpacing1: 0.111,
        bigOpSpacing2: 0.166,
        bigOpSpacing3: 0.2,
        bigOpSpacing4: 0.611,
        bigOpSpacing5: 0.143,
        sqrtRuleThickness: 0.04,
        ptPerEm: 10.0,
        doubleRuleSep: 0.2
    )

    /// Metrics for scriptscriptstyle (sizeIndex 2)
    public static let scriptscriptstyle = MetricsSet(
        slant: 0.250,
        space: 0.000,
        stretch: 0.000,
        shrink: 0.000,
        xHeight: 0.431,
        quad: 1.472,
        extraSpace: 0.000,
        num1: 0.925,
        num2: 0.387,
        num3: 0.504,
        denom1: 1.025,
        denom2: 0.532,
        sup1: 0.504,
        sup2: 0.404,
        sup3: 0.294,
        sub1: 0.200,
        sub2: 0.400,
        supDrop: 0.494,
        subDrop: 0.100,
        delim1: 1.980,
        delim2: 1.420,
        axisHeight: 0.250,
        defaultRuleThickness: 0.049,
        bigOpSpacing1: 0.111,
        bigOpSpacing2: 0.166,
        bigOpSpacing3: 0.2,
        bigOpSpacing4: 0.611,
        bigOpSpacing5: 0.143,
        sqrtRuleThickness: 0.04,
        ptPerEm: 10.0,
        doubleRuleSep: 0.2
    )

    /// Get appropriate font metrics for a given size.
    public static func getMetrics(for size: CGFloat) -> MetricsSet {
        if size >= 5.0 {
            return textstyle
        } else if size >= 3.0 {
            return scriptstyle
        } else {
            return scriptscriptstyle
        }
    }

    public static func getMetrics(for options: FormulaKit.Options) -> MetricsSet {
        getMetrics(for: options.fontSize)
    }
}

// MARK: - Math text runs & composite layout

/// One glyph span positioned in layout space (baseline origin, **math y-up**: positive y is above baseline).
public struct MathTextRun: Sendable, Equatable {
    public let string: String
    /// Logical font slot (see ``MathLogicalFontNames``); same as `SymbolNode.fontName`.
    public let fontName: String
    public let fontSize: CGFloat
    public let baselineOrigin: CGPoint
    /// When true, `\text{…}`-style metrics: prefer the text face over the math face.
    public let metricsTextMode: Bool
    /// OpenType math glyph name (e.g. ``parenleft.s5``); `nil` = cmap glyph for `string`.
    public let openTypeMathGlyphName: String?

    public init(
        string: String,
        fontName: String,
        fontSize: CGFloat,
        baselineOrigin: CGPoint,
        metricsTextMode: Bool = false,
        openTypeMathGlyphName: String? = nil
    ) {
        self.string = string
        self.fontName = fontName
        self.fontSize = fontSize
        self.baselineOrigin = baselineOrigin
        self.metricsTextMode = metricsTextMode
        self.openTypeMathGlyphName = openTypeMathGlyphName
    }
}

/// System-text + vector decorations, analogous to HTML math output (text spans + SVG/rules).
public struct MathCompositeRender: Sendable, Equatable {
    /// Rules, braces, and other non-glyph geometry. Empty if the expression is symbols only.
    public let decorationPath: MathPath
    public let textRuns: [MathTextRun]

    public init(decorationPath: MathPath, textRuns: [MathTextRun]) {
        self.decorationPath = decorationPath
        self.textRuns = textRuns
    }
}

/// Result of ``FormulaKit/render(_:options:)``: drawable content plus root layout metrics (`Box`).
public struct MathCompositeLayout {
    /// Rules, braces, and other non-glyph geometry.
    public let decorationPath: MathPath
    public let textRuns: [MathTextRun]
    /// Root layout box (width, height above baseline, depth below).
    public let rootBox: Box
    /// Per-render cache for glyph measurement and symbol boxes during layout.
    public let symbolRenderScratch: SymbolRenderScratch?
    /// Same ``FormulaKit/Options/mathFont`` used to build this layout.
    public let mathFont: MathFontIdentifier

    public init(
        decorationPath: MathPath,
        textRuns: [MathTextRun],
        rootBox: Box,
        symbolRenderScratch: SymbolRenderScratch? = nil,
        mathFont: MathFontIdentifier = .stix
    ) {
        self.decorationPath = decorationPath
        self.textRuns = textRuns
        self.rootBox = rootBox
        self.symbolRenderScratch = symbolRenderScratch
        self.mathFont = mathFont
    }

    /// Same path and runs as ``MathCompositeRender`` for APIs that expect that shape.
    public var composite: MathCompositeRender {
        MathCompositeRender(decorationPath: decorationPath, textRuns: textRuns)
    }
}
