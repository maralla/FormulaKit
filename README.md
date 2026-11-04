# FormulaKit

A platform-neutral Swift library for parsing and laying out LaTeX-style mathematical expressions and driving any external renderer (`MathRenderBackend`).

Note that this project referenced the library [KaTeX](https://katex.org/).

## Requirements

- Swift 6.0 or later
- Works on macOS, iOS, tvOS, watchOS, and Linux

## Usage

### 1. Render into an External `MathRenderBackend`

Implement `MathRenderBackend` on your renderer and pass it to `FormulaKit.render(_:options:into:)`:

```swift
import FormulaKit

struct MyMathRenderer: MathRenderBackend {
    mutating func beginMath(rootBox: Box, mathFont: MathFontIdentifier) {
        // Inspect rootBox.width, rootBox.height, rootBox.depth
    }

    mutating func fillMathPath(_ path: MathPath) {
        // Fill fraction bars, radical vinculums, and stretchy braces
    }

    mutating func drawMathTextRun(_ run: MathTextRun, mathFont: MathFontIdentifier) {
        // Draw positioned glyph run at `run.baselineOrigin`
    }
}

var renderer = MyMathRenderer()
try FormulaKit.render(
    #"\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"#,
    options: FormulaKit.Options(fontSize: 24.0, mathFont: .feiMath),
    into: &renderer
)
```

### 2. Inspect Layout Output Directly (`MathCompositeLayout`)

```swift
let layout = try FormulaKit.layout(
    #"\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}"#,
    options: FormulaKit.Options(mathFont: .feiMath)
)
// layout.rootBox        -> Box (width, height above baseline, depth below baseline)
// layout.decorationPath -> MathPath (fraction bars, radical vinculums, braces)
// layout.textRuns       -> [MathTextRun] (positioned glyph runs)
```

Use `FormulaKit.parse(_:options:)` if you only need the `ParseNode` syntax tree.

## License

[LICENSE](LICENSE).
