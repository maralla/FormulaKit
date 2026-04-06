import CoreGraphics
import CoreText
import Foundation

// MARK: - Glyph measurement scratch
/// Glyph outline + metrics at a concrete `CTFont` size (used only inside FormulaKit).
struct ScaledGlyphData {
    let glyph: CGGlyph
    let path: CGPath
    let bounds: CGRect
    /// Typographic advance (``CTFontGetAdvancesForGlyphs`` vs ``CTRunGetAdvances`` max).
    let advanceWidth: CGFloat
    /// Rightmost ink extent used for italic correction: max of outline bounds and ``CTLine`` glyph-path bounds.
    let inkRight: CGFloat
}

/// Per-render workspace: deduplicates **glyph measurement** (paths + CTLine metrics) and **symbol boxes** for one
/// ``Renderer`` pass. ``SymbolNode`` keeps a separate, process-wide ``NSCache`` for ``CTFont`` resolution so we do
/// not duplicate that layer here.
///
/// Not thread-safe across concurrent renders; do not share one instance between threads.
public final class SymbolRenderScratch: @unchecked Sendable {
    private let lock = NSLock()
    private var glyphs: [String: ScaledGlyphData] = [:]
    private var boxes: [String: Box] = [:]

    public init() {}

    internal func cachedOrMeasureGlyph(
        font: CTFont,
        character: String,
        measurementKeySuffix: String = "",
        create: () -> ScaledGlyphData?
    ) -> ScaledGlyphData? {
        let ps = CTFontCopyPostScriptName(font) as String
        let pt = CTFontGetSize(font)
        let key = "\(ps)|\(character)|\(pt)\(measurementKeySuffix)"
        lock.lock()
        if let g = glyphs[key] {
            lock.unlock()
            return g
        }
        lock.unlock()
        guard let g = create() else { return nil }
        lock.lock()
        glyphs[key] = g
        lock.unlock()
        return g
    }

    internal func cachedBox(key: String) -> Box? {
        lock.lock()
        defer { lock.unlock() }
        return boxes[key]
    }

    internal func storeBox(key: String, box: Box) {
        lock.lock()
        defer { lock.unlock() }
        boxes[key] = box
    }
}

private final class ProcessFontCacheEntry: NSObject {
    let font: CTFont
    init(font: CTFont) {
        self.font = font
    }
}

/// Process-wide `CTFont` resolution cache. Uses `NSCache` so entries are **not** unbounded: the system
/// evicts under memory pressure, and `countLimit` caps how many distinct (logical font, size, character)
/// keys we retain.
private final class ProcessFontCache: @unchecked Sendable {
    private let cache: NSCache<NSString, ProcessFontCacheEntry> = {
        let c = NSCache<NSString, ProcessFontCacheEntry>()
        c.countLimit = 4096
        return c
    }()

    func get(_ key: String) -> CTFont? {
        cache.object(forKey: key as NSString)?.font
    }

    func set(_ key: String, font: CTFont) {
        cache.setObject(ProcessFontCacheEntry(font: font), forKey: key as NSString)
    }
}

/// A LayoutNode representing a single symbol (character).
public struct SymbolNode: LayoutNode {
    /// The TeX atom type for this node.
    public let type: AtomType

    /// The character to render.
    public let character: String

    /// The font name to use.
    public let fontName: String

    /// The font size in points.
    public let fontSize: CGFloat

    /// When true, `\text{…}`-style resolution: prefer text face over math face (see ``MathFontProviding``).
    public let metricsTextMode: Bool

    /// When set, measure and draw this OpenType math delimiter master (e.g. ``parenleft.s5``) instead of the cmap glyph for ``character``.
    public let openTypeMathGlyphName: String?

    private static let processFontCache = ProcessFontCache()

    public init(
        character: String,
        type: AtomType = .mord,
        fontName: String = MathLogicalFontNames.mainRegular,
        fontSize: CGFloat = 16.0,
        metricsTextMode: Bool = false,
        openTypeMathGlyphName: String? = nil
    ) {
        self.character = character
        self.type = type
        self.fontName = fontName
        self.fontSize = fontSize
        self.metricsTextMode = metricsTextMode
        self.openTypeMathGlyphName = openTypeMathGlyphName
    }

