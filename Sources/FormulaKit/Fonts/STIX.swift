import Foundation

/// STIX Two Math / Text font provider and OpenType math helpers.
enum STIX {
    // MARK: - PostScript names

    static let primaryMathPostScriptName = "STIXTwoMath-Regular"
    static let textPostScriptName = "STIXTwoText"
    static let textItalicPostScriptName = "STIXTwoText-Italic"
    static let supplementalFontsDirectoryHint = "/System/Library/Fonts/Supplemental/"

    // MARK: - Layout tuning

    enum Layout {
        static let subscriptExtraGapEm: CGFloat = 0.06
        static let scriptItalicCorrectionCapEm: CGFloat = 0.2
        static let mopRoundOpenParenHangShaveMu: CGFloat = 3.25
        static let caligraphicCapitalDelimiterKernEm: CGFloat = 0.32
        static let caligraphicScriptCapitalInkSlackEm: CGFloat = 0.18

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

    static func isPrimaryMathFontAvailable(forFontSize size: CGFloat) -> Bool {
        MathFont.backend.isFontAvailable(postScriptName: primaryMathPostScriptName, fontSize: size)
    }

    // MARK: - OpenType math delimiter masters

    static func openTypeMathStretchDelimiterGlyphNames(for character: String) -> [String] {
        guard let base = openTypeMathDelimiterBaseGlyphName(character) else { return [] }
        var names = [base]
        for i in 1...12 {
            names.append("\(base).s\(i)")
        }
        return names
    }

    fileprivate static func horizontalBraceGlyphNameCandidates(isOver: Bool) -> [String] {
        let base = isOver ? "uni23DE" : "uni23DF"
        var names = [base]
        for i in 1...5 {
            names.append("\(base).s\(i)")
        }
        return names
    }

