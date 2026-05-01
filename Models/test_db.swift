import Foundation

struct PlaylistQueryResponse: Codable {
    let id: String
    let cover_image_url: String?
}

// Just checking if we can compile and run a simple test or read files
func testDBConnection() {
    print("Test script ready")
}
