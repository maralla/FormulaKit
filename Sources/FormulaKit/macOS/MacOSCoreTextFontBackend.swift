#if os(macOS)
import AppKit
import CoreGraphics
import CoreText
import Foundation

extension MathPath {
    /// Converts this ``MathPath`` to a Core Graphics ``CGPath``.
    public var cgPath: CGPath {
        let path = CGMutablePath()
        for el in elements {
            switch el {
            case .moveTo(let p):
                path.move(to: p)
            case .lineTo(let p):
                path.addLine(to: p)
            case .quadTo(let c, let p):
                path.addQuadCurve(to: p, control: c)
            case .closeSubpath:
                path.closeSubpath()
            }
        }
        return path
    }
}

/// Core Text implementation of ``MathFontBackend``.
public struct MacOSCoreTextFontBackend: MathFontBackend {
    public init() {
        Self.ensureBundledFeiRegistered()
    }

    private static let bundledCGFont: CGFont? = {
        guard let url = FeiMath.bundledFontURL else { return nil }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        guard let provider = CGDataProvider(url: url as CFURL) else { return nil }
        return CGFont(provider)
    }()

    public static func ensureBundledFeiRegistered() {
        _ = bundledCGFont
    }

    public static func ctFont(postScriptName: String, size: CGFloat) -> CTFont? {
        ensureBundledFeiRegistered()
        let f = CTFontCreateWithName(postScriptName as CFString, size, nil)
        let ps = (CTFontCopyPostScriptName(f) as String?) ?? ""
        if ps == postScriptName {
            return f
        }
        if postScriptName == FeiMath.primaryMathPostScriptName, let cgFont = bundledCGFont {
            return CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
        }
        return nil
    }

    public static func resolvedCTFont(postScriptName: String, size: CGFloat) -> CTFont {
        ctFont(postScriptName: postScriptName, size: size) ?? (NSFont.systemFont(ofSize: size) as CTFont)
    }

    public func isFontAvailable(postScriptName: String, fontSize: CGFloat) -> Bool {
        Self.ctFont(postScriptName: postScriptName, size: fontSize) != nil
    }

    public func hasGlyph(_ character: String, postScriptName: String, fontSize: CGFloat) -> Bool {
        guard !character.isEmpty else { return true }
        guard let font = Self.ctFont(postScriptName: postScriptName, size: fontSize) else { return false }
        let u = Array(character.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: u.count)
        guard CTFontGetGlyphsForCharacters(font, u, &glyphs, u.count) else { return false }
        return glyphs.allSatisfy { $0 != 0 }
    }

    public func hasOpenTypeGlyph(named glyphName: String, postScriptName: String, fontSize: CGFloat) -> Bool {
        guard let font = Self.ctFont(postScriptName: postScriptName, size: fontSize) else { return false }
        return CTFontGetGlyphWithName(font, glyphName as CFString) != 0
    }

