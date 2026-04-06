import Foundation

/// TeX-style **logical** font slot names. The layout engine uses these strings; each ``MathFontProviding``
/// maps them to real typefaces (e.g. STIX in ``STIX``).
public enum MathLogicalFontNames {
    public static let mainRegular = "Main-Regular"
    public static let mainItalic = "Main-Italic"
    public static let mainBold = "Main-Bold"
    public static let mathItalic = "Math-Italic"
    public static let amsRegular = "AMS-Regular"
    public static let caligraphicRegular = "Caligraphic-Regular"
    public static let typewriterRegular = "Typewriter-Regular"
    public static let sansSerifRegular = "SansSerif-Regular"

    public static let size1Regular = "Size1-Regular"
    public static let size2Regular = "Size2-Regular"
    public static let size3Regular = "Size3-Regular"
    public static let size4Regular = "Size4-Regular"

    /// Matches `SansSerif-Regular`, `SansSerif-Italic`, etc.
    public static let sansSerifFamilyMarker = "SansSerif"

    /// Matches `Size1-Regular` … `Size4-Regular`.
    public static let sizeFamilyPrefix = "Size"

    /// Matches `Main-Bold`, `Math-BoldItalic`, etc.
    public static let boldFaceMarker = "-Bold"

    /// Rare slot checked when mapping logical names to faces (see ``STIX``).
    public static let boldsymbolSlot = "boldsymbol"
}
