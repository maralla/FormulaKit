import CoreGraphics
import CoreText
import Foundation

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Apple ships **STIX Two Math** and **STIX Two Text** in system font locations.
/// FormulaKit uses them as the default math/text backend when available.
///
/// Keep **all** STIX-specific names, availability checks, glyph resolution, and layout tuning here so the rest of the module stays font-agnostic.
enum STIX {
    // MARK: - PostScript names

    static let primaryMathPostScriptName = "STIXTwoMath-Regular"
    static let textPostScriptName = "STIXTwoText"
    static let textItalicPostScriptName = "STIXTwoText-Italic"

    /// Shown in diagnostics when the primary math face is missing.
    static let supplementalFontsDirectoryHint = "/System/Library/Fonts/Supplemental/"

    // MARK: - Layout tuning (em / mu unless noted)

    /// Values tuned for STIX Two Math with Core Text.
    enum Layout {
        /// Positive kern (in **em**) between nucleus (after optional `-italic` shift) and subscript.
        static let subscriptExtraGapEm: CGFloat = 0.06
        /// Cap on italic correction used for script positioning (full `italicCorrection` still on trailing node).
        static let scriptItalicCorrectionCapEm: CGFloat = 0.2
        /// Shave from delimiter LSB hang after `.mop` before a round `(` (in **mu**; multiply by `cssEmPerMu * fontSize`).
        static let mopRoundOpenParenHangShaveMu: CGFloat = 3.25
        /// Minimum kern before delimiters after `\mathcal` capitals (as **em** of `fontSize`).
        static let caligraphicCapitalDelimiterKernEm: CGFloat = 0.32
        /// Extra right-ink margin for script capitals (as **em** of `fontSize`).
        static let caligraphicScriptCapitalInkSlackEm: CGFloat = 0.18

        /// Enclosing delimiters: slack, mild post–Size4 scaling, `\big*` targets.
        ///
        /// **Discrete sizes:** (1) **STIX Two Math** OpenType math masters ``parenleft``, ``parenleft.s1``, … ``.s12`` at body
        /// size (via ``CTGlyphInfo``). (2) Layout ``Size1``…``Size4`` tiers map to **STIXSize*Sym-Regular** when a glyph still uses
        /// logical size slots. ``leftRightMaxExtraScale`` only nudges after the largest ``.s*`` master.
        static let delimiterSizing = DelimiterSizing(
            requiredHeightSlackEm: 0.045,
            requiredHeightSlackMinPt: 1,
            leftRightMaxExtraScale: 1.38,
            leftRightTargetHeightMultiple: 1.06,
            bigDelimiterMaxExtraScale: 1.12,
            bigDelimiterMinHeightMultiples: [
                "big": 1.22,
                "Big": 1.78,
                "bigg": 2.40,
                "Bigg": 3.05,
            ]
        )
    }

    // MARK: - Availability

    private static func ctFontMatchingPostScriptName(_ name: String, size: CGFloat) -> CTFont? {
        let f = CTFontCreateWithName(name as CFString, size, nil)
        let ps = (CTFontCopyPostScriptName(f) as String?) ?? ""
        return ps == name ? f : nil
    }

    private static func systemCTFont(size: CGFloat) -> CTFont {
        #if os(macOS)
        (NSFont.systemFont(ofSize: size) as CTFont)
        #elseif canImport(UIKit)
        (UIFont.systemFont(ofSize: size) as CTFont)
        #else
        CTFontCreateWithName("Helvetica" as CFString, size, nil)
        #endif
    }

    static func isPrimaryMathFontAvailable(forFontSize size: CGFloat) -> Bool {
        ctFontMatchingPostScriptName(primaryMathPostScriptName, size: size) != nil
    }

    // MARK: - Glyph resolution

    static func hasGlyph(_ character: String, in font: CTFont) -> Bool {
        guard !character.isEmpty else { return true }
        let u = Array(character.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: u.count)
        guard CTFontGetGlyphsForCharacters(font, u, &glyphs, u.count) else { return false }
        return glyphs.allSatisfy { $0 != 0 }
    }

    // MARK: - OpenType math delimiter masters (STIX Two Math)

