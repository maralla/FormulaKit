import CoreGraphics
import Foundation

// MARK: - AtomType
public enum AtomType: Sendable {
    /// Ordinary character (e.g., 'x', 'y', '2').
    case mord
    /// Large operator (e.g., '\sum', '\int').
    case mop
    /// Binary operator (e.g., '+', '-', '\pm').
    case mbin
    /// Relation (e.g., '=', '<', '\leq').
    case mrel
    /// Opening delimiter (e.g., '(', '[').
    case mopen
    /// Closing delimiter (e.g., ')', ']').
    case mclose
    /// Punctuation (e.g., ',', ';').
    case mpunct
    /// Inner atom (e.g., fractions).
    case minner
}

// MARK: - Box

/// A Box is the fundamental unit of the layout system.
/// It represents a logical rectangle with a baseline, width, height, and depth.
public struct Box {
    /// The width of the box.
    public var width: CGFloat

    /// The height of the box (distance from baseline to top).
    public var height: CGFloat

    /// The depth of the box (distance from baseline to bottom).
    public var depth: CGFloat

    /// The italic correction for the box.
    public var italicCorrection: CGFloat

    /// Total vertical size of the box (height + depth).
    public var totalHeight: CGFloat {
        return height + depth
    }

    public init(width: CGFloat = 0, height: CGFloat = 0, depth: CGFloat = 0, italicCorrection: CGFloat = 0) {
        self.width = width
        self.height = height
        self.depth = depth
        self.italicCorrection = italicCorrection
    }
}

// MARK: - LayoutNode

/// A protocol for nodes that can be laid out and rendered.
public protocol LayoutNode {
    /// The TeX atom type for this node. Used for spacing.
    var type: AtomType { get }

    /// Calculate the box dimensions for this node.
    /// - Parameter options: Rendering options, including font metrics.
    func getBox(options: FormulaKit.Options) -> Box

    /// Geometry that is not drawn as positioned text (fraction bars, `\sqrt` rules, braces, etc.).
    /// Glyph symbols are omitted; use ``collectTextRuns(at:options:)`` for those.
    func renderDecoration(at origin: CGPoint, options: FormulaKit.Options) -> CGPath

    /// Glyph spans for system/Core Text drawing at the given baseline origins (math y-up).
    func collectTextRuns(at origin: CGPoint, options: FormulaKit.Options) -> [MathTextRun]
}

extension LayoutNode {
    /// Default: no vector ink in this node.
    public func renderDecoration(at origin: CGPoint, options: FormulaKit.Options) -> CGPath {
        CGMutablePath()
    }

    /// Default: no text in this node.
    public func collectTextRuns(at origin: CGPoint, options: FormulaKit.Options) -> [MathTextRun] {
        []
    }
}

/// Extension to provide default rendering for a sequence of nodes.
extension Array where Element == LayoutNode {
    public func renderDecoration(at origin: CGPoint, options: FormulaKit.Options) -> CGPath {
        let path = CGMutablePath()
        var currentOrigin = origin
        for node in self {
            let box = node.getBox(options: options)
            path.addPath(node.renderDecoration(at: currentOrigin, options: options))
            currentOrigin.x += box.width
        }
        return path
    }

    public func collectTextRuns(at origin: CGPoint, options: FormulaKit.Options) -> [MathTextRun] {
        var runs: [MathTextRun] = []
        var currentOrigin = origin
        for node in self {
            let box = node.getBox(options: options)
            runs.append(contentsOf: node.collectTextRuns(at: currentOrigin, options: options))
            currentOrigin.x += box.width
        }
        return runs
    }
}

// MARK: - SpaceNode

/// A LayoutNode that represents a fixed amount of horizontal and vertical space.
public struct SpaceNode: LayoutNode {
    public let type: AtomType
    public let width: CGFloat
    public let height: CGFloat
    public let depth: CGFloat

    public init(width: CGFloat, height: CGFloat = 0, depth: CGFloat = 0, type: AtomType = .mord) {
        self.width = width
        self.height = height
        self.depth = depth
        self.type = type
    }

    public func getBox(options: FormulaKit.Options) -> Box {
        Box(width: width, height: height, depth: depth)
    }
}

// MARK: - RuleNode

/// A LayoutNode representing a geometric line (rule), used for fraction bars, etc.
public struct RuleNode: LayoutNode {
    /// The TeX atom type for this node.
    public let type: AtomType

    /// Width of the rule.
    public let width: CGFloat

    /// Height of the rule.
    public let height: CGFloat

    /// Depth of the rule.
    public let depth: CGFloat

    public init(width: CGFloat, height: CGFloat, depth: CGFloat = 0, type: AtomType = .mord) {
        self.width = width
        self.height = height
        self.depth = depth
        self.type = type
    }

    public func getBox(options: FormulaKit.Options) -> Box {
        return Box(width: width, height: height, depth: depth)
    }

