//
//  ConfettiView.swift
//  SplitBill
//

import SwiftUI

// MARK: - Particle Model

struct ConfettiParticle: Identifiable {
    let id       = UUID()
    let x        : CGFloat   // 0…1 of screen width
    let size     : CGFloat
    let color    : Color
    let delay    : Double
    let duration : Double
    let rotation : Double
    let shape    : Int        // 0 = circle, 1 = square, 2 = tall rect
}

// MARK: - Confetti View

struct ConfettiView: View {
    let particles: [ConfettiParticle]
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { p in
                particleView(p, in: geo)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }

    @ViewBuilder
    private func particleView(_ p: ConfettiParticle, in geo: GeometryProxy) -> some View {
        let w: CGFloat = p.shape == 2 ? p.size * 0.5 : p.size
        let h: CGFloat = p.shape == 2 ? p.size * 1.4 : p.size

        Group {
            switch p.shape {
            case 0:  Circle().fill(p.color)
            case 1:  RoundedRectangle(cornerRadius: 2).fill(p.color)
            default: RoundedRectangle(cornerRadius: 2).fill(p.color)
            }
        }
        .frame(width: w, height: h)
        .rotationEffect(.degrees(animate ? p.rotation + 360 : p.rotation))
        .position(
            x: p.x * geo.size.width,
            y: animate
                ? -geo.size.height * 0.4   // flies up off-screen
                : geo.size.height - 80      // starts near bottom
        )
        .opacity(animate ? 0 : 1)
        .animation(
            .easeOut(duration: p.duration).delay(p.delay),
            value: animate
        )
    }
}

// MARK: - Generator

func makeConfettiParticles() -> [ConfettiParticle] {
    let colors: [Color] = [
        Color(hex: "7C6FF7"), Color(hex: "FB7185"),
        Color(hex: "34D399"), Color(hex: "FBBF24"),
        Color(hex: "60A5FA"), Color(hex: "F472B6"),
        Color(hex: "A78BFA"), Color(hex: "FCD678"),
        Color(hex: "6EE7B7"), Color(hex: "FDA4AF"),
    ]
    return (0..<32).map { i in
        ConfettiParticle(
            x:        CGFloat.random(in: 0.05...0.95),
            size:     CGFloat.random(in: 6...15),
            color:    colors[i % colors.count],
            delay:    Double.random(in: 0...0.6),
            duration: Double.random(in: 1.4...2.8),
            rotation: Double.random(in: 0...360),
            shape:    i % 3
        )
    }
}
