import Foundation

/// Semantic role of a geometric rule (`RuleNode`) so each ``MathFontProviding`` backend can style
/// stroke thickness, end-caps, and curvature to match the typeface.
public enum MathRuleRole: Sendable, Equatable {
    case fractionBar
    case radicalVinculum
    case horizontalLine
}

/// Measured glyph metrics at a concrete point size (baseline at y = 0, y-up).
public struct MathGlyphMetrics: Sendable, Equatable {
    public let advanceWidth: CGFloat
    public let boundingBox: CGRect
    public let inkRight: CGFloat
    public let leftHang: CGFloat

    public init(advanceWidth: CGFloat, boundingBox: CGRect, inkRight: CGFloat, leftHang: CGFloat = 0) {
        self.advanceWidth = advanceWidth
        self.boundingBox = boundingBox
        self.inkRight = inkRight
        self.leftHang = leftHang
    }
}

/// Font measurement backend used to query glyph availability and outline metrics.
public protocol MathFontBackend: Sendable {
    func isFontAvailable(postScriptName: String, fontSize: CGFloat) -> Bool
    func hasGlyph(_ character: String, postScriptName: String, fontSize: CGFloat) -> Bool
    func hasOpenTypeGlyph(named glyphName: String, postScriptName: String, fontSize: CGFloat) -> Bool
    func measureGlyph(
        postScriptName: String,
        character: String,
        fontSize: CGFloat,
        openTypeGlyphName: String?,
        isCaligraphicCapital: Bool,
        inkSlackPt: CGFloat,
        isItalicSlot: Bool
    ) -> MathGlyphMetrics?
}

/// Per-font layout tuning used by ``Renderer`` and ``SymbolNode`` (em / mu as documented on each field).
public struct MathFontLayoutTuning: Sendable {
    public let subscriptExtraGapEm: CGFloat
    public let scriptItalicCorrectionCapEm: CGFloat
    public let mopRoundOpenParenHangShaveMu: CGFloat
    public let caligraphicCapitalDelimiterKernEm: CGFloat
    public let caligraphicScriptCapitalInkSlackEm: CGFloat
    public let fractionRuleThicknessEm: CGFloat
    public let radicalRuleThicknessEm: CGFloat
    public let radicalVinculumJoinKernEm: CGFloat

    public init(
        subscriptExtraGapEm: CGFloat,
        scriptItalicCorrectionCapEm: CGFloat,
        mopRoundOpenParenHangShaveMu: CGFloat,
        caligraphicCapitalDelimiterKernEm: CGFloat,
        caligraphicScriptCapitalInkSlackEm: CGFloat,
        fractionRuleThicknessEm: CGFloat = 0.068,
        radicalRuleThicknessEm: CGFloat = 0.068,
        radicalVinculumJoinKernEm: CGFloat = -0.020
    ) {
        self.subscriptExtraGapEm = subscriptExtraGapEm
        self.scriptItalicCorrectionCapEm = scriptItalicCorrectionCapEm
        self.mopRoundOpenParenHangShaveMu = mopRoundOpenParenHangShaveMu
        self.caligraphicCapitalDelimiterKernEm = caligraphicCapitalDelimiterKernEm
        self.caligraphicScriptCapitalInkSlackEm = caligraphicScriptCapitalInkSlackEm
        self.fractionRuleThicknessEm = fractionRuleThicknessEm
        self.radicalRuleThicknessEm = radicalRuleThicknessEm
        self.radicalVinculumJoinKernEm = radicalVinculumJoinKernEm
    }
}

/// Tunables for stretchy / enclosing delimiters: `\left`/`\right`, `\big`…`\Bigg`, `\bigl`/`\bigr`/`\bigm`, etc.
public struct DelimiterSizing: Sendable {
    public let requiredHeightSlackEm: CGFloat
    public let requiredHeightSlackMinPt: CGFloat
    public let leftRightMaxExtraScale: CGFloat
    public let leftRightTargetHeightMultiple: CGFloat
    public let bigDelimiterMaxExtraScale: CGFloat
    public let bigDelimiterMinHeightMultiples: [String: CGFloat]

