//
//  CastMeterView.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 15/07/26.
//

import Shared
import SwiftUI

struct CastMeterView: View {
    let castSolution: CastSolution?
    let power: Float
    let phase: RodMotionPhase
    /// Live seconds held in the backswing/charging zone this attempt (ADR-056) — shown as a raw
    /// timer alongside the normalized power bar, since power is now purely a function of this.
    let holdDuration: TimeInterval

    private var isVisible: Bool {
        phase == .backswing || phase == .charging || phase == .forwardSwing
            || phase == .release || phase == .followThrough
    }

    var body: some View {
        Group {
            if isVisible {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Cast Meter")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "Holding %.1fs", holdDuration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            HStack(spacing: 0) {
                                Color.green
                                Color.yellow
                                Color.red
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                            Rectangle()
                                .fill(.primary)
                                .frame(width: 3, height: 28)
                                .offset(x: CGFloat(min(1, max(0, power))) * geometry.size.width - 1.5)
                        }
                    }
                    .frame(height: 28)

                    HStack {
                        Text("Near")
                        Spacer()
                        Text("Far")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if let castSolution, phase == .release || phase == .followThrough {
                        HStack {
                            Text(String(format: "Power %.2f", castSolution.power))
                            Spacer()
                            Text(String(format: "Distance %.1f m", castSolution.distance))
                        }
                        .font(.caption)
                    } else {
                        Text("No active cast")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
