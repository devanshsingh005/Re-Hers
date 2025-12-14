//
//  OnboardingFlowRoot.swift
//  Re-Hearse_v1
//
//  Created by DEVANSH on 14/12/25.
//

import SwiftUI
import UIKit

struct OnboardingFlowRoot: View {
    @StateObject var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            OnboardingQuestion1View()
                .environmentObject(viewModel)
        }
    }
}