    public func getBox(options: FormulaKit.Options) -> Box {
        if character.isEmpty {
            return Box()
        }
        // Commands like \tanh used to pass the whole name into one SymbolNode; only the first
        // glyph was measured. Lay out letter-by-letter instead.
        if character.count > 1 {
            return multiCharacterBox(options: options)
        }

        let fm = FontMetrics.getMetrics(for: fontSize)

        let boxKey = Self.boxCacheKey(
            fontName: fontName,
            character: character,
            fontSize: fontSize,
            type: type,
            metricsTextMode: metricsTextMode,
            mathFont: options.mathFont,
            openTypeMathGlyphName: openTypeMathGlyphName
        )
        if let hit = options.symbolRenderScratch?.cachedBox(key: boxKey) {
            return hit
        }

        let font = getFont(options: options)
        guard let glyphData = measureGlyph(in: font, options: options) else {
            var ic: CGFloat = 0
            if options.resolvedMathFont.isCaligraphicScriptCapital(character: character, logicalFontName: fontName) {
                ic = max(ic, Self.caligraphicCapitalDelimiterKernPt(fontSize, options: options))
            }
            let box = Box(width: fontSize * 0.5, height: fontSize, depth: 0, italicCorrection: ic)
            options.symbolRenderScratch?.storeBox(key: boxKey, box: box)
            return box
        }

        let bounds = glyphData.bounds
        let axisHeight = fm.axisHeight * fontSize

        var yOffset: CGFloat = 0
        if type == .mbin || type == .mrel || type == .mop {
            let midY = (bounds.minY + bounds.maxY) / 2
            yOffset = axisHeight - midY
        }

        let height = max(0, bounds.maxY + yOffset)
        let depth = max(0, -(bounds.minY + yOffset))

        var italicCorrection = max(0, glyphData.inkRight - glyphData.advanceWidth)
        // 𝒩-style capitals: a small floor in em avoids residual overlap with following delimiters when
        // Core Text metrics are slightly tighter than painted pixels (also applies on non-macOS test hosts).
        if options.resolvedMathFont.isCaligraphicScriptCapital(character: character, logicalFontName: fontName) {
            italicCorrection = max(italicCorrection, Self.caligraphicCapitalDelimiterKernPt(fontSize, options: options))
        }
        let reportedWidth = glyphData.advanceWidth

        let box = Box(width: reportedWidth, height: height, depth: depth, italicCorrection: italicCorrection)
        options.symbolRenderScratch?.storeBox(key: boxKey, box: box)
        return box
    }

    private func getFont(options: FormulaKit.Options) -> CTFont {
        Self.ctFontForMathGlyph(
            fontName: fontName,
            character: character,
            fontSize: fontSize,
            metricsTextMode: metricsTextMode,
            mathFont: options.mathFont
        )
    }

    private static func boxCacheKey(
        fontName: String,
        character: String,
        fontSize: CGFloat,
        type: AtomType,
        metricsTextMode: Bool,
        mathFont: MathFontIdentifier,
        openTypeMathGlyphName: String?
    ) -> String {
        let ot = openTypeMathGlyphName.map { "|\($0)" } ?? ""
        return "|\(mathFont.rawValue)|\(fontName)|\(character)|\(fontSize)|\(type)|\(metricsTextMode)\(ot)|"
    }

    /// Resolves the same `CTFont` used when drawing ``MathTextRun``s from ``FormulaKit/render(_:options:)``.
    /// Uses a process-wide cache inside ``SymbolNode``; pairing with ``MathCompositeLayout/symbolRenderScratch`` is not required for fonts.
    /// Uses ``MathFontRegistry`` for ``mathFont``; when nil, uses ``MathFontRegistry/defaultIdentifier``.
    public static func ctFontForMathGlyph(
        fontName: String,
        character: String,
        fontSize: CGFloat,
        metricsTextMode: Bool = false,
        mathFont: MathFontIdentifier? = nil
    ) -> CTFont {
        let resolvedId = mathFont ?? MathFontRegistry.shared.defaultIdentifier
        return resolvedCTFontProcessCached(
            fontName: fontName,
            character: character,
            fontSize: fontSize,
            metricsTextMode: metricsTextMode,
            mathFont: resolvedId
        )
    }

    /// Shared across all renders; avoids repeated font descriptor work for the same (logical font, size, char).
    private static func resolvedCTFontProcessCached(
        fontName: String,
        character: String,
        fontSize: CGFloat,
        metricsTextMode: Bool,
        mathFont: MathFontIdentifier
    ) -> CTFont {
        let key = "\(mathFont.rawValue)|\(fontName)|\(fontSize)|\(character)|\(metricsTextMode)"
        if let hit = processFontCache.get(key) {
            return hit
        }
        let font = ctFontForMathGlyphUncached(
            fontName: fontName,
            character: character,
            fontSize: fontSize,
            metricsTextMode: metricsTextMode,
            mathFont: mathFont
        )
        processFontCache.set(key, font: font)
        return font
    }

