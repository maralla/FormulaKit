import Foundation

/// Bundled **Gaegu Math** (`GaeguMath-Regular.ttf`) OpenType math backend.
public enum GaeguMath {
    public static let primaryMathPostScriptName = "GaeguMath-Regular"
    public static let resourceName = "GaeguMath-Regular"
    public static let resourceExtension = "ttf"
    public static let supplementalFontsDirectoryHint = "Bundle.module (Resources/GaeguMath-Regular.ttf)"

    /// URL of the bundled `GaeguMath-Regular.ttf` resource inside the package.
    public static var bundledFontURL: URL? {
        Bundle.module.url(forResource: resourceName, withExtension: resourceExtension)
    }

    static let layoutTuning = MathFontLayoutTuning(
        subscriptExtraGapEm: 0.06,
        scriptItalicCorrectionCapEm: 0.2,
        mopRoundOpenParenHangShaveMu: 3.25,
        caligraphicCapitalDelimiterKernEm: 0.32,
        caligraphicScriptCapitalInkSlackEm: 0.18,
        fractionRuleThicknessEm: 0.068,
        radicalRuleThicknessEm: 0.074,
        radicalVinculumJoinKernEm: -0.015
    )

    static let delimiterSizing = STIX.Layout.delimiterSizing

    static func isPrimaryMathFontAvailable(forFontSize size: CGFloat) -> Bool {
        MathFont.backend.isFontAvailable(postScriptName: primaryMathPostScriptName, fontSize: size)
    }

    // MARK: - OpenType Glyph Name Mapping

    static func openTypeGlyphName(logicalFontName: String, character: String, textMode: Bool) -> String? {
        guard !textMode, character.count == 1, let v = character.unicodeScalars.first?.value else { return nil }
        switch logicalFontName {
        case MathLogicalFontNames.mathItalic, MathLogicalFontNames.mainItalic:
            if v >= 0x41 && v <= 0x5A { return String(format: "u%04X", 0x1D434 + (v - 0x41)) }
            if v >= 0x61 && v <= 0x7A { return v == 0x68 ? "uni210E" : String(format: "u%04X", 0x1D44E + (v - 0x61)) }
            if v >= 0x03B1 && v <= 0x03C9 { return String(format: "u%04X", 0x1D6FC + (v - 0x03B1)) }
            let itMap: [UInt32: String] = [
                0x2202: "u1D715", 0x03F5: "u1D716", 0x03D1: "u1D717", 0x03F0: "u1D718",
                0x03D5: "u1D719", 0x03F1: "u1D71A", 0x03D6: "u1D71B",
            ]
            return itMap[v]

        case MathLogicalFontNames.mainBold, MathLogicalFontNames.boldsymbolSlot,
            _ where logicalFontName.contains(MathLogicalFontNames.boldFaceMarker):
            if v >= 0x41 && v <= 0x5A { return String(format: "u%04X", 0x1D400 + (v - 0x41)) }
            if v >= 0x61 && v <= 0x7A { return String(format: "u%04X", 0x1D41A + (v - 0x61)) }
            if v >= 0x30 && v <= 0x39 { return String(format: "u%04X", 0x1D7CE + (v - 0x30)) }
            if v >= 0x0391 && v <= 0x03A9 && v != 0x03A2 { return String(format: "u%04X", 0x1D6A8 + (v - 0x0391)) }
            if v >= 0x03B1 && v <= 0x03C9 { return String(format: "u%04X", 0x1D736 + (v - 0x03B1)) }
            let bfMap: [UInt32: String] = [
                0x2207: "u1D6C1", 0x2202: "u1D74F", 0x03F5: "u1D750", 0x03D1: "u1D751",
                0x03F0: "u1D752", 0x03D5: "u1D753", 0x03F1: "u1D754", 0x03D6: "u1D755",
            ]
            return bfMap[v]

        case MathLogicalFontNames.sansSerifRegular,
            _ where logicalFontName.contains(MathLogicalFontNames.sansSerifFamilyMarker):
            if v >= 0x41 && v <= 0x5A { return String(format: "u%04X", 0x1D5A0 + (v - 0x41)) }
            if v >= 0x61 && v <= 0x7A { return String(format: "u%04X", 0x1D5BA + (v - 0x61)) }
            if v >= 0x30 && v <= 0x39 { return String(format: "u%04X", 0x1D7E2 + (v - 0x30)) }
            return nil

        case MathLogicalFontNames.typewriterRegular:
            if v >= 0x41 && v <= 0x5A { return String(format: "u%04X", 0x1D670 + (v - 0x41)) }
            if v >= 0x61 && v <= 0x7A { return String(format: "u%04X", 0x1D68A + (v - 0x61)) }
            if v >= 0x30 && v <= 0x39 { return String(format: "u%04X", 0x1D7F6 + (v - 0x30)) }
            return nil

        case MathLogicalFontNames.size1Regular:
            return sizeSlotGlyphName(forScalar: v, character: character, sizeTier: 1)
        case MathLogicalFontNames.size2Regular:
            return sizeSlotGlyphName(forScalar: v, character: character, sizeTier: 2)
        case MathLogicalFontNames.size3Regular:
            return sizeSlotGlyphName(forScalar: v, character: character, sizeTier: 3)
        case MathLogicalFontNames.size4Regular:
            return sizeSlotGlyphName(forScalar: v, character: character, sizeTier: 4)
        case MathLogicalFontNames.mainRegular:
            return v == 0x002D ? "uni2212" : nil
        default:
            return nil
        }
    }

