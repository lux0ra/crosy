import AppKit
import SwiftUI

@MainActor
struct CrosshairPreview: View {
    let options: Options
    private var scale: CGFloat { min(1, 192 / options.canvasSize, 128 / options.canvasSize) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color(nsColor: .textBackgroundColor)
                Canvas { context, size in
                    var grid = Path()
                    for x in stride(from: CGFloat(0), through: size.width, by: 16) {
                        grid.move(to: CGPoint(x: x, y: 0))
                        grid.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: CGFloat(0), through: size.height, by: 16) {
                        grid.move(to: CGPoint(x: 0, y: y))
                        grid.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(grid, with: .color(.secondary.opacity(0.1)), lineWidth: 0.5)
                }
                PreviewDrawing(options: options)
            }
            .frame(height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.secondary.opacity(0.15)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.text("Ваш прицел"))
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var caption: String {
        if options.opacity == 0 { return L.text("Предпросмотр · прицел прозрачен при 0 %") }
        return scale == 1 ? L.text("Предпросмотр · 1:1")
            : L.format("Предпросмотр · уменьшен до %d %%", Int(scale * 100))
    }
}

/// Only layout scales the preview. Its Core Graphics renderer is shared with the actual overlay.
@MainActor
private struct PreviewDrawing: NSViewRepresentable {
    let options: Options

    func makeNSView(context: Context) -> PreviewHost { PreviewHost(options: options) }

    func updateNSView(_ view: PreviewHost, context: Context) {
        guard view.crosshair.options != options else { return }
        view.crosshair.options = options
        view.crosshair.alphaValue = options.opacity
        view.crosshair.needsDisplay = true
        view.needsLayout = true
    }
}

@MainActor
private final class PreviewHost: NSView {
    let crosshair: CrosshairView

    init(options: Options) {
        crosshair = CrosshairView(options: options)
        super.init(frame: .zero)
        crosshair.alphaValue = options.opacity
        addSubview(crosshair)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    override func layout() {
        super.layout()
        let size = crosshair.options.canvasSize
        let scale = min(1, max(0, bounds.width - 24) / size, max(0, bounds.height - 20) / size)
        let extent = size * scale
        crosshair.frame = NSRect(x: bounds.midX - extent / 2, y: bounds.midY - extent / 2,
                                 width: extent, height: extent)
        crosshair.bounds = NSRect(x: 0, y: 0, width: size, height: size)
    }
}
