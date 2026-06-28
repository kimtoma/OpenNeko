import SwiftUI

struct OpenNekoGlassContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    @ViewBuilder
    func openNekoGlass(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.strokeBorder(.separator.opacity(0.45), lineWidth: 1)
                }
        }
    }

    func openNekoPixelPanel(cornerRadius: CGFloat = 6) -> some View {
        modifier(OpenNekoPixelPanelModifier(cornerRadius: cornerRadius))
    }
}

private struct OpenNekoPixelPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let fill = colorScheme == .dark
            ? Color(red: 0.10, green: 0.10, blue: 0.11)
            : Color(red: 0.98, green: 0.97, blue: 0.93)
        let stroke = colorScheme == .dark
            ? Color.white.opacity(0.72)
            : Color.black.opacity(0.78)

        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
                    .fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
                    .stroke(stroke, lineWidth: 2)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.22), radius: 0, x: 3, y: 3)
    }
}
