import AppKit
@preconcurrency import CoreGraphics
import FormulaKit
import SwiftUI

@main
struct FormulaKitSampleApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
#endif

struct ContentView: View {
    @State private var latexInput: String = "x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}"
    @State private var layout: MathCompositeLayout?

    var body: some View {
        VStack(spacing: 20) {
            Text("FormulaKit (composite render)")
                .font(.title)
                .padding(.top)

            TextEditor(text: $latexInput)
                .font(.system(.body, design: .monospaced))
                .frame(height: 100)
                .padding(4)
                .border(Color.gray.opacity(0.3))
                .onChange(of: latexInput) { _ in
                    updateLayout()
                }

            GeometryReader { geometry in
                ZStack {
                    Color.white
                        .cornerRadius(8)
                        .shadow(radius: 2)

                    if layout != nil {
                        MathCompositeSwiftUIView(layout: layout)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        Text("Enter LaTeX above")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            updateLayout()
        }
    }

    private func updateLayout() {
        do {
            layout = try FormulaKit.render(latexInput)
        } catch {
            print("Rendering error: \(error)")
            layout = nil
        }
    }
}

/// Draws ``MathCompositeLayout`` via Core Graphics + Core Text (math y-up inside flipped view space).
struct MathCompositeSwiftUIView: NSViewRepresentable {
    let layout: MathCompositeLayout?

    func makeNSView(context: Context) -> MathLayoutNSView {
        let v = MathLayoutNSView()
        v.layoutToDraw = layout
        return v
    }

    func updateNSView(_ nsView: MathLayoutNSView, context: Context) {
        nsView.layoutToDraw = layout
        nsView.needsDisplay = true
    }
}

final class MathLayoutNSView: NSView {
    var layoutToDraw: MathCompositeLayout?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let layout = layoutToDraw else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.saveGState()
        defer { ctx.restoreGState() }

        // NSView: y down; layout is y up.
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)

        let box = layout.rootBox
        let totalH = box.height + box.depth
        let ink = CGRect(x: 0, y: -box.depth, width: box.width, height: totalH)
        let pad: CGFloat = 24
        let availW = bounds.width - pad * 2
        let availH = bounds.height - pad * 2
        let scale = min(availW / max(ink.width, 1), availH / max(ink.height, 1), 1)

        ctx.translateBy(x: bounds.width / 2, y: bounds.height / 2)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -ink.midX, y: -ink.midY)

        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setShouldSmoothFonts(false)
        ctx.setAllowsFontSmoothing(false)

        layout.drawMath(in: ctx, textColor: .black)
    }
}
