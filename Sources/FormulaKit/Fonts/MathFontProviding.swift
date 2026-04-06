import CoreGraphics
import CoreText
import Foundation

/// Per-font layout tuning used by ``Renderer`` and ``SymbolNode`` (em / mu as documented on each field).
public struct MathFontLayoutTuning: Sendable {
    /// Positive kern (in **em**) between nucleus (after optional `-italic` shift) and subscript.
    public let subscriptExtraGapEm: CGFloat
    /// Cap on italic correction used for script positioning.
    public let scriptItalicCorrectionCapEm: CGFloat
    /// Shave from delimiter LSB hang after `.mop` before a round `(` (in **mu**).
    public let mopRoundOpenParenHangShaveMu: CGFloat
    /// Minimum kern before delimiters after `\mathcal` capitals (as **em** of font size).
    public let caligraphicCapitalDelimiterKernEm: CGFloat
    /// Extra right-ink margin for script capitals (as **em** of font size).
    public let caligraphicScriptCapitalInkSlackEm: CGFloat

    public init(
        subscriptExtraGapEm: CGFloat,
        scriptItalicCorrectionCapEm: CGFloat,
        mopRoundOpenParenHangShaveMu: CGFloat,
        caligraphicCapitalDelimiterKernEm: CGFloat,
        caligraphicScriptCapitalInkSlackEm: CGFloat
    ) {
        self.subscriptExtraGapEm = subscriptExtraGapEm
        self.scriptItalicCorrectionCapEm = scriptItalicCorrectionCapEm
        self.mopRoundOpenParenHangShaveMu = mopRoundOpenParenHangShaveMu
        self.caligraphicCapitalDelimiterKernEm = caligraphicCapitalDelimiterKernEm
        self.caligraphicScriptCapitalInkSlackEm = caligraphicScriptCapitalInkSlackEm
    }
}

/// Tunables for stretchy / enclosing delimiters: `\left`/`\right`, `\big`…`\Bigg`, `\bigl`/`\bigr`/`\bigm`, etc.
/// Values are **font-specific** (define them on each ``MathFontProviding`` implementation, e.g. ``STIXMathFontProvider``).
///
/// `\left`/`\right` should prefer **stepping** Main → Size4 at body ``fontSize`` (designed masters) instead of only
/// inflating ``CTFont`` point size, which thickens strokes and looks heavy next to text.
public struct DelimiterSizing: Sendable {
    /// Added to required delimiter span for `\left`/`\right` (as **em** of body size).
    public let requiredHeightSlackEm: CGFloat
    /// Minimum slack in points (with em slack).
    public let requiredHeightSlackMinPt: CGFloat
    /// After Size4 at unit scale, at most this extra scale if ink is still short (keeps strokes closer to text weight).
    public let leftRightMaxExtraScale: CGFloat
    /// Multiply ``(totalExtent + slack)`` before choosing scale (≥1). Use >1 when path metrics sit inside painted ink.
    public let leftRightTargetHeightMultiple: CGFloat
    /// Max scale when nudging `\big*` delimiters toward a target height.
    public let bigDelimiterMaxExtraScale: CGFloat
    /// For `\big` / `\Big` / `\bigg` / `\Bigg`: target minimum ``Box/totalHeight`` (× body ``fontSize``). Keys match parser tokens.
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

/// One concrete math font implementation (system STIX, bundled web fonts, custom OpenType math, …).
public protocol MathFontProviding: Sendable {
    var identifier: MathFontIdentifier { get }
    var layout: MathFontLayoutTuning { get }
    /// Delimiter slack, tier / scale caps, and `\big*` targets for this typeface.
    var delimiterSizing: DelimiterSizing { get }

    func ctFont(logicalFontName: String, character: String, textMode: Bool, fontSize: CGFloat) -> CTFont

    /// Whether the primary math face is installed (diagnostics / MathImage).
    func isPrimaryMathFontAvailable(forFontSize: CGFloat) -> Bool

    /// PostScript name of the main math face (tests, logging).
    var primaryMathPostScriptName: String { get }

    /// Hint shown when ``isPrimaryMathFontAvailable(forFontSize:)`` is false.
    var supplementalFontsDirectoryHint: String { get }

    // MARK: - Letter remapping (encoding differs by font backend)

    /// Maps one letter inside ``\mathcal{…}``.
    ///
    /// Non-`nil`: use this string as the symbol (e.g. Unicode mathematical script). `nil`: keep the parsed letter and logical
    /// ``Caligraphic-Regular`` slot (only useful with a font that remaps cmap; the built-in STIX provider returns Unicode).
    func mathcalMappedLetter(_ character: Character) -> String?

    /// Script capitals that need extra delimiter kern / ink slack (see ``MathFontLayoutTuning``).
    func isCaligraphicScriptCapital(character: String, logicalFontName: String) -> Bool

    /// Maps one letter inside ``\mathbb{…}``.
    ///
    /// Non-`nil`: use this string (e.g. Unicode double-struck). `nil`: keep ASCII and the logical ``AMS-Regular`` slot.
    func mathbbMappedLetter(_ character: Character) -> String?

    // MARK: - OpenType math delimiter variants (STIX Two Math ``.s1``…``.s12`` masters)

    /// PostScript glyph names for **increasing** delimiter sizes at fixed point size (OpenType math ``.s*`` masters).
    ///
    /// Example for ``(``: ``parenleft``, ``parenleft.s1``, … ``parenleft.s12``. Empty → ``Renderer`` uses Size-slot / scaling fallback.
    func openTypeMathStretchDelimiterGlyphNames(for character: String) -> [String]

    /// Same OpenType math **size step** as ``templateGlyphName`` (e.g. ``parenleft.s5`` → ``parenright.s5`` for ``)``).
    func openTypeMatchingStretchDelimiterGlyphName(character: String, templateGlyphName: String?) -> String?

    // MARK: - Horizontal ``\overbrace`` / ``\underbrace``

    /// How this backend draws a horizontal brace for the given span. **Required** — every registered provider must implement it (no default).
    func horizontalBraceLayout(
        isOver: Bool,
        layoutWidth: CGFloat,
        bodyFontSize: CGFloat,
        mathFont: MathFontIdentifier
    ) -> MathFontHorizontalBraceLayout
}

/// What ``BraceNode`` needs to emit a Core Text run; backends hide glyph names and Unicode choices behind this.
public struct MathFontHorizontalBraceLayout: Sendable, Equatable {
    public let drawString: String
    public let logicalFontName: String
    public let pointSize: CGFloat
    /// For ``CTGlyphInfoCreateWithGlyphName``; ``nil`` uses cmap for ``drawString`` only.
    public let coreTextGlyphName: String?
    public let layoutWidth: CGFloat
    public let height: CGFloat
    public let depth: CGFloat
    /// X offset from the brace node’s left edge to the Core Text baseline origin.
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

// MARK: - Default hooks (no Unicode remap; override in font providers)

extension MathFontProviding {
    public func mathcalMappedLetter(_: Character) -> String? {
        nil
    }

    public func isCaligraphicScriptCapital(character _: String, logicalFontName _: String) -> Bool {
        false
    }

    public func mathbbMappedLetter(_: Character) -> String? {
        nil
    }

    public func openTypeMathStretchDelimiterGlyphNames(for _: String) -> [String] {
        []
    }

    public func openTypeMatchingStretchDelimiterGlyphName(character _: String, templateGlyphName _: String?) -> String?
    {
        nil
    }
}