    /// Adobe glyph names for stretchy delimiters: default + ``.s1``…``.s12`` size masters (see STIX Two Math glyph map).
    static func openTypeMathStretchDelimiterGlyphNames(for character: String) -> [String] {
        guard let base = openTypeMathDelimiterBaseGlyphName(character) else { return [] }
        var names = [base]
        for i in 1...12 {
            names.append("\(base).s\(i)")
        }
        return names
    }

    /// PostScript glyph names for horizontal ``\overbrace`` / ``\underbrace`` width masters (STIX Two Math only).
    fileprivate static func horizontalBraceGlyphNameCandidates(isOver: Bool) -> [String] {
        let base = isOver ? "uni23DE" : "uni23DF"
        var names = [base]
        for i in 1...5 {
            names.append("\(base).s\(i)")
        }
        return names
    }

    /// Same ``.s*`` step as ``templateGlyphName`` for a different delimiter (e.g. ``parenleft.s5`` + ``)`` → ``parenright.s5``).
    static func openTypeMatchingDelimiterGlyphName(character: String, templateGlyphName: String?) -> String? {
        guard let template = templateGlyphName, let ownBase = openTypeMathDelimiterBaseGlyphName(character) else {
            return nil
        }
        if let dot = template.lastIndex(of: "."), template[dot...].hasPrefix(".s") {
            return ownBase + String(template[dot...])
        }
        return ownBase
    }

    /// Maps one Unicode delimiter to its **default** glyph name in STIX Two Math (before ``.s*`` suffixes).
    private static func openTypeMathDelimiterBaseGlyphName(_ character: String) -> String? {
        guard character.count == 1, let v = character.unicodeScalars.first?.value else { return nil }
        switch v {
        case 0x0028: return "parenleft"
        case 0x0029: return "parenright"
        case 0x005B: return "bracketleft"
        case 0x005D: return "bracketright"
        case 0x007B: return "braceleft"
        case 0x007D: return "braceright"
        case 0x007C: return "bar"
        case 0x2016: return "uni2016"  // ‖
        case 0x2308, 0x2309, 0x230A, 0x230B: return String(format: "uni%04X", v)
        case 0x27E8: return "uni27E8"
        case 0x27E9: return "uni27E9"
        default:
            return nil
        }
    }

    /// Apple bundles legacy **STIX size-symbol** OT files (same Unicode code points as STIX Two Math, larger drawn glyphs).
    private static func sizeSymbolPostScriptName(logicalFontName: String) -> String? {
        switch logicalFontName {
        case MathLogicalFontNames.size1Regular: return "STIXSizeOneSym-Regular"
        case MathLogicalFontNames.size2Regular: return "STIXSizeTwoSym-Regular"
        case MathLogicalFontNames.size3Regular: return "STIXSizeThreeSym-Regular"
        case MathLogicalFontNames.size4Regular: return "STIXSizeFourSym-Regular"
        default: return nil
        }
    }

    /// Pick a system STIX `CTFont` that contains `character`, given the logical font slot name.
    static func ctFont(logicalFontName: String, character: String, textMode: Bool, fontSize: CGFloat) -> CTFont {
        let candidates = postScriptNameCandidates(logicalFontName: logicalFontName, textMode: textMode)
        for ps in candidates {
            guard let f = ctFontMatchingPostScriptName(ps, size: fontSize) else { continue }
            if character.isEmpty || hasGlyph(character, in: f) {
                return f
            }
        }
        return ctFontMatchingPostScriptName(primaryMathPostScriptName, size: fontSize)
            ?? systemCTFont(size: fontSize)
    }

    private static func postScriptNameCandidates(logicalFontName: String, textMode: Bool) -> [String] {
        if textMode {
            return [textPostScriptName, primaryMathPostScriptName]
        }
        let logical = logicalFontName
        if logical == MathLogicalFontNames.mainItalic {
            return [textItalicPostScriptName, primaryMathPostScriptName, textPostScriptName]
        }
        if logical == MathLogicalFontNames.mathItalic {
            return [primaryMathPostScriptName, textItalicPostScriptName]
        }
        if logical == MathLogicalFontNames.mainBold || logical == MathLogicalFontNames.boldsymbolSlot
            || logical.contains(MathLogicalFontNames.boldFaceMarker)
        {
            return [primaryMathPostScriptName, textPostScriptName]
        }
        if let sym = sizeSymbolPostScriptName(logicalFontName: logical) {
            return [sym, primaryMathPostScriptName]
        }
        if logical.hasPrefix(MathLogicalFontNames.sizeFamilyPrefix) {
            return [primaryMathPostScriptName]
        }
        if logical == MathLogicalFontNames.typewriterRegular
            || logical.contains(MathLogicalFontNames.sansSerifFamilyMarker)
            || logical == MathLogicalFontNames.caligraphicRegular
            || logical == MathLogicalFontNames.amsRegular
        {
            return [primaryMathPostScriptName, textPostScriptName]
        }
        return [primaryMathPostScriptName, textPostScriptName]
    }

