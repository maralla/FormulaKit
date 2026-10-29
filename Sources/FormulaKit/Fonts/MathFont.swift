import Foundation

/// Namespace for math font registration and resolution (see ``MathFontRegistry``).
public enum MathFont {
    /// Active font measurement backend.
    public static var backend: any MathFontBackend {
        get { MathFontRegistry.shared.backend }
        set { MathFontRegistry.shared.backend = newValue }
    }

    /// Registers or replaces a provider. Use a unique ``MathFontIdentifier`` per backend.
    public static func register(_ provider: some MathFontProviding) {
        MathFontRegistry.shared.register(provider)
    }

    public static var defaultIdentifier: MathFontIdentifier {
        get { MathFontRegistry.shared.defaultIdentifier }
        set { MathFontRegistry.shared.defaultIdentifier = newValue }
    }

    public static func resolvedProvider(for id: MathFontIdentifier) -> any MathFontProviding {
        MathFontRegistry.shared.resolvedProvider(for: id)
    }

    public static func provider(for id: MathFontIdentifier) -> (any MathFontProviding)? {
        MathFontRegistry.shared.provider(for: id)
    }

    // MARK: - Diagnostics (default registry font)

    public static func isPrimaryMathFontAvailable(forFontSize size: CGFloat) -> Bool {
        MathFontRegistry.shared.resolvedProvider(for: MathFontRegistry.shared.defaultIdentifier)
            .isPrimaryMathFontAvailable(forFontSize: size)
    }

    public static var primaryMathPostScriptName: String {
        MathFontRegistry.shared.resolvedProvider(for: MathFontRegistry.shared.defaultIdentifier)
            .primaryMathPostScriptName
    }

    public static var supplementalFontsDirectoryHint: String {
        MathFontRegistry.shared.resolvedProvider(for: MathFontRegistry.shared.defaultIdentifier)
            .supplementalFontsDirectoryHint
    }
}

extension FormulaKit.Options {
    /// Active math font backend for this render (must be ``MathFont/register(_:)``-ed).
    public var resolvedMathFont: any MathFontProviding {
        MathFontRegistry.shared.resolvedProvider(for: mathFont)
    }
}