    static func openTypeMatchingDelimiterGlyphName(character: String, templateGlyphName: String?) -> String? {
        guard let template = templateGlyphName, let ownBase = openTypeMathDelimiterBaseGlyphName(character) else {
            return nil
        }
        if let dot = template.lastIndex(of: "."), template[dot...].hasPrefix(".s") {
            return ownBase + String(template[dot...])
        }
        return ownBase
    }

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
        case 0x2016: return "uni2016"
        case 0x2308, 0x2309, 0x230A, 0x230B: return String(format: "uni%04X", v)
        case 0x27E8: return "uni27E8"
        case 0x27E9: return "uni27E9"
        default: return nil
        }
    }

    private static func sizeSymbolPostScriptName(logicalFontName: String) -> String? {
        switch logicalFontName {
        case MathLogicalFontNames.size1Regular: return "STIXSizeOneSym-Regular"
        case MathLogicalFontNames.size2Regular: return "STIXSizeTwoSym-Regular"
        case MathLogicalFontNames.size3Regular: return "STIXSizeThreeSym-Regular"
        case MathLogicalFontNames.size4Regular: return "STIXSizeFourSym-Regular"
        default: return nil
        }
    }

    static func resolvedPostScriptFontName(
        logicalFontName: String,
        character: String,
        textMode: Bool,
        fontSize: CGFloat
    ) -> String {
        let backend = MathFont.backend
        let candidates = postScriptNameCandidates(logicalFontName: logicalFontName, textMode: textMode)
        for ps in candidates {
            guard backend.isFontAvailable(postScriptName: ps, fontSize: fontSize) else { continue }
            if character.isEmpty || backend.hasGlyph(character, postScriptName: ps, fontSize: fontSize) {
                return ps
            }
        }
        return primaryMathPostScriptName
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
        return [primaryMathPostScriptName, textPostScriptName]
    }

    // MARK: - ``\mathcal`` & ``\mathbb``

    private static let mathcalCapitalScalars: [UnicodeScalar] = [
        UnicodeScalar(0x1D49C)!, UnicodeScalar(0x212C)!, UnicodeScalar(0x1D49E)!, UnicodeScalar(0x1D49F)!,
        UnicodeScalar(0x2130)!, UnicodeScalar(0x2131)!, UnicodeScalar(0x1D4A2)!, UnicodeScalar(0x210B)!,
        UnicodeScalar(0x2110)!, UnicodeScalar(0x1D4A5)!, UnicodeScalar(0x1D4A6)!, UnicodeScalar(0x2112)!,
        UnicodeScalar(0x2133)!, UnicodeScalar(0x1D4A9)!, UnicodeScalar(0x1D4AA)!, UnicodeScalar(0x1D4AB)!,
        UnicodeScalar(0x1D4AC)!, UnicodeScalar(0x211B)!, UnicodeScalar(0x1D4AE)!, UnicodeScalar(0x1D4AF)!,
        UnicodeScalar(0x1D4B0)!, UnicodeScalar(0x1D4B1)!, UnicodeScalar(0x1D4B2)!, UnicodeScalar(0x1D4B3)!,
        UnicodeScalar(0x1D4B4)!, UnicodeScalar(0x1D4B5)!,
    ]

    private static let mathcalLowerHoleReplacements: [UInt32: UnicodeScalar] = [
        0x1D4BA: UnicodeScalar(0x212F)!,
        0x1D4BC: UnicodeScalar(0x210A)!,
        0x1D4C4: UnicodeScalar(0x2134)!,
    ]

    static func mathcalMappedLetter(_ character: Character) -> String? {
        if let v = character.unicodeScalars.first?.value, v >= 0x41, v <= 0x5A {
            return String(mathcalCapitalScalars[Int(v - 0x41)])
        }
        if let v = character.unicodeScalars.first?.value, v >= 0x61, v <= 0x7A {
            let code = UInt32(0x1D4B6 + Int(v - 0x61))
            return String(mathcalLowerHoleReplacements[code] ?? UnicodeScalar(code)!)
        }
        return nil
    }

    static func isCaligraphicScriptCapital(_ character: String) -> Bool {
        guard character.unicodeScalars.count == 1, let u = character.unicodeScalars.first?.value else { return false }
        return mathcalCapitalScalars.contains { $0.value == u }
    }

    private static let mathbbCapitalScalars: [UnicodeScalar] = [
        UnicodeScalar(0x1D538)!, UnicodeScalar(0x1D539)!, UnicodeScalar(0x2102)!, UnicodeScalar(0x1D53B)!,
        UnicodeScalar(0x1D53C)!, UnicodeScalar(0x1D53D)!, UnicodeScalar(0x1D53E)!, UnicodeScalar(0x210D)!,
        UnicodeScalar(0x1D540)!, UnicodeScalar(0x1D541)!, UnicodeScalar(0x1D542)!, UnicodeScalar(0x1D543)!,
        UnicodeScalar(0x1D544)!, UnicodeScalar(0x2115)!, UnicodeScalar(0x1D546)!, UnicodeScalar(0x2119)!,
        UnicodeScalar(0x211A)!, UnicodeScalar(0x211D)!, UnicodeScalar(0x1D54A)!, UnicodeScalar(0x1D54B)!,
        UnicodeScalar(0x1D54C)!, UnicodeScalar(0x1D54D)!, UnicodeScalar(0x1D54E)!, UnicodeScalar(0x1D54F)!,
        UnicodeScalar(0x1D550)!, UnicodeScalar(0x2124)!,
    ]

    static func mathbbMappedLetter(_ character: Character) -> String? {
        if let v = character.unicodeScalars.first?.value, v >= 0x41, v <= 0x5A {
            return String(mathbbCapitalScalars[Int(v - 0x41)])
        }
        if let v = character.unicodeScalars.first?.value, v >= 0x61, v <= 0x7A {
            return String(UnicodeScalar(0x1D552 + UInt32(v - 0x61))!)
        }
        if let v = character.unicodeScalars.first?.value, v >= 0x30, v <= 0x39 {
            return String(UnicodeScalar(0x1D7D8 + UInt32(v - 0x30))!)
        }
        return nil
    }

    private static let mathfrakCapitalScalars: [UnicodeScalar] = [
        UnicodeScalar(0x1D504)!, UnicodeScalar(0x1D505)!, UnicodeScalar(0x212D)!, UnicodeScalar(0x1D507)!,
        UnicodeScalar(0x1D508)!, UnicodeScalar(0x1D509)!, UnicodeScalar(0x1D50A)!, UnicodeScalar(0x210C)!,
        UnicodeScalar(0x2111)!, UnicodeScalar(0x1D50D)!, UnicodeScalar(0x1D50E)!, UnicodeScalar(0x1D50F)!,
        UnicodeScalar(0x1D510)!, UnicodeScalar(0x1D511)!, UnicodeScalar(0x1D512)!, UnicodeScalar(0x1D513)!,
        UnicodeScalar(0x1D514)!, UnicodeScalar(0x211C)!, UnicodeScalar(0x1D516)!, UnicodeScalar(0x1D517)!,
        UnicodeScalar(0x1D518)!, UnicodeScalar(0x1D519)!, UnicodeScalar(0x1D51A)!, UnicodeScalar(0x1D51B)!,
        UnicodeScalar(0x1D51C)!, UnicodeScalar(0x2128)!,
    ]

    static func mathfrakMappedLetter(_ character: Character) -> String? {
        if let v = character.unicodeScalars.first?.value, v >= 0x41, v <= 0x5A {
            return String(mathfrakCapitalScalars[Int(v - 0x41)])
        }
        if let v = character.unicodeScalars.first?.value, v >= 0x61, v <= 0x7A {
            return String(UnicodeScalar(0x1D51E + UInt32(v - 0x61))!)
        }
        return nil
    }

    static func openTypeMathWideAccentGlyphNames(for accentCommand: String) -> [String] {
        let base: String
        switch accentCommand {
        case "\\widehat", "\\hat": base = "circumflex"
        case "\\widetilde", "\\tilde": base = "tilde"
        case "\\widecheck", "\\check": base = "caroncomb"
        case "\\overrightarrow", "\\vec": base = "uni20D7"
        case "\\overleftarrow": base = "uni20D6"
        default: return []
        }
        return (1...5).map { "\(base).s\($0)" }
    }
}

