import Foundation

/// Selects a registered math font backend (see ``MathFontRegistry`` / ``MathFont``).
public struct MathFontIdentifier: Hashable, Sendable, Codable, RawRepresentable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    /// System **STIX Two** on macOS (default).
    public static let stix = MathFontIdentifier(rawValue: "stix")

    /// Bundled **Gaegu Math** (`GaeguMath-Regular.ttf`).
    public static let gaeguMath = MathFontIdentifier(rawValue: "gaeguMath")

    /// Alias for ``gaeguMath``.
    public static let gaegu = MathFontIdentifier.gaeguMath
}