    public func measureGlyph(
        postScriptName: String,
        character: String,
        fontSize: CGFloat,
        openTypeGlyphName: String?,
        isCaligraphicCapital: Bool,
        inkSlackPt: CGFloat,
        isItalicSlot: Bool
    ) -> MathGlyphMetrics? {
        let font = Self.resolvedCTFont(postScriptName: postScriptName, size: fontSize)

        if let gn = openTypeGlyphName {
            let glyph = CTFontGetGlyphWithName(font, gn as CFString)
            guard glyph != 0 else { return nil }
            var advance = CGSize.zero
            CTFontGetAdvancesForGlyphs(font, .horizontal, [glyph], &advance, 1)
            let typographicAdvance = advance.width
            let italicSlack: CGFloat = isItalicSlot ? fontSize * 0.04 : 0
            if let path = CTFontCreatePathForGlyph(font, glyph, nil) {
                let b = path.boundingBox
                let pathRX = isCaligraphicCapital ? 0 : b.maxX
                let inkRight = max(pathRX, typographicAdvance + italicSlack) + (isCaligraphicCapital ? inkSlackPt : 0)
                return MathGlyphMetrics(
                    advanceWidth: typographicAdvance,
                    boundingBox: b,
                    inkRight: inkRight,
                    leftHang: max(0, -b.minX)
                )
            }
            var bbox = CGRect.zero
            CTFontGetBoundingRectsForGlyphs(font, .horizontal, [glyph], &bbox, 1)
            let bboxRX = isCaligraphicCapital ? 0 : bbox.maxX
            let inkRight = max(bboxRX, typographicAdvance + italicSlack) + (isCaligraphicCapital ? inkSlackPt : 0)
            return MathGlyphMetrics(
                advanceWidth: typographicAdvance,
                boundingBox: bbox,
                inkRight: inkRight,
                leftHang: max(0, -bbox.minX)
            )
        }

        var glyph = CGGlyph(0)
        let chars = Array(character.utf16)
        guard CTFontGetGlyphsForCharacters(font, chars, &glyph, 1) else { return nil }
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, [glyph], &advance, 1)

        let line = Self.attributedLine(character: character, font: font)
        let lineAdvance = Self.totalRunAdvanceWidth(line: line)
        let typographicAdvance = max(advance.width, lineAdvance)
        let bPath = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let bOpt = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        let leftHang = character.count == 1 ? max(0, -min(bPath.minX, bOpt.minX)) : 0

        if let path = CTFontCreatePathForGlyph(font, glyph, nil) {
            let b = path.boundingBox
            let pathRX = isCaligraphicCapital ? 0 : b.maxX
            let inkRight = max(pathRX, bPath.maxX, bOpt.maxX) + (isCaligraphicCapital ? inkSlackPt : 0)
            return MathGlyphMetrics(
                advanceWidth: typographicAdvance,
                boundingBox: b,
                inkRight: inkRight,
                leftHang: leftHang
            )
        }
        var bbox = CGRect.zero
        CTFontGetBoundingRectsForGlyphs(font, .horizontal, [glyph], &bbox, 1)
        let bboxRX = isCaligraphicCapital ? 0 : bbox.maxX
        let inkRight = max(bboxRX, bPath.maxX, bOpt.maxX, typographicAdvance) + (isCaligraphicCapital ? inkSlackPt : 0)
        return MathGlyphMetrics(
            advanceWidth: typographicAdvance,
            boundingBox: bbox,
            inkRight: inkRight,
            leftHang: leftHang
        )
    }

    private static func attributedLine(character: String, font: CTFont) -> CTLine {
        let attrs: [NSAttributedString.Key: Any] = [.font: font as NSFont]
        return CTLineCreateWithAttributedString(NSAttributedString(string: character, attributes: attrs))
    }

    private static func totalRunAdvanceWidth(line: CTLine) -> CGFloat {
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return 0 }
        var total: CGFloat = 0
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            var advances = [CGSize](repeating: .zero, count: count)
            CTRunGetAdvances(run, CFRangeMake(0, count), &advances)
            for a in advances { total += a.width }
        }
        return total
    }
}

extension SymbolNode {
    /// Resolves the `CTFont` used when drawing ``MathTextRun``s.
    public static func ctFontForMathGlyph(
        fontName: String,
        character: String,
        fontSize: CGFloat,
        metricsTextMode: Bool = false,
        mathFont: MathFontIdentifier? = nil
    ) -> CTFont {
        let resolvedId = mathFont ?? MathFontRegistry.shared.defaultIdentifier
        let provider = MathFontRegistry.shared.resolvedProvider(for: resolvedId)
        let psName = provider.resolvedPostScriptFontName(
            logicalFontName: fontName,
            character: character,
            textMode: metricsTextMode,
            fontSize: fontSize
        )
        return MacOSCoreTextFontBackend.resolvedCTFont(postScriptName: psName, size: fontSize)
    }
}
#endif
