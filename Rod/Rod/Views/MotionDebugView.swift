//
//  MotionDebugView.swift
//  Rod
//
//  Created by Calzy Akmal Indyramdhani on 17/07/26.
//

import SwiftUI
import Shared

struct MotionDebugView: View {

    let recorder: MotionDebugRecorder

    var body: some View {

        if let sample = recorder.latestSample {

            VStack(alignment: .leading, spacing: 10) {

                LabeledContent(
                    "Samples",
                    value: "\(recorder.sampleCount)"
                )

                Divider()

                LabeledContent(
                    "Phase",
                    value: sample.interpretation.phase.rawValue.capitalized
                )

                LabeledContent(
                    "Action",
                    value: sample.interpretation.action.rawValue.capitalized
                )

                LabeledContent(
                    "Pose",
                    value: sample.interpretation.isPoseValid
                    ? "✅ Valid"
                    : "❌ Invalid"
                )

                Divider()

                Group {

                    LabeledContent("Selected Pose", value: sample.decision.selectedPose.capitalized)
                    LabeledContent("Idle Distance", value: format(sample.decision.idleDistance))
                    LabeledContent("Cast Distance", value: format(sample.decision.castDistance))
                    LabeledContent("Reel Distance", value: format(sample.decision.reelDistance))
                }

                Divider()

                Group {

                    LabeledContent(
                        "Acceleration",
                        value: format(sample.decision.forwardAcceleration)
                    )

                    LabeledContent(
                        "Required",
                        value: format(sample.decision.requiredForwardAcceleration)
                    )

                    LabeledContent(
                        "Forward Check",
                        value: sample.decision.passedForwardCheck
                        ? "✅"
                        : "❌"
                    )
                }

                Divider()

                LabeledContent(
                    "Cooldown",
                    value: sample.decision.passedCooldownCheck
                    ? "✅"
                    : "❌"
                )
            }

        } else {

            Text("No motion samples recorded.")
                .foregroundStyle(.secondary)
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
