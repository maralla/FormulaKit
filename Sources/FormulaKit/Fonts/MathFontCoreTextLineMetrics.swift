import CoreGraphics
import CoreText
import Foundation

#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit

private typealias PlatformLineFont = NSFont
#elseif canImport(UIKit)
import UIKit

private typealias PlatformLineFont = UIFont
#endif

/// Core Text line bounds shared by all math fonts (not tied to a specific typeface).
enum MathFontCoreTextLineMetrics {
    private static func attributedLine(character: String, font: CTFont) -> CTLine {
        let platformFont = font as PlatformLineFont
        let attrs: [NSAttributedString.Key: Any] = [.font: platformFont]
        return CTLineCreateWithAttributedString(NSAttributedString(string: character, attributes: attrs))
    }

    /// Sum of ``CTRunGetAdvances`` widths — can differ from ``CTFontGetAdvancesForGlyphs`` for some OpenType math glyphs.
    static func totalRunAdvanceWidth(character: String, font: CTFont) -> CGFloat {
        guard !character.isEmpty else { return 0 }
        let line = attributedLine(character: character, font: font)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return 0 }
        var total: CGFloat = 0
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            var advances = [CGSize](repeating: .zero, count: count)
            CTRunGetAdvances(run, CFRangeMake(0, count), &advances)
            for a in advances { total += a.width }
        }
        return total
    }

    static func glyphPathBoundsMaxX(character: String, font: CTFont) -> CGFloat {
        guard !character.isEmpty else { return 0 }
        let line = attributedLine(character: character, font: font)
        let b = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        return b.maxX
    }

    static func opticalBoundsMaxX(character: String, font: CTFont) -> CGFloat {
        guard !character.isEmpty else { return 0 }
        let line = attributedLine(character: character, font: font)
        let b = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        return b.maxX
    }

    /// Ink extent left of the line origin (positive = hang), for a single-character line.
    static func drawingLeftHangPt(character: String, font: CTFont) -> CGFloat {
        guard character.count == 1 else { return 0 }
        let line = attributedLine(character: character, font: font)
        let bPath = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let bOpt = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        let left = min(bPath.minX, bOpt.minX)
        return max(0, -left)
    }
}