    private static func ctFontForMathGlyphUncached(
        fontName: String,
        character: String,
        fontSize: CGFloat,
        metricsTextMode: Bool,
        mathFont: MathFontIdentifier
    ) -> CTFont {
        MathFontRegistry.shared.resolvedProvider(for: mathFont).ctFont(
            logicalFontName: fontName,
            character: character,
            textMode: metricsTextMode,
            fontSize: fontSize
        )
    }

    /// Minimum kern (pt) before delimiters after `\mathcal` capitals — from ``MathFontProviding/layout``.
    private static func caligraphicCapitalDelimiterKernPt(_ fontSize: CGFloat, options: FormulaKit.Options) -> CGFloat {
        options.resolvedMathFont.layout.caligraphicCapitalDelimiterKernEm * fontSize
    }

    /// Extra right-ink margin for script capitals: ``CTLine``/path bounds can sit inside the painted swash.
    private func caligraphicCapitalInkSlackPt(options: FormulaKit.Options) -> CGFloat {
        options.resolvedMathFont.isCaligraphicScriptCapital(character: character, logicalFontName: fontName)
            ? options.resolvedMathFont.layout.caligraphicScriptCapitalInkSlackEm * fontSize
            : 0
    }

    /// How far ``CTLineDraw`` can paint **left** of the line origin for a single glyph (e.g. `(` often has negative LSB).
    /// Layout advances the pen by the previous atom’s width + italic kern only; without this, tall swash + hanging `(` overlap.
    static func ctLineDrawingLeftHangPt(
        character: String,
        fontName: String,
        fontSize: CGFloat,
        mathFont: MathFontIdentifier? = nil
    ) -> CGFloat {
        guard character.count == 1 else { return 0 }
        let font = ctFontForMathGlyph(
            fontName: fontName,
            character: character,
            fontSize: fontSize,
            metricsTextMode: false,
            mathFont: mathFont
        )
        return MathFontCoreTextLineMetrics.drawingLeftHangPt(character: character, font: font)
    }

    private func measureGlyph(in font: CTFont, options: FormulaKit.Options) -> ScaledGlyphData? {
        if let gn = openTypeMathGlyphName {
            let suffix = "|ot:\(gn)"
            let namedBuild: () -> ScaledGlyphData? = {
                self.measureOpenTypeDelimiterGlyph(glyphName: gn, in: font, options: options)
            }
            if let scratch = options.symbolRenderScratch {
                return scratch.cachedOrMeasureGlyph(
                    font: font,
                    character: character,
                    measurementKeySuffix: suffix,
                    create: namedBuild
                )
            }
            return namedBuild()
        }

        let build: () -> ScaledGlyphData? = {
            var glyph = CGGlyph(0)
            let chars = Array(character.utf16)
            if !CTFontGetGlyphsForCharacters(font, chars, &glyph, 1) {
                return nil
            }
            var advance = CGSize.zero
            CTFontGetAdvancesForGlyphs(font, .horizontal, [glyph], &advance, 1)
            let lineAdvance = MathFontCoreTextLineMetrics.totalRunAdvanceWidth(character: character, font: font)
            let typographicAdvance = max(advance.width, lineAdvance)
            let linePathMaxX = MathFontCoreTextLineMetrics.glyphPathBoundsMaxX(character: character, font: font)
            let opticalMaxX = MathFontCoreTextLineMetrics.opticalBoundsMaxX(character: character, font: font)
            let caligraphic = options.resolvedMathFont.isCaligraphicScriptCapital(
                character: character,
                logicalFontName: fontName
            )
            // OpenType math glyphs may omit a vector path while still painting via ``CTLineDraw``.
            if let path = CTFontCreatePathForGlyph(font, glyph, nil) {
                // Script capitals (e.g. 𝒩): ``CTFontCreatePathForGlyph`` outline can sit inside the pixels
                // ``CTLineDraw`` paints — trust line/optical bounds for horizontal ink, not outline maxX alone.
                let pathRX = caligraphic ? 0 : path.boundingBox.maxX
                let inkRight =
                    max(pathRX, linePathMaxX, opticalMaxX) + self.caligraphicCapitalInkSlackPt(options: options)
                return ScaledGlyphData(
                    glyph: glyph,
                    path: path,
                    bounds: path.boundingBox,
                    advanceWidth: typographicAdvance,
                    inkRight: inkRight
                )
            }
            var bbox = CGRect.zero
            CTFontGetBoundingRectsForGlyphs(font, .horizontal, [glyph], &bbox, 1)
            let bboxRX = caligraphic ? 0 : bbox.maxX
            let inkRight =
                max(bboxRX, linePathMaxX, opticalMaxX, typographicAdvance)
                + self.caligraphicCapitalInkSlackPt(options: options)
            return ScaledGlyphData(
                glyph: glyph,
                path: CGMutablePath(),
                bounds: bbox,
                advanceWidth: typographicAdvance,
                inkRight: inkRight
            )
        }
        if let scratch = options.symbolRenderScratch {
            return scratch.cachedOrMeasureGlyph(font: font, character: character, create: build)
        }
        return build()
    }

