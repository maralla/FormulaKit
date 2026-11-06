import Foundation

/// Per-render workspace: deduplicates **glyph measurement** and **symbol boxes** for one ``Renderer`` pass.
public final class SymbolRenderScratch: @unchecked Sendable {
    private let lock = NSLock()
    private var glyphs: [String: MathGlyphMetrics] = [:]
    private var boxes: [String: Box] = [:]

    public init() {}

    internal func cachedOrMeasureGlyph(
        key: String,
        create: () -> MathGlyphMetrics?
    ) -> MathGlyphMetrics? {
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

/// A LayoutNode representing a single symbol (character).
public struct SymbolNode: LayoutNode {
    public let type: AtomType
    public let character: String
    public let fontName: String
    public let fontSize: CGFloat
    public let metricsTextMode: Bool
    public let openTypeMathGlyphName: String?

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

        guard let glyphData = measureGlyph(options: options) else {
            var ic: CGFloat = 0
            if options.resolvedMathFont.isCaligraphicScriptCapital(character: character, logicalFontName: fontName) {
                ic = max(ic, Self.caligraphicCapitalDelimiterKernPt(fontSize, options: options))
            }
            let box = Box(width: fontSize * 0.5, height: fontSize, depth: 0, italicCorrection: ic)
            options.symbolRenderScratch?.storeBox(key: boxKey, box: box)
            return box
        }

        let bounds = glyphData.boundingBox
        let yOffset = Self.axisYOffset(
            fontSize: fontSize,
            type: type,
            character: character,
            glyphBounds: bounds
        )

        let height = max(0, bounds.maxY + yOffset)
        let depth = max(0, -(bounds.minY + yOffset))

        var italicCorrection = max(0, glyphData.inkRight - glyphData.advanceWidth)
        if options.resolvedMathFont.isCaligraphicScriptCapital(character: character, logicalFontName: fontName) {
            italicCorrection = max(italicCorrection, Self.caligraphicCapitalDelimiterKernPt(fontSize, options: options))
        }
        let box = Box(
            width: glyphData.advanceWidth,
            height: height,
            depth: depth,
            italicCorrection: italicCorrection
        )
        options.symbolRenderScratch?.storeBox(key: boxKey, box: box)
        return box
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

    private static func caligraphicCapitalDelimiterKernPt(_ fontSize: CGFloat, options: FormulaKit.Options) -> CGFloat {
        options.resolvedMathFont.layout.caligraphicCapitalDelimiterKernEm * fontSize
    }

    private func caligraphicCapitalInkSlackPt(options: FormulaKit.Options) -> CGFloat {
        options.resolvedMathFont.isCaligraphicScriptCapital(character: character, logicalFontName: fontName)
            ? options.resolvedMathFont.layout.caligraphicScriptCapitalInkSlackEm * fontSize
            : 0
    }

    static func ctLineDrawingLeftHangPt(
        character: String,
        fontName: String,
        fontSize: CGFloat,
        mathFont: MathFontIdentifier? = nil
    ) -> CGFloat {
        guard character.count == 1 else { return 0 }
        let resolvedId = mathFont ?? MathFontRegistry.shared.defaultIdentifier
        let provider = MathFontRegistry.shared.resolvedProvider(for: resolvedId)
        let psName = provider.resolvedPostScriptFontName(
            logicalFontName: fontName,
            character: character,
            textMode: false,
            fontSize: fontSize
        )
        return MathFont.backend.measureGlyph(
            postScriptName: psName,
            character: character,
            fontSize: fontSize,
            openTypeGlyphName: nil,
            isCaligraphicCapital: false,
            inkSlackPt: 0,
            isItalicSlot: false
        )?.leftHang ?? 0
    }

    private func effectiveOpenTypeGlyphName(options: FormulaKit.Options) -> String? {
        if let explicit = openTypeMathGlyphName {
            return explicit
        }
        return options.resolvedMathFont.openTypeGlyphName(
            logicalFontName: fontName,
            character: character,
            textMode: metricsTextMode
        )
    }

    private func measureGlyph(options: FormulaKit.Options) -> MathGlyphMetrics? {
        let provider = options.resolvedMathFont
        let psName = provider.resolvedPostScriptFontName(
            logicalFontName: fontName,
            character: character,
            textMode: metricsTextMode,
            fontSize: fontSize
        )
        let effectiveOT = effectiveOpenTypeGlyphName(options: options)
        let caligraphic = provider.isCaligraphicScriptCapital(character: character, logicalFontName: fontName)
        let slack = caligraphicCapitalInkSlackPt(options: options)
        let isItalic = fontName == MathLogicalFontNames.mathItalic || fontName == MathLogicalFontNames.mainItalic
        let key = "\(psName)|\(character)|\(fontSize)|\(effectiveOT ?? "")|\(caligraphic)|\(isItalic)"

        let build: () -> MathGlyphMetrics? = {
            MathFont.backend.measureGlyph(
                postScriptName: psName,
                character: character,
                fontSize: fontSize,
                openTypeGlyphName: effectiveOT,
                isCaligraphicCapital: caligraphic,
                inkSlackPt: slack,
                isItalicSlot: isItalic
            )
        }
        if let scratch = options.symbolRenderScratch {
            return scratch.cachedOrMeasureGlyph(key: key, create: build)
        }
        return build()
    }

    private static func axisYOffset(
        fontSize: CGFloat,
        type: AtomType,
        character: String,
        glyphBounds: CGRect
    ) -> CGFloat {
        let fm = FontMetrics.getMetrics(for: fontSize)
        let axis = fm.axisHeight * fontSize
        guard type == .mbin || type == .mrel || type == .mop else { return 0 }
        if type == .mop, let sc = character.unicodeScalars.first, sc.value <= 0x007E {
            return 0
        }
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

    public func renderDecoration(at _: CGPoint, options _: FormulaKit.Options) -> MathPath {
        MathPath()
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

        let glyphBounds = measureGlyph(options: options)?.boundingBox ?? .zero
        let yOffset = Self.axisYOffset(
            fontSize: fontSize,
            type: type,
            character: character,
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
                openTypeMathGlyphName: effectiveOpenTypeGlyphName(options: options)
            )
        ]
    }
}
