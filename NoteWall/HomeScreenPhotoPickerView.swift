import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

@available(iOS 16.0, *)
struct HomeScreenPhotoPickerView: View {
    @Binding var isSavingHomeScreenPhoto: Bool
    @Binding var homeScreenStatusMessage: String?
    @Binding var homeScreenStatusColor: Color
    @Binding var homeScreenImageAvailable: Bool

    let handlePickedHomeScreenData: (Data) -> Void

    @State private var showSourceOptions = false
    @State private var activePicker: PickerType?

    private enum PickerType: Identifiable {
        case camera
        case photoLibrary
        case files

        var id: String {
            switch self {
            case .camera: return "camera"
            case .photoLibrary: return "photoLibrary"
            case .files: return "files"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { showSourceOptions = true }) {
                HStack(spacing: 12) {
                    Image(systemName: homeScreenImageAvailable ? "photo.fill" : "photo")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(homeScreenImageAvailable ? .blue : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(homeScreenImageAvailable ? "Home Screen Photo" : "Add Home Screen Photo")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(isSavingHomeScreenPhoto ? "Saving…" : "Choose a photo to keep your Home Screen consistent.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.tertiaryLabel)
                }
            }
            .buttonStyle(.plain)
            .disabled(isSavingHomeScreenPhoto)
            .contentShape(Rectangle())

            Divider()

            if let message = homeScreenStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(homeScreenStatusColor)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: homeScreenImageAvailable)
        .confirmationDialog(
            "Add Home Screen Photo",
            isPresented: $showSourceOptions,
            titleVisibility: .visible
        ) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button(role: .none) {
                        activePicker = .camera
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }

            Button(role: .none) {
                activePicker = .photoLibrary
            } label: {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
            }

            Button(role: .none) {
                activePicker = .files
            } label: {
                Label("Browse Files", systemImage: "folder")
            }

            Button("Cancel", role: .cancel) { }
        }
        .sheet(item: $activePicker) { picker in
            switch picker {
            case .camera:
                CameraPickerView { image in
                    guard let data = image.jpegData(compressionQuality: 0.95) ?? image.pngData() else {
                        reportLoadFailure("Unable to process captured photo.")
                        activePicker = nil
                        return
                    }
                    processPickedData(data)
                    activePicker = nil
                } onCancel: {
                    activePicker = nil
                }

            case .photoLibrary:
                PhotoLibraryPickerView { data in
                    processPickedData(data)
                    activePicker = nil
                } onError: { message in
                    reportLoadFailure(message)
                    activePicker = nil
                } onCancel: {
                    activePicker = nil
                }

            case .files:
                DocumentPickerView { data in
                    processPickedData(data)
                    activePicker = nil
                } onError: { message in
                    reportLoadFailure(message)
                    activePicker = nil
                } onCancel: {
                    activePicker = nil
                }
            }
        }
    }

    private func selectionRow(icon: String, title: String, showCheckmark: Bool = false) -> some View {
                HStack {
            Image(systemName: icon)
                        .foregroundColor(.blue)
            Text(title)
                        .foregroundColor(.blue)
                    Spacer()
            if showCheckmark {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

    private func reportLoadFailure(_ message: String) {
        DispatchQueue.main.async {
            homeScreenStatusMessage = message
            homeScreenStatusColor = .red
        }
    }

    private func processPickedData(_ data: Data) {
        DispatchQueue.main.async {
            handlePickedHomeScreenData(data)
        }
    }
}

// MARK: - Camera Picker

@available(iOS 16.0, *)
private struct CameraPickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let onCancel: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            } else {
                onCancel()
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Photo Library Picker

@available(iOS 16.0, *)
private struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onError: onError, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPick: (Data) -> Void
        private let onError: (String) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (Data) -> Void, onError: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onError = onError
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                onCancel()
                picker.dismiss(animated: true)
                return
            }

            let typeIdentifier = UTType.image.identifier

            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                DispatchQueue.main.async {
                    if let data, !data.isEmpty {
                        self.onPick(data)
                    } else {
                        self.onError("Unable to load selected photo.")
                    }
                }
            }

            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Picker

@available(iOS 16.0, *)
private struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onError: onError, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.image], asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (Data) -> Void
        private let onError: (String) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (Data) -> Void, onError: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onError = onError
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                DispatchQueue.main.async {
                    self.onError("No file selected.")
                    self.onCancel()
                }
                return
            }

            do {
                let data = try Data(contentsOf: url)
                DispatchQueue.main.async {
                    self.onPick(data)
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError("Unable to read selected file.")
                }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            DispatchQueue.main.async {
                self.onCancel()
            }
        }
    }
}
