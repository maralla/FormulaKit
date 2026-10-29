import Foundation
import XCTest

@testable import FormulaKit

#if os(macOS)
import AppKit
import CoreGraphics
import CoreText
#endif

final class FormulaKitTests: XCTestCase {

    // MARK: - Version Tests

    func testVersion() {
        XCTAssertEqual(FormulaKit.version, "0.1.0")
    }

    // MARK: - Empty Input Tests

    func testEmptyExpressionWithThrowOnErrorEnabled() throws {
        let options = FormulaKit.Options(throwOnError: true)
        let layout = try FormulaKit.render("", options: options)
        XCTAssertTrue(layout.rootBox.width == 0 && layout.rootBox.height == 0 && layout.rootBox.depth == 0)
        XCTAssertTrue(layout.textRuns.isEmpty)
        XCTAssertTrue(layout.decorationPath.boundingBoxOfPath.isEmpty)
    }

    func testEmptyExpressionWithThrowOnErrorDisabled() {
        let options = FormulaKit.Options(throwOnError: false)

        do {
            let result = try FormulaKit.render("", options: options)
            XCTAssertNotNil(result)
        } catch {
            XCTFail("Should not throw with throwOnError disabled")
        }
    }

    // MARK: - Parse Tests

    func testParse() {
        do {
            let parseTree = try FormulaKit.parse("x^2")
            XCTAssertNotNil(parseTree)
        } catch {
            XCTFail("Parsing should succeed: \(error)")
        }
    }

    func testParseInvalidExpression() {
        let result = try? FormulaKit.parse("\\invalid")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, .root)
        XCTAssertFalse(result?.children.isEmpty ?? true)

