//
//  CatchCutsceneView.swift
//  World
//

import SwiftUI

/// Shown while `WorldViewModel.isShowingCatchCutscene` is true — the brief window between a catch
/// resolving and `ResultView` appearing (ADR-045), while `hookEntity` plays its jump/freeze/settle
/// in the RealityKit scene behind this overlay. Non-interactive and undismissable: it always ends on
/// its own once `WorldViewModel`'s cutscene timer elapses, same as the no-button casting phases.
///
/// Letterbox bars, a radial glow, and a spring-overshoot title (ADR-048) — a static "CATCH!" label
/// alone, even with the ADR-046/047 camera cut and freeze, still read as flat rather than a real
/// cutscene moment; these are the presentation-only levers available before real fish/camera assets
/// land.
///
/// ADR-100: the title now sits on the same dark rounded-rectangle + white border card used by every
/// other HUD element (`CastMeterView`'s track, `LineTensionView`'s bar, `FishCounterBadgeView`'s
/// pill, `LastCatchStatBoxView`) — was bare text with only a drop shadow, which read as a one-off
/// style next to the rest of the HUD. The letterbox bars and radial glow stay full-bleed cinematic
/// effects, unrelated to the card design language.
struct CatchCutsceneView: View {
    @State private var titleScale: CGFloat = 0.3
    @State private var titleOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var barHeight: CGFloat = 0

    private let maxBarHeight: CGFloat = 64
    private static let panelColor = Color(red: 0.16, green: 0.12, blue: 0.09)

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [.clear, .black.opacity(0.5)],
                center: .center,
                startRadius: 100,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack {
                Rectangle().fill(.black).frame(height: barHeight)
                Spacer()
                Rectangle().fill(.black).frame(height: barHeight)
            }
            .ignoresSafeArea()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow.opacity(0.55), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 170
                        )
                    )
                    .frame(width: 340, height: 340)
                    .opacity(glowOpacity)

                Text("CATCH!")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                    .shadow(color: .black.opacity(0.7), radius: 10)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 20)
                    .background(Self.panelColor, in: RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white, lineWidth: 2))
                    .scaleEffect(titleScale)
                    .opacity(titleOpacity)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                barHeight = maxBarHeight
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.45)) {
                titleScale = 1
                titleOpacity = 1
                glowOpacity = 1
            }
        }
    }
}

#Preview {
    CatchCutsceneView()
}