    // MARK: - ``\mathcal`` (Unicode script; reference web fonts use cmap on ASCII instead)

    /// Mathematical script capitals (not contiguous in Unicode).
    private static let mathcalCapitalScalars: [UnicodeScalar] = [
        UnicodeScalar(0x1D49C)!, UnicodeScalar(0x212C)!, UnicodeScalar(0x1D49E)!, UnicodeScalar(0x1D49F)!,
        UnicodeScalar(0x2130)!, UnicodeScalar(0x2131)!, UnicodeScalar(0x1D4A2)!, UnicodeScalar(0x210B)!,
        UnicodeScalar(0x2110)!, UnicodeScalar(0x1D4A5)!, UnicodeScalar(0x1D4A6)!, UnicodeScalar(0x2112)!,
        UnicodeScalar(0x2133)!, UnicodeScalar(0x1D4A9)!, UnicodeScalar(0x1D4AA)!, UnicodeScalar(0x1D4AB)!,
        UnicodeScalar(0x1D4AC)!, UnicodeScalar(0x211B)!, UnicodeScalar(0x1D4AE)!, UnicodeScalar(0x1D4AF)!,
        UnicodeScalar(0x1D4B0)!, UnicodeScalar(0x1D4B1)!, UnicodeScalar(0x1D4B2)!, UnicodeScalar(0x1D4B3)!,
        UnicodeScalar(0x1D4B4)!, UnicodeScalar(0x1D4B5)!,
    ]

    /// STIX Two Math omits a few code points in the ``U+1D4B6``…``U+1D4CF`` block; use Letterlike Symbols.
    private static let mathcalLowerHoleReplacements: [UInt32: UnicodeScalar] = [
        0x1D4BA: UnicodeScalar(0x212F)!,  // e — SCRIPT SMALL E
        0x1D4BC: UnicodeScalar(0x210A)!,  // g — SCRIPT SMALL G
        0x1D4C4: UnicodeScalar(0x2134)!,  // o — SCRIPT SMALL O
    ]

    /// Maps A–Z / a–z to Unicode script for STIX Two Math.
    static func mathcalMappedLetter(_ character: Character) -> String? {
        if let v = character.unicodeScalars.first?.value, v >= 0x41, v <= 0x5A {
            let idx = Int(v - 0x41)
            return String(mathcalCapitalScalars[idx])
        }
        if let v = character.unicodeScalars.first?.value, v >= 0x61, v <= 0x7A {
            let ord = Int(v - 0x61)
            let code = 0x1D4B6 + ord
            let scalar = mathcalLowerHoleReplacements[UInt32(code)] ?? UnicodeScalar(code)!
            return String(scalar)
        }
        return nil
    }

    /// True if `character` is a single Unicode scalar for a **capital** produced by ``mathcalMappedLetter`` (𝒜–𝒵-style).
    static func isCaligraphicScriptCapital(_ character: String) -> Bool {
        guard character.unicodeScalars.count == 1, let u = character.unicodeScalars.first?.value else { return false }
        return mathcalCapitalScalars.contains { $0.value == u }
    }

    // MARK: - ``\mathbb`` (double-struck Unicode for OpenType math)

