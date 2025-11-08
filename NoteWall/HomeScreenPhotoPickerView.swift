import SwiftUI
import PhotosUI

@available(iOS 16.0, *)
struct HomeScreenPhotoPickerView: View {
    @Binding var isSavingHomeScreenPhoto: Bool
    @Binding var homeScreenStatusMessage: String?
    @Binding var homeScreenStatusColor: Color
    @Binding var homeScreenImageAvailable: Bool

    let handlePickedHomeScreenPhoto: (PhotosPickerItem?) -> Void
    @State private var selectedHomeScreenPhoto: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotosPicker(selection: $selectedHomeScreenPhoto, matching: .images) {
                HStack {
                    Image(systemName: "photo")
                        .foregroundColor(.blue)
                    Text(isSavingHomeScreenPhoto ? "Saving…" : "Pick Photo")
                        .foregroundColor(.blue)
                    Spacer()
                    if homeScreenImageAvailable {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .disabled(isSavingHomeScreenPhoto)
            .onChange(of: selectedHomeScreenPhoto) { newValue in
                handlePickedHomeScreenPhoto(newValue)
            }

            if let message = homeScreenStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(homeScreenStatusColor)
            }
        }
    }
}

