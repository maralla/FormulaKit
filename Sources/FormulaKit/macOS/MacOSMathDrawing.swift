#if os(macOS)
import AppKit
import CoreGraphics
import CoreText
import Foundation

extension MathPath {
    /// Converts this ``MathPath`` to a Core Graphics ``CGPath``.
    public var cgPath: CGPath {
        let path = CGMutablePath()
        for el in elements {
            switch el {
            case .moveTo(let p):
                path.move(to: p)
            case .lineTo(let p):
                path.addLine(to: p)
            case .quadTo(let c, let p):
                path.addQuadCurve(to: p, control: c)
            case .closeSubpath:
                path.closeSubpath()
            }
        }
        return path
    }
}

extension MathCompositeLayout {
    /// Fills ``decorationPath`` then draws ``textRuns`` with Core Text.
    ///
    /// **Coordinate system:** math layout space (y up), same as ``textRuns`` / ``rootBox``.
    public func drawMath(in cgContext: CGContext, textColor: NSColor = .black) {
        let textCGColor = textColor.cgColor
        cgContext.saveGState()
        defer { cgContext.restoreGState() }

        cgContext.setFillColor(textCGColor)
        cgContext.addPath(decorationPath.cgPath)
        cgContext.fillPath()

        for run in textRuns {
            let ctFont = SymbolNode.ctFontForMathGlyph(
                fontName: run.fontName,
                character: run.string,
                fontSize: run.fontSize,
                metricsTextMode: run.metricsTextMode,
                mathFont: mathFont
            )
            var attrs: [NSAttributedString.Key: Any] = [
                .font: ctFont as NSFont,
                kCTForegroundColorAttributeName as NSAttributedString.Key: textCGColor,
            ]
            if let gn = run.openTypeMathGlyphName,
                let glyphInfo = CTGlyphInfoCreateWithGlyphName(gn as CFString, ctFont, run.string as CFString)
            {
                attrs[kCTGlyphInfoAttributeName as NSAttributedString.Key] = glyphInfo
            }
            let line = CTLineCreateWithAttributedString(
                NSAttributedString(string: run.string, attributes: attrs) as CFAttributedString
            )
            cgContext.textPosition = CGPoint(x: run.baselineOrigin.x, y: run.baselineOrigin.y)
            CTLineDraw(line, cgContext)
        }
    }
}
#endif
