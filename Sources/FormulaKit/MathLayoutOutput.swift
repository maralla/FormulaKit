import CoreGraphics
import CoreText
import Foundation

#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit

private func linePlatformFont(from ctFont: CTFont) -> NSFont {
    ctFont as NSFont
}
#elseif canImport(UIKit)
import UIKit

private func linePlatformFont(from ctFont: CTFont) -> UIFont {
    ctFont as UIFont
}
#endif

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

        /// Reference `options.fontMetrics().cssEmPerMu` — `quad / 18` (see `fontMetrics.js`).
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
    /// Matches reference `getGlobalMetrics` / `fontMetrics.js` sizeIndex rules on **current** `fontSize` (pt).
    public static func getMetrics(for size: CGFloat) -> MetricsSet {
        if size >= 5.0 {
            return textstyle
        } else if size >= 3.0 {
            return scriptstyle
        } else {
            return scriptscriptstyle
        }
    }

    /// Reference `options.fontMetrics()` for a given style’s **current** font size (after `withStyle` scaling).
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
    /// When true, `\text{…}`-style metrics: prefer the text face over the math face on macOS (see ``MathFont``).
    public let metricsTextMode: Bool
    /// STIX Two Math OpenType math delimiter master (e.g. ``parenleft.s5``) via ``CTGlyphInfo``; `nil` = cmap glyph for `string`.
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
public struct MathCompositeRender {
    /// Rules, braces, and other non-glyph geometry. Empty if the expression is symbols only.
    public let decorationPath: CGPath
    public let textRuns: [MathTextRun]

    public init(decorationPath: CGPath, textRuns: [MathTextRun]) {
        self.decorationPath = decorationPath
        self.textRuns = textRuns
    }
}

/// Result of ``FormulaKit/render(_:options:)``: drawable content plus root layout metrics (`Box`).
public struct MathCompositeLayout {
    /// Rules, braces, and other non-glyph geometry.
    public let decorationPath: CGPath
    public let textRuns: [MathTextRun]
    /// Root layout box (width, height above baseline, depth below).
    public let rootBox: Box
    /// Per-render cache for glyph measurement and symbol boxes during layout. Not needed when resolving ``CTFont`` for drawing (see ``SymbolNode/ctFontForMathGlyph(fontName:character:fontSize:metricsTextMode:mathFont:)``).
    public let symbolRenderScratch: SymbolRenderScratch?

    /// Same ``FormulaKit/Options/mathFont`` used to build this layout; required when resolving ``CTFont`` for ``textRuns``.
    public let mathFont: MathFontIdentifier

    public init(
        decorationPath: CGPath,
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

    /// Fills ``decorationPath`` then draws ``textRuns`` with Core Text.
    ///
    /// **Coordinate system:** math layout space (y up), same as ``textRuns`` / ``rootBox`` — set the context
    /// transform (centering, scaling) before calling.
    #if os(macOS) && !targetEnvironment(macCatalyst)
    public func drawMath(in cgContext: CGContext, textColor: NSColor = .black) {
        drawMathImpl(in: cgContext, textCGColor: textColor.cgColor)
    }
    #elseif canImport(UIKit)
    public func drawMath(in cgContext: CGContext, textColor: UIColor = .black) {
        drawMathImpl(in: cgContext, textCGColor: textColor.cgColor)
    }
    #endif

    private func drawMathImpl(in cgContext: CGContext, textCGColor: CGColor) {
        cgContext.saveGState()
        defer { cgContext.restoreGState() }

        cgContext.setFillColor(textCGColor)
        cgContext.addPath(decorationPath)
        cgContext.fillPath()

        for run in textRuns {
            let ctFont = SymbolNode.ctFontForMathGlyph(
                fontName: run.fontName,
                character: run.string,
                fontSize: run.fontSize,
                metricsTextMode: run.metricsTextMode,
                mathFont: mathFont
            )
            var attrs: [NSAttributedString.Key: Any] = [
                .font: linePlatformFont(from: ctFont),
                kCTForegroundColorAttributeName as NSAttributedString.Key: textCGColor,
            ]
            if let gn = run.openTypeMathGlyphName,
                let glyphInfo = CTGlyphInfoCreateWithGlyphName(gn as CFString, ctFont, run.string as CFString)
            {
                attrs[kCTGlyphInfoAttributeName as NSAttributedString.Key] = glyphInfo
            }
            let line = CTLineCreateWithAttributedString(
                NSAttributedString(string: run.string, attributes: attrs) as CFAttributedString
            )
            cgContext.textPosition = CGPoint(x: run.baselineOrigin.x, y: run.baselineOrigin.y)
            CTLineDraw(line, cgContext)
        }
    }
}