    /// Double-struck capitals (Letterlike Symbols + ``U+1D538`` block; not contiguous).
    private static let mathbbCapitalScalars: [UnicodeScalar] = [
        UnicodeScalar(0x1D538)!, UnicodeScalar(0x1D539)!, UnicodeScalar(0x2102)!, UnicodeScalar(0x1D53B)!,
        UnicodeScalar(0x1D53C)!, UnicodeScalar(0x1D53D)!, UnicodeScalar(0x1D53E)!, UnicodeScalar(0x210D)!,
        UnicodeScalar(0x1D540)!, UnicodeScalar(0x1D541)!, UnicodeScalar(0x1D542)!, UnicodeScalar(0x1D543)!,
        UnicodeScalar(0x1D544)!, UnicodeScalar(0x2115)!, UnicodeScalar(0x1D546)!, UnicodeScalar(0x2119)!,
        UnicodeScalar(0x211A)!, UnicodeScalar(0x211D)!, UnicodeScalar(0x1D54A)!, UnicodeScalar(0x1D54B)!,
        UnicodeScalar(0x1D54C)!, UnicodeScalar(0x1D54D)!, UnicodeScalar(0x1D54E)!, UnicodeScalar(0x1D54F)!,
        UnicodeScalar(0x1D550)!, UnicodeScalar(0x2124)!,
    ]

    private static let mathbbDoubleStruckSmallABase: UInt32 = 0x1D552

    /// Maps A–Z / a–z to Unicode double-struck for STIX Two Math.
    static func mathbbMappedLetter(_ character: Character) -> String? {
        if let v = character.unicodeScalars.first?.value, v >= 0x41, v <= 0x5A {
            let idx = Int(v - 0x41)
            return String(mathbbCapitalScalars[idx])
        }
        if let v = character.unicodeScalars.first?.value, v >= 0x61, v <= 0x7A {
            let ord = UInt32(v - 0x61)
            return String(UnicodeScalar(mathbbDoubleStruckSmallABase + ord)!)
        }
        return nil
    }
}

// MARK: - ``\overbrace`` / ``\underbrace`` (STIX Two Math)

extension STIX {
    /// Prefer STIX Two Math width-master glyphs; if those PostScript names do not resolve in ``CTFont``, use cmap-scaled
    /// ``U+23DE`` / ``U+23DF``. Always returns a ``MathFontHorizontalBraceLayout``.
    static func makeHorizontalBraceLayout(
        provider: any MathFontProviding,
        isOver: Bool,
        layoutWidth: CGFloat,
        bodyFontSize: CGFloat,
        mathFont: MathFontIdentifier
    ) -> MathFontHorizontalBraceLayout {
        let character = isOver ? "\u{23DE}" : "\u{23DF}"
        let logical = MathLogicalFontNames.mainRegular
        let layoutW = layoutWidth

        if provider.isPrimaryMathFontAvailable(forFontSize: bodyFontSize),
            let mastered = layoutFromOpenTypeBraceWidthMasters(
                provider: provider,
                isOver: isOver,
                character: character,
                logical: logical,
                layoutW: layoutW,
                bodyFontSize: bodyFontSize,
                mathFont: mathFont
            )
        {
            return mastered
        }
        return cmapOnlyHorizontalBraceLayout(
            provider: provider,
            character: character,
            logical: logical,
            layoutW: layoutW,
            bodyFontSize: bodyFontSize,
            mathFont: mathFont
        )
    }

