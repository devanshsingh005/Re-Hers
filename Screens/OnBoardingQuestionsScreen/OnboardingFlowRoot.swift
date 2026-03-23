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
