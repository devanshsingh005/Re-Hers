import PhotosUI
import SwiftUI

/// Minimal on-device check of OemerKit: Core ML self-test, timed transcriptions of the bundled
/// tabi.jpg with thermal state and memory, and a photo picker for your own pages.
@main
struct OemerTestApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @StateObject private var bench = Benchmark()
    @State private var photo: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(bench.lines.enumerated()), id: \.offset) { i, line in
                            Text(line).font(.system(.caption, design: .monospaced)).id(i)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
                }
                .task(id: bench.lines.count) { proxy.scrollTo(bench.lines.count - 1, anchor: .bottom) }
            }
            .navigationTitle("OemerKit Test")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button {
                        Task { await bench.runAll(repeats: Benchmark.autorunRepeats ?? 3) }
                    } label: {
                        Label("Benchmark", systemImage: "play.fill")
                    }
                    .disabled(bench.running)
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("Photo", systemImage: "photo")
                    }
                    .disabled(bench.running)
                    ShareLink(item: bench.reportURL) { Image(systemName: "square.and.arrow.up") }
                        .disabled(bench.running || bench.lines.isEmpty)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
        }
        .task { if let n = Benchmark.autorunRepeats { await bench.runAll(repeats: n) } }
        .task(id: photo) {
            guard let item = photo else { return }
            await bench.transcribe(item)
            photo = nil  // so the same photo can be picked again
        }
    }
}