    /// Metrics for an OpenType math delimiter master (Adobe glyph name) in the resolved ``CTFont``.
    private func measureOpenTypeDelimiterGlyph(
        glyphName: String,
        in font: CTFont,
        options: FormulaKit.Options
    ) -> ScaledGlyphData? {
        let glyph = CTFontGetGlyphWithName(font, glyphName as CFString)
        guard glyph != 0 else { return nil }
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, [glyph], &advance, 1)
        let typographicAdvance = advance.width
        let caligraphic = options.resolvedMathFont.isCaligraphicScriptCapital(
            character: character,
            logicalFontName: fontName
        )
        if let path = CTFontCreatePathForGlyph(font, glyph, nil) {
            let pathRX = caligraphic ? 0 : path.boundingBox.maxX
            let inkRight = max(pathRX, typographicAdvance) + caligraphicCapitalInkSlackPt(options: options)
            return ScaledGlyphData(
                glyph: glyph,
                path: path,
                bounds: path.boundingBox,
                advanceWidth: typographicAdvance,
                inkRight: inkRight
            )
        }
        var bbox = CGRect.zero
        CTFontGetBoundingRectsForGlyphs(font, .horizontal, [glyph], &bbox, 1)
        let bboxRX = caligraphic ? 0 : bbox.maxX
        let inkRight = max(bboxRX, typographicAdvance) + caligraphicCapitalInkSlackPt(options: options)
        return ScaledGlyphData(
            glyph: glyph,
            path: CGMutablePath(),
            bounds: bbox,
            advanceWidth: typographicAdvance,
            inkRight: inkRight
        )
    }

    /// Vertical shift for `mbin` / `mrel` / `mop` to sit on the math axis.
    private static func axisYOffset(
        fontSize: CGFloat,
        type: AtomType,
        glyphBounds: CGRect
    ) -> CGFloat {
        let fm = FontMetrics.getMetrics(for: fontSize)
        let axis = fm.axisHeight * fontSize
        guard type == .mbin || type == .mrel || type == .mop else { return 0 }
        let midY = (glyphBounds.minY + glyphBounds.maxY) / 2
        return axis - midY
    }

    private func multiCharacterBox(options: FormulaKit.Options) -> Box {
        var totalWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
        var maxDepth: CGFloat = 0
        var lastItalic: CGFloat = 0
        for ch in character {
            let one = SymbolNode(
                character: String(ch),
                type: type,
                fontName: fontName,
                fontSize: fontSize,
                metricsTextMode: metricsTextMode
            )
            let b = one.getBox(options: options)
            totalWidth += b.width
            maxHeight = max(maxHeight, b.height)
            maxDepth = max(maxDepth, b.depth)
            lastItalic = b.italicCorrection
        }
        return Box(width: totalWidth, height: maxHeight, depth: maxDepth, italicCorrection: lastItalic)
    }

    public func renderDecoration(at origin: CGPoint, options: FormulaKit.Options) -> CGPath {
        CGMutablePath()
    }

    public func collectTextRuns(at origin: CGPoint, options: FormulaKit.Options) -> [MathTextRun] {
        if character.isEmpty {
            return []
        }
        if character.count > 1 {
            var runs: [MathTextRun] = []
            var x: CGFloat = 0
            for ch in character {
                let one = SymbolNode(
                    character: String(ch),
                    type: type,
                    fontName: fontName,
                    fontSize: fontSize,
                    metricsTextMode: metricsTextMode
                )
                runs.append(
                    contentsOf: one.collectTextRuns(at: CGPoint(x: origin.x + x, y: origin.y), options: options)
                )
                x += one.getBox(options: options).width
            }
            return runs
        }

        let font = getFont(options: options)
        let glyphBounds = measureGlyph(in: font, options: options)?.bounds ?? .zero
        let yOffset = Self.axisYOffset(
            fontSize: fontSize,
            type: type,
            glyphBounds: glyphBounds
        )
        let baseline = CGPoint(x: origin.x, y: origin.y + yOffset)
        return [
            MathTextRun(
                string: character,
                fontName: fontName,
                fontSize: fontSize,
                baselineOrigin: baseline,
                metricsTextMode: metricsTextMode,
                openTypeMathGlyphName: openTypeMathGlyphName
            )
        ]
    }
}
