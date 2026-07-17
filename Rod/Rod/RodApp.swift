//
//  RodApp.swift
//  Rod
//
//  Created by Calzy Akmal Indyramdhani on 16/07/26.
//

import SwiftUI
import Shared

@main
struct RodApp: App {

    @StateObject
    private var viewModel: RodViewModel

    init() {

        let motionManager = MotionManager()

        let interpreter = RodMotionInterpreter()

        let spatial = NearbyInteractionManager()

        let transport = TransportClient()

        let haptics = FishingHaptics()

        _viewModel = StateObject(
            wrappedValue: RodViewModel(
                motionManager: motionManager,
                motionInterpreter: interpreter,
                spatialManager: spatial,
                transport: transport,
                fishingHaptics: haptics
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