// MARK: - ``\overbrace`` / ``\underbrace``

extension STIX {
    static func makeHorizontalBraceLayout(
        provider: any MathFontProviding,
        isOver: Bool,
        layoutWidth: CGFloat,
        bodyFontSize: CGFloat,
        mathFont _: MathFontIdentifier
    ) -> MathFontHorizontalBraceLayout {
        let character = isOver ? "\u{23DE}" : "\u{23DF}"
        let logical = MathLogicalFontNames.mainRegular
        let psName = provider.resolvedPostScriptFontName(
            logicalFontName: logical,
            character: character,
            textMode: false,
            fontSize: bodyFontSize
        )
        let backend = MathFont.backend
        let maxScale = provider.delimiterSizing.leftRightMaxExtraScale

        if provider.isPrimaryMathFontAvailable(forFontSize: bodyFontSize) {
            let names = horizontalBraceGlyphNameCandidates(isOver: isOver).filter {
                backend.hasOpenTypeGlyph(named: $0, postScriptName: psName, fontSize: bodyFontSize)
            }
            if !names.isEmpty {
                func inkMetrics(_ gn: String) -> (w: CGFloat, bbox: CGRect)? {
                    guard
                        let m = backend.measureGlyph(
                            postScriptName: psName,
                            character: character,
                            fontSize: bodyFontSize,
                            openTypeGlyphName: gn,
                            isCaligraphicCapital: false,
                            inkSlackPt: 0,
                            isItalicSlot: false
                        )
                    else { return nil }
                    return (max(m.boundingBox.width, m.advanceWidth), m.boundingBox)
                }

                var pick: (name: String, w: CGFloat)?
                for name in names {
                    if let m = inkMetrics(name), m.w * maxScale >= layoutWidth - 0.25 {
                        pick = (name, m.w)
                        break
                    }
                }
                if pick == nil, let last = names.last, let m = inkMetrics(last) {
                    pick = (last, m.w)
                }
                if let (glyphName, w0) = pick {
                    let scale = min(maxScale, layoutWidth / max(w0, 0.0001))
                    let effectiveFontSize = bodyFontSize * scale
                    if let mDraw = backend.measureGlyph(
                        postScriptName: psName,
                        character: character,
                        fontSize: effectiveFontSize,
                        openTypeGlyphName: glyphName,
                        isCaligraphicCapital: false,
                        inkSlackPt: 0,
                        isItalicSlot: false
                    ) {
                        let bbox = mDraw.boundingBox
                        let cx = (bbox.minX + bbox.maxX) / 2
                        return MathFontHorizontalBraceLayout(
                            drawString: character,
                            logicalFontName: logical,
                            pointSize: effectiveFontSize,
                            coreTextGlyphName: glyphName,
                            layoutWidth: layoutWidth,
                            height: bbox.maxY,
                            depth: -bbox.minY,
                            textOriginOffsetX: layoutWidth / 2 - cx
                        )
                    }
                }
            }
        }

        // Fallback to cmap glyph
        guard
            let m0 = backend.measureGlyph(
                postScriptName: psName,
                character: character,
                fontSize: bodyFontSize,
                openTypeGlyphName: nil,
                isCaligraphicCapital: false,
                inkSlackPt: 0,
                isItalicSlot: false
            )
        else {
            return MathFontHorizontalBraceLayout(
                drawString: character,
                logicalFontName: logical,
                pointSize: bodyFontSize,
                coreTextGlyphName: nil,
                layoutWidth: layoutWidth,
                height: 0,
                depth: 0,
                textOriginOffsetX: layoutWidth / 2
            )
        }
        let w0 = max(m0.boundingBox.width, m0.advanceWidth)
        let scale = min(maxScale, layoutWidth / max(w0, 0.0001))
        let effective = bodyFontSize * scale
        let mDraw = backend.measureGlyph(
            postScriptName: psName,
            character: character,
            fontSize: effective,
            openTypeGlyphName: nil,
            isCaligraphicCapital: false,
            inkSlackPt: 0,
            isItalicSlot: false
        ) ?? m0
        let bbox = mDraw.boundingBox
        let cx = (bbox.minX + bbox.maxX) / 2
        return MathFontHorizontalBraceLayout(
            drawString: character,
            logicalFontName: logical,
            pointSize: effective,
            coreTextGlyphName: nil,
            layoutWidth: layoutWidth,
            height: bbox.maxY,
            depth: -bbox.minY,
            textOriginOffsetX: layoutWidth / 2 - cx
        )
    }
}

