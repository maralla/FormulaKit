# FormulaKit

Swift library for laying out and rendering LaTeX-style math. Parsing, metrics, and drawing run in native code (Core Text and Core Graphics).

Note that this project referenced the library [KaTeX](https://katex.org/).

## Requirements

- Swift 6.0 or later
- macOS 13, iOS 16, tvOS 16, or watchOS 9

## Adding the package

In Xcode, use File > Add Package Dependencies and choose this folder or its remote URL. In another Swift package, add a dependency on this package and list the `FormulaKit` product in your target’s `dependencies`.

## Usage

```swift
import FormulaKit

let layout = try FormulaKit.render(#"\frac{-b \pm \sqrt{b^2-4ac}}{2a}"#)
```

Use `FormulaKit.parse` if you only need the parse tree. Configure behavior with `FormulaKit.Options` (font size, display vs text style, error handling, and math font selection).

STIX is used as the default math font when available on the system.

## License

[LICENSE](LICENSE).
