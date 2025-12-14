import SwiftUI
import UIKit

// MARK: - Genre Row Component
struct GenreOptionRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var backgroundColor: Color {
        isSelected ? Color(UIColor.secondaryColor) : Color(UIColor.lightGray)
    }

    var textColor: Color {
        isSelected ? .white : .black
    }

    var scaleAmount: CGFloat {
        isSelected ? 1.02 : 1.0
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(icon)
                Text(title)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)            // <- full width on iPad
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(12)
            .scaleEffect(scaleAmount)
        }
    }
}

// MARK: - Genre Scroll List
struct GenreListScrollView: View {
    @Binding var selection: String?
    @EnvironmentObject var viewModel: OnboardingViewModel

    let genres: [(String, String)]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(genres, id: \.1) { icon, genre in
                    GenreOptionRow(
                        icon: icon,
                        title: genre,
                        isSelected: selection == genre,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selection = genre
                                viewModel.selectedGenre = genre
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity)              // <- expands list width
        }
        .frame(maxHeight: .infinity)                 // <- no shrinking on iPad
    }
}

// MARK: - Main Question 1 View
struct OnboardingQuestion1View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selection: String?

    let genres = [
        ("🕺", "Pop"),
        ("🎸", "Rock"),
        ("🎼", "Classical"),
        ("💖", "Romantic / Ballads"),
        ("🎬", "Movie & Anime themes"),
        ("🎹", "Lo-Fi / Chill"),
        ("🌍", "Instrumental / World")
    ]

    var horizontalPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 180 : 24
    }

    var body: some View {
        VStack(spacing: 24) {

            ProgressIndicator(step: 1)

            Text("What kind of music gets you in the groove?")
                .font(.title2.bold())
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("We'll use this to recommend songs you'll actually love playing.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            GenreListScrollView(selection: $selection, genres: genres)
                .environmentObject(viewModel)

            NavigationLink {
                OnboardingQuestion2View().environmentObject(viewModel)
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(selection == nil ? .gray : Color(UIColor.secondaryColor))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(selection == nil)

            Spacer()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // <- critical for iPad full expansion
        .background(Color(UIColor.appBackground))
    }
}