/// Default backend: STIX Two Math / Text.
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

    public var delimiterSizing: DelimiterSizing { STIX.Layout.delimiterSizing }
    public var primaryMathPostScriptName: String { STIX.primaryMathPostScriptName }
    public var supplementalFontsDirectoryHint: String { STIX.supplementalFontsDirectoryHint }

    public func resolvedPostScriptFontName(
        logicalFontName: String,
        character: String,
        textMode: Bool,
        fontSize: CGFloat
    ) -> String {
        STIX.resolvedPostScriptFontName(
            logicalFontName: logicalFontName,
            character: character,
            textMode: textMode,
            fontSize: fontSize
        )
    }

    public func isPrimaryMathFontAvailable(forFontSize size: CGFloat) -> Bool {
        STIX.isPrimaryMathFontAvailable(forFontSize: size)
    }

    public func mathcalMappedLetter(_ character: Character) -> String? { STIX.mathcalMappedLetter(character) }

    public func isCaligraphicScriptCapital(character: String, logicalFontName _: String) -> Bool {
        STIX.isCaligraphicScriptCapital(character)
    }

    public func mathbbMappedLetter(_ character: Character) -> String? { STIX.mathbbMappedLetter(character) }

    public func mathfrakMappedLetter(_ character: Character) -> String? { STIX.mathfrakMappedLetter(character) }

    public func openTypeMathStretchDelimiterGlyphNames(for character: String) -> [String] {
        STIX.openTypeMathStretchDelimiterGlyphNames(for: character)
    }

    public func openTypeMatchingStretchDelimiterGlyphName(character: String, templateGlyphName: String?) -> String? {
        STIX.openTypeMatchingDelimiterGlyphName(character: character, templateGlyphName: templateGlyphName)
    }

    public func openTypeMathWideAccentGlyphNames(for accentCommand: String) -> [String] {
        STIX.openTypeMathWideAccentGlyphNames(for: accentCommand)
    }

    public func openTypeGlyphName(logicalFontName: String, character: String, textMode: Bool) -> String? {
        FeiMath.openTypeGlyphName(logicalFontName: logicalFontName, character: character, textMode: textMode)
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
