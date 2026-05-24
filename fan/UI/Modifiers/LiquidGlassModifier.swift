//
//  LiquidGlassModifier.swift
//  ffan
//
//  Native Liquid Glass (macOS 26+) with material fallback styling.
//

import SwiftUI

// MARK: - Ambient backdrop (gives glass something to refract)

/// Full-bleed animated mesh used behind Liquid Glass panels (showcase pattern).
struct LiquidGlassAmbientBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                    .init(0, 1), .init(0.5, 1), .init(1, 1)
                ],
                colors: meshColors(time: t)
            )
            .ignoresSafeArea()
            .overlay {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.12),
                        Color.clear,
                        Color.black.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }

    private func meshColors(time: TimeInterval) -> [Color] {
        let s = sin(time * 0.35)
        let c = cos(time * 0.28)
        return [
            Color(hue: 0.58 + s * 0.04, saturation: 0.55, brightness: 0.92),
            Color(hue: 0.62 + c * 0.03, saturation: 0.48, brightness: 0.88),
            Color(hue: 0.72 + s * 0.05, saturation: 0.52, brightness: 0.90),
            Color(hue: 0.55 + c * 0.04, saturation: 0.45, brightness: 0.85),
            Color(hue: 0.60, saturation: 0.38, brightness: 0.78),
            Color(hue: 0.68 + s * 0.03, saturation: 0.50, brightness: 0.86),
            Color(hue: 0.52 + c * 0.02, saturation: 0.42, brightness: 0.82),
            Color(hue: 0.64 + s * 0.04, saturation: 0.46, brightness: 0.84),
            Color(hue: 0.70 + c * 0.03, saturation: 0.44, brightness: 0.80)
        ]
    }
}

// MARK: - Panel wrapper

struct LiquidGlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var prominent: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                prominent
                    ? .regular.tint(.white.opacity(0.08)).interactive()
                    : .regular.interactive(),
                in: .rect(cornerRadius: cornerRadius)
            )
    }
}

// MARK: - Legacy modifier (routes to native glass on macOS 26)

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var prominent: Bool = false

    func body(content: Content) -> some View {
        content
            .glassEffect(
                prominent
                    ? .regular.tint(.white.opacity(0.06)).interactive()
                    : .regular.interactive(),
                in: .rect(cornerRadius: cornerRadius)
            )
    }
}

extension View {
    /// Applies Apple's Liquid Glass material in a rounded rect.
    func liquidGlass(cornerRadius: CGFloat = 16, prominent: Bool = false) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, prominent: prominent))
    }
}