    public func renderDecoration(at origin: CGPoint, options: FormulaKit.Options) -> CGPath {
        let rect = CGRect(x: origin.x, y: origin.y - depth, width: width, height: height + depth)
        return CGPath(rect: rect, transform: nil)
    }
}

// MARK: - OpaqueStrutNode

/// Invisible strut with explicit width / height / depth (for `\phantom`-style spacing).
public struct OpaqueStrutNode: LayoutNode {
    public let type: AtomType
    public let box: Box

    public init(width: CGFloat, height: CGFloat, depth: CGFloat, type: AtomType = .mord) {
        self.box = Box(width: width, height: height, depth: depth)
        self.type = type
    }

    public func getBox(options: FormulaKit.Options) -> Box { box }

    public func collectTextRuns(at origin: CGPoint, options: FormulaKit.Options) -> [MathTextRun] {
        []
    }
}

// MARK: - SmashNode

/// Layout box with TeX `\smash` semantics: natural width, zero height/depth for surrounding layout,
/// while still painting and emitting text runs (ink may extend outside the reported box).
public struct SmashNode: LayoutNode {
    public let type: AtomType
    public let content: LayoutNode

    public init(content: LayoutNode, type: AtomType = .mord) {
        self.content = content
        self.type = type
    }

    public func getBox(options: FormulaKit.Options) -> Box {
        let b = content.getBox(options: options)
        return Box(width: b.width, height: 0, depth: 0, italicCorrection: b.italicCorrection)
    }

    public func renderDecoration(at origin: CGPoint, options: FormulaKit.Options) -> CGPath {
        content.renderDecoration(at: origin, options: options)
    }

    public func collectTextRuns(at origin: CGPoint, options: FormulaKit.Options) -> [MathTextRun] {
        content.collectTextRuns(at: origin, options: options)
    }
}

// MARK: - HorizontalBox

/// A LayoutNode that arranges its children horizontally.
public struct HorizontalBox: LayoutNode {
    /// The TeX atom type for this node.
    public let type: AtomType

    /// The children of this box.
    public let children: [LayoutNode]

    public init(children: [LayoutNode], type: AtomType = .mord) {
        self.children = children
        self.type = type
    }

    public func getBox(options: FormulaKit.Options) -> Box {
        if children.isEmpty {
            return Box()
        }

        var width: CGFloat = 0
        var height: CGFloat = 0
        var depth: CGFloat = 0

        var lastItalicCorrection: CGFloat = 0
        for child in children {
            let childBox = child.getBox(options: options)
            width += childBox.width
            height = max(height, childBox.height)
            depth = max(depth, childBox.depth)
            lastItalicCorrection = childBox.italicCorrection
        }

        // `\tanh`, `\sin`, `\operatorname{…}` are `.mop` boxes of upright letters. Each child may still
        // report Core Text “italic correction” from serifs; that must not kern the whole operator away
        // from the following delimiter (e.g. `\tanh(z)` vs `\mathcal{N}(…)`).
        let outgoingItalic: CGFloat = (type == .mop) ? 0 : lastItalicCorrection
        return Box(width: width, height: height, depth: depth, italicCorrection: outgoingItalic)
    }

    public func renderDecoration(at origin: CGPoint, options: FormulaKit.Options) -> CGPath {
        let path = CGMutablePath()
        var currentOrigin = origin
        for child in children {
            let childBox = child.getBox(options: options)
            path.addPath(child.renderDecoration(at: currentOrigin, options: options))
            currentOrigin.x += childBox.width
        }
        return path
    }

    public func collectTextRuns(at origin: CGPoint, options: FormulaKit.Options) -> [MathTextRun] {
        var runs: [MathTextRun] = []
        var currentOrigin = origin
        for child in children {
            let childBox = child.getBox(options: options)
            runs.append(contentsOf: child.collectTextRuns(at: currentOrigin, options: options))
            currentOrigin.x += childBox.width
        }
        return runs
    }
}

// MARK: - VerticalBox

public struct VerticalBox: LayoutNode {
    /// The TeX atom type for this node.
    public let type: AtomType

    /// Positioning types for vertical layout.
    public enum PositionType {
        case top(CGFloat)
        case bottom(CGFloat)
        case shift(CGFloat)
        case individualShift
    }

    /// An element in the vertical box.
    public struct Element {
        public let node: LayoutNode
        public let shift: CGFloat

        public init(node: LayoutNode, shift: CGFloat = 0) {
            self.node = node
            self.shift = shift
        }
    }

    public let elements: [Element]
    public let position: PositionType

    public init(elements: [Element], position: PositionType = .shift(0), type: AtomType = .minner) {
        self.elements = elements
        self.position = position
        self.type = type
    }

