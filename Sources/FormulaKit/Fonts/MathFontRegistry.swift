import Foundation

/// Default font metric estimator used when no custom ``MathFontBackend`` is installed.
struct FallbackMathFontBackend: MathFontBackend {
    func isFontAvailable(postScriptName _: String, fontSize _: CGFloat) -> Bool { true }
    func hasGlyph(_ character: String, postScriptName _: String, fontSize _: CGFloat) -> Bool { !character.isEmpty }
    func hasOpenTypeGlyph(named glyphName: String, postScriptName _: String, fontSize _: CGFloat) -> Bool {
        !glyphName.hasPrefix("bar.s") && !glyphName.hasPrefix("uni2016.s")
    }

    func measureGlyph(
        postScriptName _: String,
        character: String,
        fontSize: CGFloat,
        openTypeGlyphName: String?,
        isCaligraphicCapital: Bool,
        inkSlackPt: CGFloat,
        isItalicSlot: Bool
    ) -> MathGlyphMetrics? {
        guard !character.isEmpty else { return nil }
        var step = 0
        if let gn = openTypeGlyphName, let dot = gn.lastIndex(of: "."), gn[dot...].hasPrefix(".s") {
            step = Int(gn[gn.index(dot, offsetBy: 2)...]) ?? 1
        }
        if let gn = openTypeGlyphName, gn.contains("23DE") || gn.contains("23DF") {
            let w = fontSize * (0.63 + CGFloat(step) * 0.85)
            let isOver = gn.contains("23DE")
            let bbox = isOver
                ? CGRect(x: 0, y: fontSize * 0.58, width: w, height: fontSize * 0.24)
                : CGRect(x: 0, y: -fontSize * 0.30, width: w, height: fontSize * 0.24)
            return MathGlyphMetrics(advanceWidth: w, boundingBox: bbox, inkRight: w)
        }
        if step > 0 {
            let h = fontSize * (0.95 + CGFloat(step) * 0.32)
            let w = fontSize * 0.42
            let bbox = CGRect(x: fontSize * 0.04, y: fontSize * 0.25 - h * 0.5, width: w * 0.8, height: h)
            return MathGlyphMetrics(advanceWidth: w, boundingBox: bbox, inkRight: w)
        }
        let adv = fontSize * (isCaligraphicCapital ? 0.72 : 0.52)
        let h = fontSize * 0.68
        let d: CGFloat = ["g", "j", "p", "q", "y", "(", ")", "[", "]", "{", "}", "∫", "∑", "∏"].contains(character)
            ? fontSize * 0.22
            : 0
        let bbox = CGRect(x: fontSize * 0.03, y: -d, width: adv * 0.9, height: h + d)
        let italicExtra = isItalicSlot ? fontSize * 0.04 : 0
        let inkRight = adv + italicExtra + (isCaligraphicCapital ? inkSlackPt : 0)
        let leftHang: CGFloat = character == "(" ? fontSize * 0.02 : 0
        return MathGlyphMetrics(advanceWidth: adv, boundingBox: bbox, inkRight: inkRight, leftHang: leftHang)
    }
}

/// Registry of ``MathFontProviding`` backends. **STIX** and **Gaegu Math** are registered by default.
public final class MathFontRegistry: @unchecked Sendable {
    public static let shared = MathFontRegistry()

    private let lock = NSLock()
    private var providers: [MathFontIdentifier: any MathFontProviding] = [:]
    private var _backend: any MathFontBackend

    /// Used when ``FormulaKit/Options/mathFont`` is missing from the registry.
    public var defaultIdentifier: MathFontIdentifier

    public var backend: any MathFontBackend {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _backend
        }
        set {
            lock.lock()
            _backend = newValue
            lock.unlock()
        }
    }

    private init() {
        #if os(macOS)
        _backend = MacOSCoreTextFontBackend()
        #else
        _backend = FallbackMathFontBackend()
        #endif
        defaultIdentifier = .stix
        register(STIXMathFontProvider())
        register(GaeguMathFontProvider())
    }

    /// Registers or replaces a provider for its ``MathFontProviding/identifier``.
    public func register(_ provider: some MathFontProviding) {
        lock.lock()
        providers[provider.identifier] = provider
        lock.unlock()
    }

    public func provider(for id: MathFontIdentifier) -> (any MathFontProviding)? {
        lock.lock()
        defer { lock.unlock() }
        return providers[id]
    }

    public func resolvedProvider(for id: MathFontIdentifier) -> any MathFontProviding {
        lock.lock()
        let chosen = providers[id] ?? providers[defaultIdentifier]
        lock.unlock()
        guard let chosen else {
            preconditionFailure(
                "FormulaKit: no math font provider registered; call MathFont.register(_:) before rendering."
            )
        }
        return chosen
    }
}