        if let firstChild = result?.children.first {
            XCTAssertEqual(firstChild.type, .function)
            XCTAssertEqual(firstChild.value, "invalid")
        } else {
            XCTFail("Expected at least one child node")
        }
    }

    // MARK: - Render Tests

    func testRenderSimpleExpression() {
        do {
            let layout = try FormulaKit.render("x^2")
            XCTAssertFalse(layout.textRuns.isEmpty, "x^2 should emit text runs")
            XCTAssertGreaterThan(layout.rootBox.width, 0)
        } catch {
            XCTFail("Rendering should succeed: \(error)")
        }
    }

    func testRenderInvalidExpressionWithThrowOnErrorEnabled() {
        let options = FormulaKit.Options(throwOnError: true)
        let result = try? FormulaKit.render("\\invalid", options: options)
        XCTAssertNotNil(result)
    }

    func testRenderInvalidExpressionWithThrowOnErrorDisabled() {
        let options = FormulaKit.Options(throwOnError: false, errorColor: "#cc0000")

        do {
            let result = try FormulaKit.render("\\invalid", options: options)
            XCTAssertNotNil(result)
        } catch {
            XCTFail("Should not throw with throwOnError disabled")
        }
    }

    // MARK: - Options Tests

    func testDefaultOptions() {
        let defaultOptions = FormulaKit.Options.default

        XCTAssertFalse(defaultOptions.throwOnError)
        XCTAssertEqual(defaultOptions.errorColor, "#cc0000")
        XCTAssertEqual(defaultOptions.mathFont, .stix)
    }

    func testCustomOptions() {
        let customOptions = FormulaKit.Options(throwOnError: true, errorColor: "#ff0000")

        XCTAssertTrue(customOptions.throwOnError)
        XCTAssertEqual(customOptions.errorColor, "#ff0000")
    }

    // MARK: - Render (system text + decoration path)

    func testRender_glyphsAsRunsFractionHasDecoration() throws {
        let layout = try FormulaKit.render(#"\frac{a}{b}"#)
        XCTAssertFalse(layout.textRuns.isEmpty)
        let joined = layout.textRuns.map(\.string).joined()
        XCTAssertTrue(joined.contains("a"))
        XCTAssertTrue(joined.contains("b"))
        XCTAssertFalse(layout.decorationPath.boundingBoxOfPath.isEmpty, "fraction bar should be a non-empty path")
        XCTAssertGreaterThan(layout.rootBox.width, 0)
    }

    func testRender_simpleVariable() throws {
        let layout = try FormulaKit.render("x")
        XCTAssertEqual(layout.textRuns.count, 1)
        XCTAssertEqual(layout.textRuns[0].string, "x")
        XCTAssertTrue(layout.decorationPath.boundingBoxOfPath.isEmpty)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
    }

    /// `\quad` must be 1em space; previously the renderer emitted the four letters "quad".
    func testRender_quadHorizontalSpace() throws {
        let spaced = try FormulaKit.render(#"a\quad b"#)
        let tight = try FormulaKit.render("ab")
        XCTAssertGreaterThan(spaced.rootBox.width, tight.rootBox.width + 8)
        let letters = spaced.textRuns.map(\.string).joined()
        XCTAssertFalse(letters.contains("q"))
        XCTAssertFalse(letters.contains("u"))
    }

    /// `\,` / `\!` are mu-based glue, not punctuation glyphs.
    func testRender_thinspaceAndNegThinspace() throws {
        let thin = try FormulaKit.render(#"a\,b"#)
        let neg = try FormulaKit.render(#"a\!b"#)
        let none = try FormulaKit.render("ab")
        XCTAssertGreaterThan(thin.rootBox.width, none.rootBox.width)
        XCTAssertLessThan(neg.rootBox.width, thin.rootBox.width)
        let joined = thin.textRuns.map(\.string).joined()
        XCTAssertFalse(joined.contains(","))
    }

    func testRender_operatornameUprightNoItalics() throws {
        let layout = try FormulaKit.render(#"\operatorname{span}"#)
        let joined = layout.textRuns.map(\.string).joined()
        XCTAssertTrue(joined.contains("s"))
        XCTAssertTrue(joined.contains("p"))
    }

    /// Multi-letter `\tanh` is `.mop` upright letters; the last glyph’s serif ic must not space `(` like math italic.
    func testRender_tanhOpenParenReasonableGap() throws {
        let layout = try FormulaKit.render(#"\tanh(z)"#)
        guard let runOpen = layout.textRuns.first(where: { $0.string == "(" }),
            let runH = layout.textRuns.last(where: { $0.string == "h" })
        else {
            XCTFail("expected separate runs for h and (")
            return
        }
        let wH = SymbolNode(character: "h", type: .mord, fontName: MathLogicalFontNames.mainRegular, fontSize: 16)
            .getBox(options: .default).width
        let gap = runOpen.baselineOrigin.x - runH.baselineOrigin.x
        XCTAssertLessThan(
            gap,
            wH + 10,
            "gap h→( was \(gap) pt (wH=\(wH)); expect only advance + thin muskip, not whole-word italic correction"
        )
    }

    #if os(macOS)
    /// Raster: no shared ink between `h` and `(` in the slice just left of the `(` origin (too-strong negative mop kern caused overlap).
    func testRasterTanhOpenParenInkSeparation() throws {
        let fontSize: CGFloat = 16
        let options = FormulaKit.Options(style: .display, fontSize: fontSize)
        let layout = try FormulaKit.render(#"\tanh(z)"#, options: options)
        guard let runH = layout.textRuns.last(where: { $0.string == "h" }),
            let runOpen = layout.textRuns.first(where: { $0.string == "(" })
        else {
            XCTFail("expected runs for h and (")
            return
        }
        let wH = SymbolNode(character: "h", type: .mord, fontName: MathLogicalFontNames.mainRegular, fontSize: fontSize)
            .getBox(options: options).width
        let gapStart = runH.baselineOrigin.x + wH * 0.86
        let gapEnd = runOpen.baselineOrigin.x - 0.04
        XCTAssertGreaterThan(gapEnd, gapStart + 0.2, "invalid h/`(` sample strip (start \(gapStart) end \(gapEnd))")

        let root = layout.rootBox
        let totalH = root.height + root.depth
        let bounds = CGRect(x: 0, y: -root.depth, width: root.width, height: totalH)
        let supersample: CGFloat = 4
        let pad: CGFloat = 12
        let hiW = Int((bounds.width + pad * 2) * supersample)
        let hiH = Int((totalH + pad * 2) * supersample)

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let data = calloc(hiW * hiH * 4, 1) else {
            XCTFail("buffer alloc failed")
            return
        }
        defer { free(data) }
        guard
            let ctx = CGContext(
                data: data,
                width: hiW,
                height: hiH,
                bitsPerComponent: 8,
                bytesPerRow: hiW * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue
            )
        else {
            XCTFail("CGContext failed")
            return
        }

        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setShouldSmoothFonts(false)
        ctx.setAllowsFontSmoothing(false)

        ctx.setFillColor(CGColor.white)
        ctx.fill(CGRect(x: 0, y: 0, width: hiW, height: hiH))

        ctx.translateBy(x: CGFloat(hiW) / 2, y: CGFloat(hiH) / 2)
        ctx.scaleBy(x: supersample, y: supersample)
        ctx.translateBy(x: -bounds.midX, y: -bounds.midY)

        ctx.setFillColor(CGColor.black)
        ctx.addPath(layout.decorationPath.cgPath)
        ctx.fillPath()

        let mathToDevice = ctx.ctm

        for run in layout.textRuns {
            let ctFont = SymbolNode.ctFontForMathGlyph(
                fontName: run.fontName,
                character: run.string,
                fontSize: run.fontSize,
                metricsTextMode: run.metricsTextMode,
                mathFont: layout.mathFont
            )
            let attrs: [NSAttributedString.Key: Any] = [
                .font: ctFont as NSFont,
                .foregroundColor: NSColor.black,
            ]
            let line = CTLineCreateWithAttributedString(
                NSAttributedString(string: run.string, attributes: attrs)
            )
            ctx.textPosition = CGPoint(x: run.baselineOrigin.x, y: run.baselineOrigin.y)
            CTLineDraw(line, ctx)
        }

        let yMid = runH.baselineOrigin.y
        let bandHalf: CGFloat = max(2, root.height * 0.09)
        let corners = [
            CGPoint(x: gapStart, y: yMid - bandHalf),
            CGPoint(x: gapEnd, y: yMid - bandHalf),
            CGPoint(x: gapEnd, y: yMid + bandHalf),
            CGPoint(x: gapStart, y: yMid + bandHalf),
        ]
        var minXP = CGFloat.infinity
        var maxXP = -CGFloat.infinity
        var minYP = CGFloat.infinity
        var maxYP = -CGFloat.infinity
        for c in corners {
            let p = c.applying(mathToDevice)
            minXP = min(minXP, p.x)
            maxXP = max(maxXP, p.x)
            minYP = min(minYP, p.y)
            maxYP = max(maxYP, p.y)
        }

        let ix0 = max(0, Int(floor(minXP)) - 1)
        let ix1 = min(hiW - 1, Int(ceil(maxXP)) + 1)
        let iy0 = max(0, Int(floor(minYP)) - 1)
        let iy1 = min(hiH - 1, Int(ceil(maxYP)) + 1)

        let bytes = data.assumingMemoryBound(to: UInt8.self)
        var darkest: UInt8 = 255
        for y in iy0...iy1 {
            for x in ix0...ix1 {
                let o = (y * hiW + x) * 4
                darkest = min(darkest, bytes[o])
            }
        }
        XCTAssertGreaterThan(
            Int(darkest),
            228,
            "h/`(` slice should stay light (darkest R=\(darkest) x \(ix0)...\(ix1) y \(iy0)...\(iy1), pt \(gapStart)...\(gapEnd))"
        )
    }

    /// ``\downarrow`` and ``\implies`` are both ``.mrel``; STIX ink can extend past advances, so rel–rel glue must clear a slice.
    func testRasterDownarrowImpliesInkSeparation() throws {
        let fontSize: CGFloat = 16
        let options = FormulaKit.Options(style: .display, fontSize: fontSize)
        let layout = try FormulaKit.render(#"h \downarrow \implies \text{x}"#, options: options)
        guard let runDown = layout.textRuns.first(where: { $0.string == "↓" }),
            let runImpl = layout.textRuns.first(where: { $0.string == "⟹" })
        else {
            XCTFail("expected runs for ↓ and ⟹")
            return
        }
        let wDown = SymbolNode(
            character: "↓",
            type: .mrel,
            fontName: MathLogicalFontNames.mainRegular,
            fontSize: fontSize
        )
        .getBox(options: options).width
        // Sample strictly inside the glue (past ↓ advance, before ⟹ origin); STIX ink can extend past advances.
        let inset: CGFloat = 1.1
        let gapStart = runDown.baselineOrigin.x + wDown + inset
        let gapEnd = runImpl.baselineOrigin.x - inset
        XCTAssertGreaterThan(gapEnd, gapStart + 0.5, "layout gap strip invalid (start \(gapStart) end \(gapEnd))")

        let root = layout.rootBox
        let totalH = root.height + root.depth
        let bounds = CGRect(x: 0, y: -root.depth, width: root.width, height: totalH)
        let supersample: CGFloat = 4
        let pad: CGFloat = 12
        let hiW = Int((bounds.width + pad * 2) * supersample)
        let hiH = Int((totalH + pad * 2) * supersample)

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let data = calloc(hiW * hiH * 4, 1) else {
            XCTFail("buffer alloc failed")
            return
        }
        defer { free(data) }
        guard
            let ctx = CGContext(
                data: data,
                width: hiW,
                height: hiH,
                bitsPerComponent: 8,
                bytesPerRow: hiW * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue
            )
        else {
            XCTFail("CGContext failed")
            return
        }

        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setShouldSmoothFonts(false)
        ctx.setAllowsFontSmoothing(false)

        ctx.setFillColor(CGColor.white)
        ctx.fill(CGRect(x: 0, y: 0, width: hiW, height: hiH))

        ctx.translateBy(x: CGFloat(hiW) / 2, y: CGFloat(hiH) / 2)
        ctx.scaleBy(x: supersample, y: supersample)
        ctx.translateBy(x: -bounds.midX, y: -bounds.midY)

        layout.drawMath(in: ctx, textColor: .black)

        let mathToDevice = ctx.ctm
        let yMid = runDown.baselineOrigin.y
        let bandHalf: CGFloat = max(2, root.height * 0.12)
        let corners = [
            CGPoint(x: gapStart, y: yMid - bandHalf),
            CGPoint(x: gapEnd, y: yMid - bandHalf),
            CGPoint(x: gapEnd, y: yMid + bandHalf),
            CGPoint(x: gapStart, y: yMid + bandHalf),
        ]
        var minXP = CGFloat.infinity
        var maxXP = -CGFloat.infinity
        var minYP = CGFloat.infinity
        var maxYP = -CGFloat.infinity
        for c in corners {
            let p = c.applying(mathToDevice)
            minXP = min(minXP, p.x)
            maxXP = max(maxXP, p.x)
            minYP = min(minYP, p.y)
            maxYP = max(maxYP, p.y)
        }

        let ix0 = max(0, Int(floor(minXP)) - 1)
        let ix1 = min(hiW - 1, Int(ceil(maxXP)) + 1)
        let iy0 = max(0, Int(floor(minYP)) - 1)
        let iy1 = min(hiH - 1, Int(ceil(maxYP)) + 1)

        let bytes = data.assumingMemoryBound(to: UInt8.self)
        var darkest: UInt8 = 255
        for y in iy0...iy1 {
            for x in ix0...ix1 {
                let o = (y * hiW + x) * 4
                darkest = min(darkest, bytes[o])
            }
        }
        XCTAssertGreaterThan(
            Int(darkest),
            228,
            "↓/⟹ slice should stay light (darkest R=\(darkest) x \(ix0)...\(ix1) y \(iy0)...\(iy1), pt \(gapStart)...\(gapEnd))"
        )
    }
    #endif

    func testRender_kernEm() throws {
        let k = try FormulaKit.render(#"a\kern0.5em b"#)
        let plain = try FormulaKit.render("ab")
        XCTAssertGreaterThan(k.rootBox.width, plain.rootBox.width)
    }

    func testRender_leftMiddleRight() throws {
        let layout = try FormulaKit.render(#"\left( x \middle| y \right)"#)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
        XCTAssertFalse(layout.textRuns.map(\.string).joined().contains("?"))
    }

    func testRender_bigDelimiter() throws {
        let layout = try FormulaKit.render(#"\big("#)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
    }

    func testRender_displaystyle() throws {
        let d = try FormulaKit.render(#"\displaystyle x"#)
        let t = try FormulaKit.render(#"\textstyle x"#)
        XCTAssertGreaterThan(d.rootBox.width, 0)
        XCTAssertGreaterThan(t.rootBox.width, 0)
    }

    func testRender_pmatrixStillWorks() throws {
        let layout = try FormulaKit.render(#"\begin{pmatrix} a & b \\ c & d \end{pmatrix}"#)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
    }

    func testRender_displaystyleWithoutBraces() throws {
        let layout = try FormulaKit.render(#"\displaystyle x"#)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
    }

    func testRender_mathchoice() throws {
        let layout = try FormulaKit.render(#"\mathchoice{D}{T}{S}{SS}"#)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
    }

    func testRender_oversetXrightarrow() throws {
        let layout = try FormulaKit.render(#"\overset{!}{=}"#)
        let arr = try FormulaKit.render(#"\xrightarrow{f}"#)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
        XCTAssertGreaterThan(arr.rootBox.width, 0)
    }

    func testRender_alignedEnvironment() throws {
        let layout = try FormulaKit.render(#"\begin{aligned} a &= b \\ c &= d \end{aligned}"#)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
    }

    func testRender_phantomAndSmash() throws {
        let ph = try FormulaKit.render(#"\phantom{xx}"#)
        let hp = try FormulaKit.render(#"\hphantom{xx}"#)
        let sm = try FormulaKit.render(#"\smash{y}"#)
        XCTAssertGreaterThan(ph.rootBox.height + ph.rootBox.depth, 0)
        XCTAssertEqual(hp.rootBox.height + hp.rootBox.depth, 0, accuracy: 0.001)
        XCTAssertEqual(sm.rootBox.height + sm.rootBox.depth, 0, accuracy: 0.001)
    }

    func testRender_arrayHline() throws {
        let layout = try FormulaKit.render(#"\begin{array}{cc} a & b \\ \hline c & d \\ \end{array}"#)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
        XCTAssertFalse(layout.decorationPath.boundingBoxOfPath.isEmpty, "hline should add rule geometry")
    }

    func testRender_biglBigr() throws {
        let layout = try FormulaKit.render(#"\bigl( x \bigr)"#)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
    }

    func testRender_tbinom() throws {
        let layout = try FormulaKit.render(#"\tbinom{n}{k}"#)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
    }

    /// Math-italic `T` before `\uparrow` needs ic + `\mathrel` spacing (was `mord`–`mord`, zero glue).
    func testRender_italicCorrectionBeforeUpArrow() throws {
        let spaced = try FormulaKit.render(#"T\uparrow"#)
        let wT = try FormulaKit.render("T").rootBox.width
        let wUp = try FormulaKit.render(#"\uparrow"#).rootBox.width
        let concatWidth = wT + wUp
        XCTAssertGreaterThan(spaced.rootBox.width, concatWidth, "expect kern and/or thickmuskip between T and ↑")
    }

    /// STIX 𝒩: typographic advance can be tighter than drawn outline; italic kern + width must clear `(`.
    func testRender_mathcalNFollowedByOpenParenUsesLineAdvance() throws {
        let combined = try FormulaKit.render(#"\mathcal{N}("#).rootBox.width
        let nOnly = try FormulaKit.render(#"\mathcal{N}"#).rootBox.width
        let paren = try FormulaKit.render("(").rootBox.width
        XCTAssertGreaterThanOrEqual(
            combined,
            nOnly + paren - 0.25,
            "𝒩 box width should match CTLine advance so ( is not placed inside 𝒩 ink"
        )
        let layout = try FormulaKit.render(#"\mathcal{N}("#)
        let scriptN = UnicodeScalar(0x1D4A9)!  // MATHEMATICAL SCRIPT CAPITAL N
        guard
            let runN = layout.textRuns.first(where: { $0.string.unicodeScalars.contains(scriptN) }),
            let runParen = layout.textRuns.first(where: { $0.string == "(" })
        else {
            XCTFail("expected separate text runs for 𝒩 and (")
            return
        }
        XCTAssertGreaterThan(
            runParen.baselineOrigin.x,
            runN.baselineOrigin.x,
            "open paren must be laid out to the right of 𝒩 origin"
        )
    }

    /// Full expression: kern before auto-`leftright` `(` must not be lost after `\sim` and subscripted `W`s.
    func testRender_mathcalNGapBeforeAutoDelimInLSTMStyleLine() throws {
        let layout = try FormulaKit.render(#"W_f, W_i, W_o, W_c \sim \mathcal{N}(0, 0.1)"#)
        let scriptN = UnicodeScalar(0x1D4A9)!  // MATHEMATICAL SCRIPT CAPITAL N
        guard
            let runN = layout.textRuns.first(where: { $0.string.unicodeScalars.contains(scriptN) }),
            let runParen = layout.textRuns.first(where: { $0.string == "(" })
        else {
            XCTFail("expected text runs for 𝒩 and (")
            return
        }
        let wN = try FormulaKit.render(#"\mathcal{N}"#).rootBox.width
        let gap = runParen.baselineOrigin.x - runN.baselineOrigin.x
        let kernBundle = gap - wN
        XCTAssertGreaterThan(
            kernBundle,
            2.5,
            "expect kern between 𝒩 and `(` (gap=\(gap) wN=\(wN) kernBundle=\(kernBundle))"
        )
    }

    /// 𝒩 before a balanced `(…)` group (auto ``\left``-style) still needs italic kern so the swash clears `(`.
    func testRender_mathcalNBeforePairedOpenParenClearsInk() throws {
        let wFull = try FormulaKit.render(#"\mathcal{N}(0)"#).rootBox.width
        let wN = try FormulaKit.render(#"\mathcal{N}"#).rootBox.width
        let wParen = try FormulaKit.render(#"(0)"#).rootBox.width
        XCTAssertGreaterThan(
            wFull,
            wN + wParen + 0.2,
            "expect extra width from italic kern between 𝒩 and auto-stretched (…)"
        )
    }

    #if os(macOS)
    func testCaligraphicScriptCapitalHasDelimiterItalicFloor() {
        let n = SymbolNode(
            character: "\u{1D4A9}",
            type: .mord,
            fontName: MathLogicalFontNames.mainRegular,
            fontSize: 16
        )
        let box = n.getBox(options: .default)
        XCTAssertGreaterThan(box.italicCorrection, 0.30 * 16 - 0.001)
    }

    /// Pixels between the 𝒩 advance column and the `(` origin must stay white (guards CTLineDraw vs layout).
    func testRasterGapBetweenMathcalNAndOpenParenIsInkFree() throws {
        let latex = #"W_f, W_i, W_o, W_c \sim \mathcal{N}(0, 0.1)"#
        let fontSize: CGFloat = 16
        let options = FormulaKit.Options(style: .display, fontSize: fontSize)
        let layout = try FormulaKit.render(latex, options: options)
        let scriptN = UnicodeScalar(0x1D4A9)!
        guard
            let runN = layout.textRuns.first(where: { $0.string.unicodeScalars.contains(scriptN) }),
            let runParen = layout.textRuns.first(where: { $0.string == "(" })
        else {
            XCTFail("expected runs for 𝒩 and (")
            return
        }
        let wN = try FormulaKit.render(#"\mathcal{N}"#, options: options).rootBox.width
        let kernWidth = runParen.baselineOrigin.x - (runN.baselineOrigin.x + wN)
        XCTAssertGreaterThan(
            kernWidth,
            3,
            "layout should reserve kern between 𝒩 advance and `(` origin (got \(kernWidth) pt)"
        )
        // `(` is drawn at runParen.x but its curve extends left — sample only the kern slice near 𝒩, not near `(`.
        let gapStart = runN.baselineOrigin.x + wN + kernWidth * 0.08
        let gapEnd = runN.baselineOrigin.x + wN + kernWidth * 0.42
        XCTAssertGreaterThan(gapEnd, gapStart + 0.5, "kern too small for left-slot sample (w=\(kernWidth))")

        let root = layout.rootBox
        let totalH = root.height + root.depth
        let bounds = CGRect(x: 0, y: -root.depth, width: root.width, height: totalH)
        let supersample: CGFloat = 4
        let pad: CGFloat = 12
        let hiW = Int((bounds.width + pad * 2) * supersample)
        let hiH = Int((totalH + pad * 2) * supersample)

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let data = calloc(hiW * hiH * 4, 1) else {
            XCTFail("buffer alloc failed")
            return
        }
        defer { free(data) }
        guard
            let ctx = CGContext(
                data: data,
                width: hiW,
                height: hiH,
                bitsPerComponent: 8,
                bytesPerRow: hiW * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue
            )
        else {
            XCTFail("CGContext failed")
            return
        }

        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setShouldSmoothFonts(false)
        ctx.setAllowsFontSmoothing(false)

        ctx.setFillColor(CGColor.white)
        ctx.fill(CGRect(x: 0, y: 0, width: hiW, height: hiH))

        ctx.translateBy(x: CGFloat(hiW) / 2, y: CGFloat(hiH) / 2)
        ctx.scaleBy(x: supersample, y: supersample)
        ctx.translateBy(x: -bounds.midX, y: -bounds.midY)

        ctx.setFillColor(CGColor.black)
        ctx.addPath(layout.decorationPath.cgPath)
        ctx.fillPath()

        let mathToDevice = ctx.ctm

        for run in layout.textRuns {
            let ctFont = SymbolNode.ctFontForMathGlyph(
                fontName: run.fontName,
                character: run.string,
                fontSize: run.fontSize,
                metricsTextMode: run.metricsTextMode,
                mathFont: layout.mathFont
            )
            let attrs: [NSAttributedString.Key: Any] = [
                .font: ctFont as NSFont,
                .foregroundColor: NSColor.black,
            ]
            let line = CTLineCreateWithAttributedString(
                NSAttributedString(string: run.string, attributes: attrs)
            )
            ctx.textPosition = CGPoint(x: run.baselineOrigin.x, y: run.baselineOrigin.y)
            CTLineDraw(line, ctx)
        }

        // Sample a thin band around the 𝒩 baseline so descenders / other rows cannot darken the strip.
        let yMid = runN.baselineOrigin.y
        let bandHalf: CGFloat = max(2, root.height * 0.08)
        let corners = [
            CGPoint(x: gapStart, y: yMid - bandHalf),
            CGPoint(x: gapEnd, y: yMid - bandHalf),
            CGPoint(x: gapEnd, y: yMid + bandHalf),
            CGPoint(x: gapStart, y: yMid + bandHalf),
        ]
        var minXP = CGFloat.infinity
        var maxXP = -CGFloat.infinity
        var minYP = CGFloat.infinity
        var maxYP = -CGFloat.infinity
        for c in corners {
            let p = c.applying(mathToDevice)
            minXP = min(minXP, p.x)
            maxXP = max(maxXP, p.x)
            minYP = min(minYP, p.y)
            maxYP = max(maxYP, p.y)
        }

        let ix0 = max(0, Int(floor(minXP)) - 1)
        let ix1 = min(hiW - 1, Int(ceil(maxXP)) + 1)
        let iy0 = max(0, Int(floor(minYP)) - 1)
        let iy1 = min(hiH - 1, Int(ceil(maxYP)) + 1)

        let bytes = data.assumingMemoryBound(to: UInt8.self)
        var darkest: UInt8 = 255
        for y in iy0...iy1 {
            for x in ix0...ix1 {
                let o = (y * hiW + x) * 4
                darkest = min(darkest, bytes[o])
            }
        }
        // Anti-aliased margins land around ~235–245; true overlap is ≲200.
        XCTAssertGreaterThan(
            Int(darkest),
            230,
            "kern interior should be free of 𝒩/`(` ink (darkest R=\(darkest) x \(ix0)...\(ix1) y \(iy0)...\(iy1), pt \(gapStart)...\(gapEnd))"
        )
    }
    #endif

    /// Plain `(`…`)` / `[`…`]` should stretch like ``\left(…\right)`` when enclosing tall operators (not strict TeX).
    func testRender_autoStretchPlainDelimitersMatchExplicitLeftRight() throws {
        let tall = #"\sum_{k=1}^{h+d} x"#
        let autoParen = try FormulaKit.render("(\(tall))")
        let explicitParen = try FormulaKit.render(#"\left("# + tall + #"\right)"#)
        XCTAssertEqual(autoParen.rootBox.totalHeight, explicitParen.rootBox.totalHeight, accuracy: 2.0)
        let openAuto = autoParen.textRuns.first { $0.string == "(" }
        let openExplicit = explicitParen.textRuns.first { $0.string == "(" }
        XCTAssertEqual(
            openAuto?.fontName,
            openExplicit?.fontName,
            #"auto vs explicit `\left` should agree on logical font slot"#
        )
        XCTAssertEqual(
            openAuto?.fontName,
            MathLogicalFontNames.mainRegular,
            "STIX uses Main + OpenType ``.s*`` masters for tall stretchy delimiters"
        )
        XCTAssertEqual(openAuto?.openTypeMathGlyphName, openExplicit?.openTypeMathGlyphName)
        XCTAssertNotNil(openAuto?.openTypeMathGlyphName)

        let autoBracket = try FormulaKit.render("[\(tall)]")
        let explicitBracket = try FormulaKit.render(#"\left["# + tall + #"\right]"#)
        XCTAssertEqual(autoBracket.rootBox.totalHeight, explicitBracket.rootBox.totalHeight, accuracy: 2.0)
        let braAuto = autoBracket.textRuns.first { $0.string == "[" }
        let braExplicit = explicitBracket.textRuns.first { $0.string == "[" }
        XCTAssertEqual(braAuto?.fontName, braExplicit?.fontName)

        let offOpts = FormulaKit.Options(autoStretchDelimiters: false)
        let noStretch = try FormulaKit.render("(\(tall))", options: offOpts)
        let openOff = noStretch.textRuns.first { $0.string == "(" }
        XCTAssertEqual(openOff?.fontName, MathLogicalFontNames.mainRegular)
    }

    /// STIX Two Math: `\left`/`\right` should prefer OpenType math ``parenleft`` / ``parenleft.s*`` masters (not only huge pt scaling).
    func testLeftRightDelimitersForDisplaySummationWithLimits() throws {
        let inner = #"\sum_{k=1}^{h+d} W_f[j,k] \cdot z_t[k] + b_f[j]"#
        let opts = FormulaKit.Options(style: .display, fontSize: 16)
        var scratch = SymbolRenderScratch()
        var o = FormulaKit.Options(style: .display, fontSize: 16, symbolRenderScratch: scratch)
        let innerH = try FormulaKit.render(inner, options: o).rootBox.totalHeight

        let lr = try FormulaKit.render(#"\left("# + inner + #"\right)"#, options: opts)
        let open = try XCTUnwrap(lr.textRuns.first { $0.string == "(" })
        XCTAssertEqual(open.fontName, MathLogicalFontNames.mainRegular, "OT math masters use Main + glyph names")
        XCTAssertNotNil(open.openTypeMathGlyphName)
        XCTAssertTrue(
            open.openTypeMathGlyphName!.contains("parenleft"),
            "expected parenleft(.sN) master, got \(open.openTypeMathGlyphName!)"
        )
        XCTAssertLessThanOrEqual(
            open.fontSize,
            opts.fontSize * 1.45,
            "delimiter pt size should stay near body when using .s* masters; got \(open.fontSize)"
        )
        let close = try XCTUnwrap(lr.textRuns.first { $0.string == ")" })
        XCTAssertTrue(
            (close.openTypeMathGlyphName ?? "").contains("parenright"),
            "closing paren should use matching parenright(.sN); got \(String(describing: close.openTypeMathGlyphName))"
        )

        scratch = SymbolRenderScratch()
        o = FormulaKit.Options(style: .display, fontSize: 16, symbolRenderScratch: scratch)
        let metrics = FontMetrics.getMetrics(for: opts.fontSize)
        let axis = metrics.axisHeight * opts.fontSize
        let paren = SymbolNode(
            character: "(",
            type: .mopen,
            fontName: open.fontName,
            fontSize: open.fontSize,
            openTypeMathGlyphName: open.openTypeMathGlyphName
        )
        let pb = paren.getBox(options: o)
        let wrapped = VerticalBox(
            elements: [VerticalBox.Element(node: paren, shift: axis - (pb.height - pb.totalHeight / 2))],
            position: .individualShift
        )
        XCTAssertGreaterThanOrEqual(
            wrapped.getBox(options: o).totalHeight + 0.5,
            innerH,
            "axis-centered delimiter span should cover inner totalHeight"
        )

        let fullLine =
            #"f_t[j] = \sigma \left( \sum_{k=1}^{h+d} W_f[j,k] \cdot z_t[k] + b_f[j] \right)"#
        let full = try FormulaKit.render(fullLine, options: opts)
        let openFull = try XCTUnwrap(full.textRuns.first { $0.string == "(" })
        XCTAssertNotNil(openFull.openTypeMathGlyphName)
        XCTAssertLessThanOrEqual(openFull.fontSize, opts.fontSize * 1.45)
        XCTAssertGreaterThanOrEqual(full.rootBox.totalHeight + 0.5, innerH)
    }

    /// `\mathbb{R}` must use Unicode double-struck R (U+211D), not ASCII `R`.
    func testRender_mathbbRIsDoubleStruck() throws {
        let layout = try FormulaKit.render(#"\mathbb{R}"#)
        let joined = layout.textRuns.map(\.string).joined()
        XCTAssertTrue(
            joined.unicodeScalars.contains { $0.value == 0x211D },
            "expected U+211D DOUBLE-STRUCK R, got: \(joined.debugDescription)"
        )
    }

    /// `\mathcal{L}` must use Unicode script L (U+2112), not ASCII `L`, when using STIX / system fonts.
    func testRender_mathcalLIsScriptCapital() throws {
        let layout = try FormulaKit.render(#"\mathcal{L}"#)
        let joined = layout.textRuns.map(\.string).joined()
        XCTAssertTrue(
            joined.unicodeScalars.contains { $0.value == 0x2112 },
            "expected U+2112 SCRIPT CAPITAL L, got: \(joined.debugDescription)"
        )
    }

    /// `\to` is `\rightarrow` in LaTeX; without a `MathSymbols` entry it was parsed as function `to` (letters “to”).
    func testRender_toIsRightArrowGlyph() throws {
        let layout = try FormulaKit.render(#"\to"#)
        XCTAssertTrue(
            layout.textRuns.contains { $0.string == "→" },
            #"\to should emit a → text run, not render the letters t-o"#
        )
        XCTAssertGreaterThan(layout.rootBox.width, 0)
    }

    /// `f_t` must keep the nucleus italic correction past `\scriptspace` so `f_t \to` isn’t tight/colliding.
    func testRender_supSubPropagatesItalicCorrectionBeforeRel() throws {
        let fSub = try FormulaKit.render(#"f_t"#)
        XCTAssertGreaterThan(
            fSub.rootBox.italicCorrection,
            0.000_5,
            "trailing script space should carry nucleus ic for the next atom"
        )
        let full = try FormulaKit.render(#"f_t \to 1"#)
        let wFsub = try FormulaKit.render(#"f_t"#).rootBox.width
        let wTo = try FormulaKit.render(#"\to"#).rootBox.width
        let wOne = try FormulaKit.render("1").rootBox.width
        XCTAssertGreaterThan(
            full.rootBox.width,
            wFsub + wTo + wOne,
            "expect ic + mu glue between f_t, \\to, and 1"
        )
    }

    #if os(macOS)
    /// Bundled web-font `.ttf` assets are not used on macOS; math should resolve to the primary system math face.
    func testMacOSCompositeFontUsesStIX() throws {
        let font = SymbolNode.ctFontForMathGlyph(
            fontName: MathLogicalFontNames.mathItalic,
            character: "x",
            fontSize: 16,
            metricsTextMode: false
        )
        let ps = (CTFontCopyPostScriptName(font) as String?) ?? ""
        let expected = MathFont.resolvedProvider(for: .stix).primaryMathPostScriptName
        XCTAssertTrue(
            ps.localizedCaseInsensitiveContains("stix"),
            "expected font matching \(expected), got \(ps)"
        )
    }
    #endif

    func testMathFontRegistryResolvesStixByDefault() {
        let p = MathFont.resolvedProvider(for: .stix)
        XCTAssertEqual(p.identifier, .stix)
        XCTAssertTrue(p.primaryMathPostScriptName.localizedCaseInsensitiveContains("stix"))
    }

    func testMathFontUnknownIdentifierFallsBackToDefaultProvider() {
        let unknown = MathFontIdentifier(rawValue: "no-such-math-font-xyz")
        let p = MathFont.resolvedProvider(for: unknown)
        XCTAssertEqual(p.identifier, MathFontRegistry.shared.defaultIdentifier)
    }

    func testRenderOptionsMathFontMatchesLayout() throws {
        var opts = FormulaKit.Options()
        opts.mathFont = .stix
        let layout = try FormulaKit.render(#"x"#, options: opts)
        XCTAssertEqual(layout.mathFont, .stix)
    }

    func testMathFontRegistryResolvesGaeguMath() throws {
        let p = MathFont.resolvedProvider(for: .gaeguMath)
        XCTAssertEqual(p.identifier, .gaeguMath)
        XCTAssertEqual(p.primaryMathPostScriptName, "GaeguMath-Regular")
        XCTAssertTrue(p.isPrimaryMathFontAvailable(forFontSize: 16))
        XCTAssertNotNil(GaeguMath.bundledFontURL)

        let opts = FormulaKit.Options(mathFont: .gaeguMath)
        let layout = try FormulaKit.render(
            #"\frac{-b \pm \sqrt{b^2 - 4ac}}{2a} + \underbrace{x_1 + x_2}_{k}"#,
            options: opts
        )
        XCTAssertEqual(layout.mathFont, .gaeguMath)
        XCTAssertFalse(layout.textRuns.isEmpty)
        XCTAssertGreaterThan(layout.rootBox.width, 0)
    }
}
