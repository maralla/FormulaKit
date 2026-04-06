import Foundation

/// Registry of ``MathFontProviding`` backends. **STIX** is registered by default.
public final class MathFontRegistry: @unchecked Sendable {
    public static let shared = MathFontRegistry()

    private let lock = NSLock()
    private var providers: [MathFontIdentifier: any MathFontProviding] = [:]

    /// Used when ``FormulaKit/Options/mathFont`` is missing from the registry.
    public var defaultIdentifier: MathFontIdentifier

    private init() {
        defaultIdentifier = .stix
        register(STIXMathFontProvider())
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
