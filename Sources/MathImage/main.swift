import AppKit
import CoreGraphics
import Foundation
import ImageIO
import FormulaKit
import UniformTypeIdentifiers

@main
enum MathImage {
    private static let defaultLatex =
        #"c_t = \underbrace{f_t \odot c_{t-1}}_{\text{keep old memory}} + i_t \odot \tilde{c}_t"#

    private static let supersample: CGFloat = 2

    static func main() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let parsed = parseArguments(CommandLine.arguments)

        let outName =
            parsed.explicitOutPath
            ?? ProcessInfo.processInfo.environment["MATH_IMAGE_OUT"]
            ?? ProcessInfo.processInfo.environment["VISUAL_COMPARE_OUTPUT"]
            ?? "actual.png"
        let outputURL: URL =
            outName.hasPrefix("/")
            ? URL(fileURLWithPath: outName).standardizedFileURL
            : cwd.appendingPathComponent(outName, isDirectory: false).standardizedFileURL

        let latex =
            parsed.latexFromArgs
            ?? ProcessInfo.processInfo.environment["MATH_IMAGE_LATEX"]
            ?? ProcessInfo.processInfo.environment["VISUAL_COMPARE_LATEX"]
            ?? Self.defaultLatex

        try renderPNG(to: outputURL, latex: latex)
    }

    private struct ParsedCLI {
        var explicitOutPath: String?
        var latexFromArgs: String?
    }

    private static func parseArguments(_ args: [String]) -> ParsedCLI {
        if args.contains(where: { $0 == "-h" || $0 == "--help" }) {
            print(
                """
                Usage: MathImage [--out <file.png>] [latex ...]

                Renders LaTeX math with FormulaKit and writes a PNG (default size 592×192 logical, white background).

                Output path: --out if present, else MATH_IMAGE_OUT or VISUAL_COMPARE_OUTPUT, else actual.png in the current directory.

                LaTeX: non-flag arguments (joined with spaces), else MATH_IMAGE_LATEX or VISUAL_COMPARE_LATEX, else a built-in sample.

                Environment: MATH_IMAGE_OUT, MATH_IMAGE_LATEX, MATH_IMAGE_FONTSIZE (VISUAL_COMPARE_* still accepted for compatibility).
                """
            )
            exit(0)
        }

        var result = ParsedCLI(explicitOutPath: nil, latexFromArgs: nil)
        var latexParts: [String] = []
        var i = 1
        while i < args.count {
            let a = args[i]
            if a == "--out", i + 1 < args.count {
                result.explicitOutPath = args[i + 1]
                i += 2
                continue
            }
            latexParts.append(a)
            i += 1
        }
        let joined = latexParts.joined(separator: " ")
        if !joined.isEmpty {
            result.latexFromArgs = joined
        }
        return result
    }

    private static func renderPNG(to outputURL: URL, latex: String) throws {
        #if os(macOS)
        if !MathFont.isPrimaryMathFontAvailable(forFontSize: 16) {
            fputs(
                "MathImage: \(MathFont.primaryMathPostScriptName) not found (expected in \(MathFont.supplementalFontsDirectoryHint)). Math rendering may use fallback fonts.\n",
                stderr
            )
        }
        #endif

        print("Rendering LaTeX: \(latex)")

        let fontSize: CGFloat = {
            if let s = ProcessInfo.processInfo.environment["MATH_IMAGE_FONTSIZE"]
                ?? ProcessInfo.processInfo.environment["VISUAL_COMPARE_FONTSIZE"],
                let d = Double(s)
            {
                return CGFloat(d)
            }
            return 16.0
        }()

        let options = FormulaKit.Options(style: .display, fontSize: fontSize)
        let layout = try FormulaKit.render(latex, options: options)
        let layoutBox = layout.rootBox
        let imageSize = CGSize(width: 592, height: 192)
        let horizontalPadding: CGFloat = 20
        let verticalPadding: CGFloat = 26

        let totalH = layoutBox.height + layoutBox.depth
        let bounds = CGRect(x: 0, y: -layoutBox.depth, width: layoutBox.width, height: totalH)
        let availW = (imageSize.width - horizontalPadding * 2) * supersample
        let availH = (imageSize.height - verticalPadding * 2) * supersample
        let scale = min(availW / max(bounds.width, 1), availH / max(bounds.height, 1))

        let hiW = Int(imageSize.width * supersample)
        let hiH = Int(imageSize.height * supersample)

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard
            let hiCtx = CGContext(
                data: nil,
                width: hiW,
                height: hiH,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue
            )
        else {
            throw NSError(
                domain: "MathImage",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create high-res CGContext"]
            )
        }

        hiCtx.setAllowsAntialiasing(true)
        hiCtx.setShouldAntialias(true)
        hiCtx.setShouldSmoothFonts(false)
        hiCtx.setAllowsFontSmoothing(false)

        hiCtx.setFillColor(CGColor.white)
        hiCtx.fill(CGRect(x: 0, y: 0, width: hiW, height: hiH))

        hiCtx.translateBy(x: CGFloat(hiW) / 2, y: CGFloat(hiH) / 2)
        hiCtx.scaleBy(x: scale, y: scale)
        hiCtx.translateBy(x: -bounds.midX, y: -bounds.midY)

        layout.drawMath(in: hiCtx, textColor: .black)

        guard let hiImage = hiCtx.makeImage() else {
            throw NSError(
                domain: "MathImage",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create high-res CGImage"]
            )
        }

        guard
            let loCtx = CGContext(
                data: nil,
                width: Int(imageSize.width),
                height: Int(imageSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo.rawValue
            )
        else {
            throw NSError(
                domain: "MathImage",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create output CGContext"]
            )
        }

        loCtx.setAllowsAntialiasing(true)
        loCtx.setShouldAntialias(true)
        loCtx.setShouldSmoothFonts(false)
        loCtx.setAllowsFontSmoothing(false)
        loCtx.interpolationQuality = .high

        loCtx.setFillColor(CGColor.white)
        loCtx.fill(CGRect(origin: .zero, size: imageSize))

        loCtx.draw(hiImage, in: CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))

        guard let outImage = loCtx.makeImage() else {
            throw NSError(
                domain: "MathImage",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create output CGImage"]
            )
        }

        let ppm = Int(round(144.0 / 0.0254))
        let pngProps: [CFString: Any] = [
            kCGImagePropertyPixelWidth: Int(imageSize.width),
            kCGImagePropertyPixelHeight: Int(imageSize.height),
            kCGImagePropertyPNGDictionary: [
                kCGImagePropertyPNGXPixelsPerMeter: ppm,
                kCGImagePropertyPNGYPixelsPerMeter: ppm,
            ] as CFDictionary,
        ]

        guard
            let dest = CGImageDestinationCreateWithURL(
                outputURL as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            throw NSError(
                domain: "MathImage",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"]
            )
        }
        CGImageDestinationAddImage(dest, outImage, pngProps as CFDictionary)
        if !CGImageDestinationFinalize(dest) {
            throw NSError(
                domain: "MathImage",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG"]
            )
        }

        print("Wrote: \(outputURL.path)")
    }
}
