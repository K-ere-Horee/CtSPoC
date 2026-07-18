//
//  LoadingView.swift
//  World
//
//  Created by Calzy Akmal Indyramdhani on 19/07/26.
//

import SwiftUI

/// Full-bleed loading screen shown while the game world spins up.
struct LoadingView: View {
    var body: some View {
        ZStack {
            Image("LoadingScreen")
                .resizable()
                .scaledToFill()
                .clipped()
                .ignoresSafeArea()

            Theme.overlay
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 128)
                    .padding(.top, 20)
                    .padding(.leading, 20)

                Spacer()

                Text("Loading…")
                    .font(.fredokaBold(20))
                    .foregroundStyle(.white)
                    .padding(.bottom, 20)
                    .padding(.leading, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

#Preview {
    LoadingView()
}
