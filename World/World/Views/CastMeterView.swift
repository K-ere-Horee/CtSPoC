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

    private var power: Float { castSolution?.power ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cast Meter")
                .font(.headline)

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

            if let castSolution {
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