    public func getBox(options: FormulaKit.Options) -> Box {
        if elements.isEmpty {
            return Box()
        }

        let elementBoxes = elements.map { $0.node.getBox(options: options) }
        var width: CGFloat = 0
        var height: CGFloat = 0
        var depth: CGFloat = 0

        // Calculate based on children and position type
        // This is a simplified version of classic TeX vlist logic
        var minPos: CGFloat = 0
        var maxPos: CGFloat = 0
        var currPos: CGFloat = 0

        switch position {
        case .individualShift:
            for (idx, elem) in elements.enumerated() {
                let box = elementBoxes[idx]
                // Element is shifted by elem.shift (positive is up)
                // Y in our layout: baseline is 0, up is positive.
                // Element's top: box.height + elem.shift
                // Element's bottom: -box.depth + elem.shift
                height = max(height, box.height + elem.shift)
                depth = max(depth, box.depth - elem.shift)
                width = max(width, box.width)
            }
        case .shift(let shift):
            if let firstBox = elementBoxes.first {
                depth = -firstBox.depth - shift
                currPos = depth
                minPos = depth

                for box in elementBoxes {
                    currPos += box.height + box.depth
                    width = max(width, box.width)
                }
                maxPos = currPos
                height = maxPos
                depth = -minPos
            }
        default:
            // Simplified fallback
            for box in elementBoxes {
                width = max(width, box.width)
                height += box.totalHeight
            }
        }

        // HorizontalBox uses children.last.italicCorrection, we do same if appropriate
        // but VerticalBox usually doesn't have italic correction unless it's a wrapper.

        return Box(width: width, height: height, depth: depth)
    }

    public func renderDecoration(at origin: CGPoint, options: FormulaKit.Options) -> CGPath {
        let path = CGMutablePath()
        let elementBoxes = elements.map { $0.node.getBox(options: options) }
        switch position {
        case .individualShift:
            for elem in elements {
                let elementOrigin = CGPoint(x: origin.x, y: origin.y + elem.shift)
                path.addPath(elem.node.renderDecoration(at: elementOrigin, options: options))
            }
        case .shift(let shift):
            var currentY = origin.y - shift
            for (idx, elem) in elements.enumerated() {
                let box = elementBoxes[idx]
                let elementOrigin = CGPoint(x: origin.x, y: currentY)
                path.addPath(elem.node.renderDecoration(at: elementOrigin, options: options))
                currentY += box.totalHeight
            }
        default:
            break
        }
        return path
    }

    public func collectTextRuns(at origin: CGPoint, options: FormulaKit.Options) -> [MathTextRun] {
        var runs: [MathTextRun] = []
        let elementBoxes = elements.map { $0.node.getBox(options: options) }
        switch position {
        case .individualShift:
            for elem in elements {
                let elementOrigin = CGPoint(x: origin.x, y: origin.y + elem.shift)
                runs.append(contentsOf: elem.node.collectTextRuns(at: elementOrigin, options: options))
            }
        case .shift(let shift):
            var currentY = origin.y - shift
            for (idx, elem) in elements.enumerated() {
                let box = elementBoxes[idx]
                let elementOrigin = CGPoint(x: origin.x, y: currentY)
                runs.append(contentsOf: elem.node.collectTextRuns(at: elementOrigin, options: options))
                currentY += box.totalHeight
            }
        default:
            break
        }
        return runs
    }
}

// MARK: - BraceNode
import Foundation

/// Horizontal ``\overbrace`` / ``\underbrace``. Ink and metrics come **only** from ``MathFontProviding/horizontalBraceLayout`` (font-specific; no engine fallback).
public struct BraceNode: LayoutNode {
    public let type: AtomType = .mord
    public let isOver: Bool
    public let targetWidth: CGFloat
    public let fontSize: CGFloat
    public let mathFont: MathFontIdentifier

    /// Reference renderer image-metrics brace `minWidth` (em).
    public static let minWidthEm: CGFloat = 1.6

    public init(isOver: Bool, targetWidth: CGFloat, fontSize: CGFloat, mathFont: MathFontIdentifier = .stix) {
        self.isOver = isOver
        self.targetWidth = targetWidth
        self.fontSize = fontSize
        self.mathFont = mathFont
    }

    private func braceLayout(options: FormulaKit.Options) -> MathFontHorizontalBraceLayout {
        let layoutW = max(targetWidth, Self.minWidthEm * fontSize)
        return options.resolvedMathFont.horizontalBraceLayout(
            isOver: isOver,
            layoutWidth: layoutW,
            bodyFontSize: fontSize,
            mathFont: mathFont
        )
    }

    public func getBox(options: FormulaKit.Options) -> Box {
        let L = braceLayout(options: options)
        return Box(width: L.layoutWidth, height: L.height, depth: L.depth, italicCorrection: 0)
    }

    public func collectTextRuns(at origin: CGPoint, options: FormulaKit.Options) -> [MathTextRun] {
        let L = braceLayout(options: options)
        return [
            MathTextRun(
                string: L.drawString,
                fontName: L.logicalFontName,
                fontSize: L.pointSize,
                baselineOrigin: CGPoint(x: origin.x + L.textOriginOffsetX, y: origin.y),
                openTypeMathGlyphName: L.coreTextGlyphName
            )
        ]
    }

    public func renderDecoration(at _: CGPoint, options _: FormulaKit.Options) -> CGPath {
        CGMutablePath()
    }
}
