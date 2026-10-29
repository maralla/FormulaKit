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

    /// Bundled **Fei Math** (`FeiMath-Regular.ttf`).
    public static let feiMath = MathFontIdentifier(rawValue: "feiMath")

    /// Alias for ``feiMath``.
    public static let fei = MathFontIdentifier.feiMath
}
