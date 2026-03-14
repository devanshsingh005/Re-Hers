import SwiftUI
import UIKit

struct OnboardingQuestion2View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selection: String?

    struct Artist: Identifiable {
        let id = UUID()
        let imageName: String
        
    }

    let artists: [Artist] = [
        .init(imageName: "artist1"),
        .init(imageName: "artist2"),
        .init(imageName: "artist3"),
        .init(imageName: "artist4"),
        .init(imageName: "artist5"),
        .init(imageName: "artist6"),
        .init(imageName: "artist7"),
        .init(imageName: "artist8")
    ]

    // 2 columns that scale naturally on iPad
    let grid = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    // Adaptive padding for iPad vs iPhone
    var horizontalPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 180 : 24
    }

    var body: some View {
        VStack(spacing: 24) {

            ProgressIndicator(step: 2)

            Text("Any favorite songs or artists?")
                .font(.title2.bold())
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("Type a few names so we can shape your first playlist.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: grid, spacing: 22) {

                    ForEach(artists) { artist in
                        Button {
                            selection = artist.imageName
                            viewModel.selectedArtist = artist.imageName
                        } label: {
                            Image(artist.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 140, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selection == artist.imageName
                                            ? Color(UIColor.secondaryColor)
                                            : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                        }

                    }
                }
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            NavigationLink {
                OnboardingQuestion3View()
                    .environmentObject(viewModel)
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(selection == nil ? Color(UIColor.systemGray4) : Color(UIColor.primaryColor))
                    .foregroundColor(.white)
                    .cornerRadius(28)
            }
            .disabled(selection == nil)

        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.appBackground))
    }
}
