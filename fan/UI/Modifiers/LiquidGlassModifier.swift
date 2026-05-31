//
//  LiquidGlassModifier.swift
//  ffan
//
//  Native Liquid Glass (macOS 26+) applied to a rounded rect.
//

import SwiftUI

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
