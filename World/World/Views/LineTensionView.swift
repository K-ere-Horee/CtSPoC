//
//  LineTensionView.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 18/07/26.
//

import SwiftUI

struct LineTensionView: View {
    let isFighting: Bool
    let tension: Float

    private var color: Color {
        switch tension {
        case ..<0.5: .green
        case ..<0.8: .yellow
        default: .red
        }
    }

    var body: some View {
        if isFighting {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Line Tension")
                        .font(.headline)
                    Spacer()
                    if tension >= 0.8 {
                        Text("SNAPPING")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)

                        Capsule()
                            .fill(color)
                            .frame(width: CGFloat(min(1, max(0, tension))) * geometry.size.width)
                    }
                }
                .frame(height: 14)
            }
        }
    }
}