    /// STIX Two Math ``uni23DE`` / ``uni23DF`` width masters (``.s1``…``.s5``). Returns ``nil`` only when **named** glyphs
    /// do not resolve in the resolved ``CTFont`` (wrong face / install); then ``cmapOnlyHorizontalBraceLayout`` runs.
    private static func layoutFromOpenTypeBraceWidthMasters(
        provider: any MathFontProviding,
        isOver: Bool,
        character: String,
        logical: String,
        layoutW: CGFloat,
        bodyFontSize: CGFloat,
        mathFont: MathFontIdentifier
    ) -> MathFontHorizontalBraceLayout? {
        let rawNames = horizontalBraceGlyphNameCandidates(isOver: isOver)
        guard !rawNames.isEmpty else { return nil }

        let baseFont = provider.ctFont(
            logicalFontName: logical,
            character: character,
            textMode: false,
            fontSize: bodyFontSize
        )
        let names = rawNames.filter { CTFontGetGlyphWithName(baseFont, $0 as CFString) != 0 }
        guard !names.isEmpty else { return nil }

        let maxScale = provider.delimiterSizing.leftRightMaxExtraScale

        func inkMetrics(glyphName: String) -> (w: CGFloat, bbox: CGRect)? {
            let g = CTFontGetGlyphWithName(baseFont, glyphName as CFString)
            guard g != 0 else { return nil }
            var adv = CGSize.zero
            CTFontGetAdvancesForGlyphs(baseFont, .horizontal, [g], &adv, 1)
            if let path = CTFontCreatePathForGlyph(baseFont, g, nil) {
                let b = path.boundingBox
                return (max(b.width, adv.width), b)
            }
            var b = CGRect.zero
            CTFontGetBoundingRectsForGlyphs(baseFont, .horizontal, [g], &b, 1)
            return (max(b.width, adv.width), b)
        }

        var pick: (name: String, w: CGFloat, bbox: CGRect)?
        for name in names {
            guard let m = inkMetrics(glyphName: name) else { continue }
            if m.w * maxScale >= layoutW - 0.25 {
                pick = (name, m.w, m.bbox)
                break
            }
        }
        if pick == nil {
            for name in names.reversed() {
                if let m = inkMetrics(glyphName: name) {
                    pick = (name, m.w, m.bbox)
                    break
                }
            }
        }
        guard let (glyphName, w0, _) = pick else { return nil }

        let scale = min(maxScale, layoutW / max(w0, 0.0001))
        let effectiveFontSize = bodyFontSize * scale
        let drawFont = SymbolNode.ctFontForMathGlyph(
            fontName: logical,
            character: character,
            fontSize: effectiveFontSize,
            metricsTextMode: false,
            mathFont: mathFont
        )
        let gDraw = CTFontGetGlyphWithName(drawFont, glyphName as CFString)
        guard gDraw != 0 else { return nil }

        var bbox = CGRect.zero
        if let path = CTFontCreatePathForGlyph(drawFont, gDraw, nil) {
            bbox = path.boundingBox
        } else {
            CTFontGetBoundingRectsForGlyphs(drawFont, .horizontal, [gDraw], &bbox, 1)
        }
        let height = max(0, bbox.maxY)
        let depth = max(0, -bbox.minY)
        let cx = (bbox.minX + bbox.maxX) / 2
        let textOffsetX = layoutW / 2 - cx

        return MathFontHorizontalBraceLayout(
            drawString: character,
            logicalFontName: logical,
            pointSize: effectiveFontSize,
            coreTextGlyphName: glyphName,
            layoutWidth: layoutW,
            height: height,
            depth: depth,
            textOriginOffsetX: textOffsetX
        )
    }

    private static func cmapOnlyHorizontalBraceLayout(
        provider: any MathFontProviding,
        character: String,
        logical: String,
        layoutW: CGFloat,
        bodyFontSize: CGFloat,
        mathFont: MathFontIdentifier
    ) -> MathFontHorizontalBraceLayout {
        let baseFont = provider.ctFont(
            logicalFontName: logical,
            character: character,
            textMode: false,
            fontSize: bodyFontSize
        )
        let utf16 = Array(character.utf16)
        var g: CGGlyph = 0
        guard CTFontGetGlyphsForCharacters(baseFont, utf16, &g, 1), g != 0 else {
            return MathFontHorizontalBraceLayout(
                drawString: character,
                logicalFontName: logical,
                pointSize: bodyFontSize,
                coreTextGlyphName: nil,
                layoutWidth: layoutW,
                height: 0,
                depth: 0,
                textOriginOffsetX: layoutW / 2
            )
        }
        var adv = CGSize.zero
        CTFontGetAdvancesForGlyphs(baseFont, .horizontal, [g], &adv, 1)
        let w0: CGFloat
        if let path = CTFontCreatePathForGlyph(baseFont, g, nil) {
            w0 = max(path.boundingBox.width, adv.width)
        } else {
            var b = CGRect.zero
            CTFontGetBoundingRectsForGlyphs(baseFont, .horizontal, [g], &b, 1)
            w0 = max(b.width, adv.width)
        }
        let maxScale = provider.delimiterSizing.leftRightMaxExtraScale
        let scale = min(maxScale, layoutW / max(w0, 0.0001))
        let effective = bodyFontSize * scale
        let drawFont = SymbolNode.ctFontForMathGlyph(
            fontName: logical,
            character: character,
            fontSize: effective,
            metricsTextMode: false,
            mathFont: mathFont
        )
        var g2: CGGlyph = 0
        guard CTFontGetGlyphsForCharacters(drawFont, utf16, &g2, 1), g2 != 0 else {
            return MathFontHorizontalBraceLayout(
                drawString: character,
                logicalFontName: logical,
                pointSize: bodyFontSize,
                coreTextGlyphName: nil,
                layoutWidth: layoutW,
                height: 0,
                depth: 0,
                textOriginOffsetX: layoutW / 2
            )
        }
        var bbox = CGRect.zero
        if let path = CTFontCreatePathForGlyph(drawFont, g2, nil) {
            bbox = path.boundingBox
        } else {
            CTFontGetBoundingRectsForGlyphs(drawFont, .horizontal, [g2], &bbox, 1)
        }
        let height = max(0, bbox.maxY)
        let depth = max(0, -bbox.minY)
        let cx = (bbox.minX + bbox.maxX) / 2
        let textOffsetX = layoutW / 2 - cx
        return MathFontHorizontalBraceLayout(
            drawString: character,
            logicalFontName: logical,
            pointSize: effective,
            coreTextGlyphName: nil,
            layoutWidth: layoutW,
            height: height,
            depth: depth,
            textOriginOffsetX: textOffsetX
        )
    }
}

