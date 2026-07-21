//
//  CreditsView.swift
//  World
//
//  Placeholder credits screen reached from the Main Menu's "Credit" button.
//

import SwiftUI

struct CreditsView: View {
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "281E0D").ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Credits")
                    .font(.fredokaBold(28))
                    .foregroundStyle(Theme.buttonLabel)

                Text("Credits content coming soon.")
                    .font(.fredoka(16))
                    .foregroundStyle(Theme.buttonLabel.opacity(0.8))

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