    private static func sizeSlotGlyphName(forScalar v: UInt32, character: String, sizeTier: Int) -> String? {
        if v == 0x221A { return "uni221A.s\(min(max(sizeTier, 1), 3))" }
        let dspMap: [UInt32: String] = [
            0x2211: "uni2211.s1", 0x220F: "uni220F.s1", 0x2210: "uni2210.s1",
            0x222B: "uni222B.dsp", 0x222C: "uni222C.dsp", 0x222D: "uni222D.dsp", 0x222E: "uni222E.dsp",
            0x22C0: "uni22C0.s1", 0x22C1: "uni22C1.s1", 0x22C2: "uni22C2.s1", 0x22C3: "uni22C3.s1",
            0x2A00: "uni2A00.s1", 0x2A01: "uni2A01.s1", 0x2A02: "uni2A02.s1",
            0x2A04: "uni2A04.s1", 0x2A06: "uni2A06.s1",
        ]
        if let op = dspMap[v] { return op }
        let candidates = STIX.openTypeMathStretchDelimiterGlyphNames(for: character)
        if candidates.count > 1 {
            let step = min(sizeTier * 2, candidates.count - 1)
            let candidate = candidates[step]
            if candidate != "bar.s\(step)" && candidate != "uni2016.s\(step)" { return candidate }
        }
        return nil
    }

    // MARK: - Hand-Drawn Rule Rendering