// MARK: - Registry provider

/// Default backend: system STIX Two Math / Text when installed.
public struct STIXMathFontProvider: MathFontProviding {
    public init() {}

    public let identifier = MathFontIdentifier.stix

    public var layout: MathFontLayoutTuning {
        MathFontLayoutTuning(
            subscriptExtraGapEm: STIX.Layout.subscriptExtraGapEm,
            scriptItalicCorrectionCapEm: STIX.Layout.scriptItalicCorrectionCapEm,
            mopRoundOpenParenHangShaveMu: STIX.Layout.mopRoundOpenParenHangShaveMu,
            caligraphicCapitalDelimiterKernEm: STIX.Layout.caligraphicCapitalDelimiterKernEm,
            caligraphicScriptCapitalInkSlackEm: STIX.Layout.caligraphicScriptCapitalInkSlackEm
        )
    }

    public var delimiterSizing: DelimiterSizing {
        STIX.Layout.delimiterSizing
    }

    public func ctFont(logicalFontName: String, character: String, textMode: Bool, fontSize: CGFloat) -> CTFont {
        STIX.ctFont(logicalFontName: logicalFontName, character: character, textMode: textMode, fontSize: fontSize)
    }

    public func isPrimaryMathFontAvailable(forFontSize size: CGFloat) -> Bool {
        STIX.isPrimaryMathFontAvailable(forFontSize: size)
    }

    public var primaryMathPostScriptName: String { STIX.primaryMathPostScriptName }

    public var supplementalFontsDirectoryHint: String { STIX.supplementalFontsDirectoryHint }

    public func mathcalMappedLetter(_ character: Character) -> String? {
        STIX.mathcalMappedLetter(character)
    }

    public func isCaligraphicScriptCapital(character: String, logicalFontName _: String) -> Bool {
        STIX.isCaligraphicScriptCapital(character)
    }

    public func mathbbMappedLetter(_ character: Character) -> String? {
        STIX.mathbbMappedLetter(character)
    }

    public func openTypeMathStretchDelimiterGlyphNames(for character: String) -> [String] {
        STIX.openTypeMathStretchDelimiterGlyphNames(for: character)
    }

    public func openTypeMatchingStretchDelimiterGlyphName(character: String, templateGlyphName: String?) -> String? {
        STIX.openTypeMatchingDelimiterGlyphName(character: character, templateGlyphName: templateGlyphName)
    }

    public func horizontalBraceLayout(
        isOver: Bool,
        layoutWidth: CGFloat,
        bodyFontSize: CGFloat,
        mathFont: MathFontIdentifier
    ) -> MathFontHorizontalBraceLayout {
        STIX.makeHorizontalBraceLayout(
            provider: self,
            isOver: isOver,
            layoutWidth: layoutWidth,
            bodyFontSize: bodyFontSize,
            mathFont: mathFont
        )
    }
}
