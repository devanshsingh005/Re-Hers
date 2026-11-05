import SwiftUI
import UIKit

struct OnboardingFlowRoot: View {
    @StateObject var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationView {
            OnboardingQuestion1View()
                .environmentObject(viewModel)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
