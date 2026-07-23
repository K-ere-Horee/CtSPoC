//
//  CreditsView.swift
//  World
//
//  Credits screen reached from the Main Menu's "Credits" button.
//

import SwiftUI

private struct CreditsEntry {
    let role: String
    let names: [String]
}

struct CreditsView: View {
    let onBack: () -> Void

    private static let entries: [CreditsEntry] = [
        CreditsEntry(role: "Art and Game Design", names: ["Bintang Lay"]),
        CreditsEntry(role: "3D and Game Program", names: ["Radit Silver", "Calzy"]),
        CreditsEntry(role: "Music and Sound Design", names: ["Gerald"]),
    ]

    var body: some View {
        ZStack {
            Color(hex: "281E0D").ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Credits")
                    .font(.fredokaBold(28))
                    .foregroundStyle(Theme.buttonLabel)

                VStack(spacing: 20) {
                    ForEach(Self.entries, id: \.role) { entry in
                        VStack(spacing: 6) {
                            Text(entry.role)
                                .font(.fredokaBold(16))
                                .foregroundStyle(Theme.buttonLabel)
                            ForEach(entry.names, id: \.self) { name in
                                Text(name)
                                    .font(.fredoka(16))
                                    .foregroundStyle(Theme.buttonLabel.opacity(0.8))
                            }
                        }
                    }
                }
                .multilineTextAlignment(.center)

                Spacer()

                Button(action: onBack) {
                    ShadowedLabel(
                        text: "Back",
                        font: .fredokaBold(20),
                        color: Theme.buttonLabel,
                        shadowColor: Theme.buttonLabelShadow
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.buttonFill, in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding(.top, 60)
        }
    }
}

#Preview {
    CreditsView(onBack: {})
}