    public init(
        requiredHeightSlackEm: CGFloat,
        requiredHeightSlackMinPt: CGFloat,
        leftRightMaxExtraScale: CGFloat,
        leftRightTargetHeightMultiple: CGFloat = 1.0,
        bigDelimiterMaxExtraScale: CGFloat,
        bigDelimiterMinHeightMultiples: [String: CGFloat]
    ) {
        self.requiredHeightSlackEm = requiredHeightSlackEm
        self.requiredHeightSlackMinPt = requiredHeightSlackMinPt
        self.leftRightMaxExtraScale = leftRightMaxExtraScale
        self.leftRightTargetHeightMultiple = leftRightTargetHeightMultiple
        self.bigDelimiterMaxExtraScale = bigDelimiterMaxExtraScale
        self.bigDelimiterMinHeightMultiples = bigDelimiterMinHeightMultiples
    }
}

/// One concrete math font implementation.
public protocol MathFontProviding: Sendable {
    var identifier: MathFontIdentifier { get }
    var layout: MathFontLayoutTuning { get }
    var delimiterSizing: DelimiterSizing { get }

    /// Resolves the PostScript font name for a logical font slot and character.
    func resolvedPostScriptFontName(logicalFontName: String, character: String, textMode: Bool, fontSize: CGFloat) -> String

    /// Whether the primary math face is installed.
    func isPrimaryMathFontAvailable(forFontSize: CGFloat) -> Bool

    /// PostScript name of the main math face.
    var primaryMathPostScriptName: String { get }

    /// Hint shown when ``isPrimaryMathFontAvailable(forFontSize:)`` is false.
    var supplementalFontsDirectoryHint: String { get }

    // MARK: - Letter remapping

    func mathcalMappedLetter(_ character: Character) -> String?
    func isCaligraphicScriptCapital(character: String, logicalFontName: String) -> Bool
    func mathbbMappedLetter(_ character: Character) -> String?

    // MARK: - OpenType math delimiter & glyph variants

    func openTypeMathStretchDelimiterGlyphNames(for character: String) -> [String]
    func openTypeMatchingStretchDelimiterGlyphName(character: String, templateGlyphName: String?) -> String?
    func openTypeGlyphName(logicalFontName: String, character: String, textMode: Bool) -> String?

    // MARK: - Horizontal ``\overbrace`` / ``\underbrace`` & Rules

    func horizontalBraceLayout(
        isOver: Bool,
        layoutWidth: CGFloat,
        bodyFontSize: CGFloat,
        mathFont: MathFontIdentifier
    ) -> MathFontHorizontalBraceLayout

    func renderRulePath(
        rect: CGRect,
        role: MathRuleRole,
        options: FormulaKit.Options
    ) -> MathPath
}

/// What ``BraceNode`` needs to emit a text run; backends hide glyph names and Unicode choices behind this.
public struct MathFontHorizontalBraceLayout: Sendable, Equatable {
    public let drawString: String
    public let logicalFontName: String
    public let pointSize: CGFloat
    public let coreTextGlyphName: String?
    public let layoutWidth: CGFloat
    public let height: CGFloat
    public let depth: CGFloat
    public let textOriginOffsetX: CGFloat

    public init(
        drawString: String,
        logicalFontName: String,
        pointSize: CGFloat,
        coreTextGlyphName: String?,
        layoutWidth: CGFloat,
        height: CGFloat,
        depth: CGFloat,
        textOriginOffsetX: CGFloat
    ) {
        self.drawString = drawString
        self.logicalFontName = logicalFontName
        self.pointSize = pointSize
        self.coreTextGlyphName = coreTextGlyphName
        self.layoutWidth = layoutWidth
        self.height = height
        self.depth = depth
        self.textOriginOffsetX = textOriginOffsetX
    }
}

// MARK: - Default hooks

extension MathFontProviding {
    public func mathcalMappedLetter(_: Character) -> String? { nil }
    public func isCaligraphicScriptCapital(character _: String, logicalFontName _: String) -> Bool { false }
    public func mathbbMappedLetter(_: Character) -> String? { nil }
    public func openTypeMathStretchDelimiterGlyphNames(for _: String) -> [String] { [] }
    public func openTypeMatchingStretchDelimiterGlyphName(character _: String, templateGlyphName _: String?) -> String? {
        nil
    }
    public func openTypeGlyphName(logicalFontName _: String, character _: String, textMode _: Bool) -> String? { nil }
    public func renderRulePath(rect: CGRect, role _: MathRuleRole, options _: FormulaKit.Options) -> MathPath {
        MathPath(rect: rect)
    }
}