    static func renderRulePath(rect: CGRect, role: MathRuleRole) -> MathPath {
        guard rect.width > 0.1, rect.height > 0.1 else { return MathPath(rect: rect) }
        let h = rect.height, w = rect.width, cy0 = rect.midY
        let seedVal = Int(round(w * 7.0 + abs(cy0) * 3.0))
        let sign1: CGFloat = (seedVal % 2 == 0) ? 1.0 : -1.0
        let sign2: CGFloat = ((seedVal / 2) % 2 == 0) ? 1.0 : -1.0
        let isVinculum = (role == .radicalVinculum)
        let rBase = h * (isVinculum ? 0.46 : 0.48)
        let xStart = isVinculum ? rect.minX : (rect.minX + rBase)
        let xEnd = max(xStart + 0.1, rect.maxX - rBase)
        let spanW = xEnd - xStart
        let arcAmp = min(h * 0.55, spanW * 0.013)
        let tiltAmp = min(h * 0.28, spanW * 0.006)
        let nSteps = max(12, min(40, Int(ceil(spanW / 3.0))))

        func sample(_ t: CGFloat) -> (x: CGFloat, y: CGFloat, r: CGFloat) {
            let x = xStart + t * spanW
            let arch = 4.0 * t * (1.0 - t)
            if isVinculum {
                let env = t * t * (1.5 - 0.5 * t)
                let dy = env * (sign1 * arcAmp * arch + sign2 * tiltAmp * (t - 0.35))
                let r = h * (0.50 - 0.04 * env + 0.025 * sin(CGFloat.pi * t) * env)
                return (x, cy0 + dy, r)
            } else {
                let asym = t * (1.0 - t) * (1.0 - 2.0 * t)
                let dy = sign1 * arcAmp * arch + sign2 * tiltAmp * (t - 0.5) + sign1 * (arcAmp * 0.35) * asym
                let r = rBase * (1.0 + 0.05 * sin(CGFloat.pi * t))
                return (x, cy0 + dy, r)
            }
        }

        var path = MathPath()
        var topPts: [CGPoint] = [], botPts: [CGPoint] = []
        for i in 0...nSteps {
            let (x, cy, r) = sample(CGFloat(i) / CGFloat(nSteps))
            topPts.append(CGPoint(x: x, y: cy + r))
            botPts.append(CGPoint(x: x, y: cy - r))
        }
        path.move(to: topPts[0])
        for i in 1...nSteps { path.addLine(to: topPts[i]) }
        let (cxR, cyR, rR) = sample(1.0)
        for j in 1..<8 {
            let ang = (CGFloat.pi / 2.0) - CGFloat(j) * (CGFloat.pi / 8.0)
            path.addLine(to: CGPoint(x: cxR + rR * cos(ang), y: cyR + rR * sin(ang)))
        }
        for i in (0...nSteps).reversed() { path.addLine(to: botPts[i]) }
        if !isVinculum {
            let (cxL, cyL, rL) = sample(0.0)
            for j in 1..<8 {
                let ang = (-CGFloat.pi / 2.0) - CGFloat(j) * (CGFloat.pi / 8.0)
                path.addLine(to: CGPoint(x: cxL + rL * cos(ang), y: cyL + rL * sin(ang)))
            }
        }
        path.closeSubpath()
        return path
    }
}

/// Bundled **Gaegu Math** (`GaeguMath-Regular.ttf`) backend.
public struct GaeguMathFontProvider: MathFontProviding {
    public init() {}
    public let identifier = MathFontIdentifier.gaeguMath
    public var layout: MathFontLayoutTuning { GaeguMath.layoutTuning }
    public var delimiterSizing: DelimiterSizing { GaeguMath.delimiterSizing }
    public var primaryMathPostScriptName: String { GaeguMath.primaryMathPostScriptName }
    public var supplementalFontsDirectoryHint: String { GaeguMath.supplementalFontsDirectoryHint }

    public func resolvedPostScriptFontName(
        logicalFontName _: String,
        character _: String,
        textMode _: Bool,
        fontSize _: CGFloat
    ) -> String {
        GaeguMath.primaryMathPostScriptName
    }

    public func isPrimaryMathFontAvailable(forFontSize size: CGFloat) -> Bool {
        GaeguMath.isPrimaryMathFontAvailable(forFontSize: size)
    }

    public func mathcalMappedLetter(_ character: Character) -> String? { STIX.mathcalMappedLetter(character) }

    public func isCaligraphicScriptCapital(character: String, logicalFontName _: String) -> Bool {
        STIX.isCaligraphicScriptCapital(character)
    }

    public func mathbbMappedLetter(_ character: Character) -> String? { STIX.mathbbMappedLetter(character) }

    public func openTypeMathStretchDelimiterGlyphNames(for character: String) -> [String] {
        STIX.openTypeMathStretchDelimiterGlyphNames(for: character)
    }

    public func openTypeMatchingStretchDelimiterGlyphName(character: String, templateGlyphName: String?) -> String? {
        STIX.openTypeMatchingDelimiterGlyphName(character: character, templateGlyphName: templateGlyphName)
    }

    public func openTypeGlyphName(logicalFontName: String, character: String, textMode: Bool) -> String? {
        GaeguMath.openTypeGlyphName(logicalFontName: logicalFontName, character: character, textMode: textMode)
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

    public func renderRulePath(rect: CGRect, role: MathRuleRole, options _: FormulaKit.Options) -> MathPath {
        GaeguMath.renderRulePath(rect: rect, role: role)
    }
}
