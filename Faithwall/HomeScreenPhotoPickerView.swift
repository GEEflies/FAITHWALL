import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

@available(iOS 16.0, *)
struct HomeScreenPhotoPickerView: View {
    @AppStorage("homeScreenPresetSelection") private var homeScreenPresetSelectionRaw = ""
    @Binding var isSavingHomeScreenPhoto: Bool
    @Binding var homeScreenStatusMessage: String?
    @Binding var homeScreenStatusColor: Color
    @Binding var homeScreenImageAvailable: Bool

    let handlePickedHomeScreenData: (Data) -> Void

    @State private var showSourceOptions = false
    @State private var activePicker: PickerType?
    @State private var isPhotoLibraryPickerPresented = false
    @State private var photoLibrarySelection: PhotosPickerItem?
    @State private var isHomeIconActive = false
    @State private var hasActivatedHomeThisSession = false
    @State private var showPresetPicker = false

    private var selectedPreset: PresetOption? {
        PresetOption(rawValue: homeScreenPresetSelectionRaw)
    }

    private enum PickerType: Identifiable {
        case camera
        case files

        var id: String {
            switch self {
            case .camera: return "camera"
            case .files: return "files"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { showSourceOptions = true }) {
                HStack(spacing: 12) {
                    Image(systemName: (homeScreenImageAvailable || !homeScreenPresetSelectionRaw.isEmpty) ? "photo.fill" : "photo")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isHomeIconActive ? .appAccent : .gray)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Home Screen Photo")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(isSavingHomeScreenPhoto ? "Saving…" : "Choose your own photo")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .buttonStyle(.plain)
            .disabled(isSavingHomeScreenPhoto)
            .contentShape(Rectangle())

            if let message = homeScreenStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(homeScreenStatusColor)
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: homeScreenImageAvailable)
        .confirmationDialog(
            "",
            isPresented: $showSourceOptions,
            titleVisibility: .hidden
        ) {
            Button(role: .none) {
                isPhotoLibraryPickerPresented = true
                showSourceOptions = false
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
                    .labelStyle(LeadingMenuLabelStyle())
            }

            Button(role: .none) {
                showSourceOptions = false
                showPresetPicker = true
            } label: {
                Label("Faith Wall Presets", systemImage: "rectangle.on.rectangle.angled")
                    .labelStyle(LeadingMenuLabelStyle())
            }

            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(
            isPresented: $isPhotoLibraryPickerPresented,
            selection: $photoLibrarySelection,
            matching: .images
        )
        .onChange(of: photoLibrarySelection) { newValue in
            guard let item = newValue else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            processPickedData(data)
                        }
                    } else {
                        await MainActor.run {
                            reportLoadFailure("Unable to load selected photo.")
                        }
                    }
                } catch {
                    await MainActor.run {
                        reportLoadFailure("Unable to load selected photo.")
                    }
                }

                await MainActor.run {
                    photoLibrarySelection = nil
                    isPhotoLibraryPickerPresented = false
                }
            }
        }
        .onChange(of: homeScreenImageAvailable) { _ in
            syncHomeIconState()
        }
        .onChange(of: homeScreenPresetSelectionRaw) { _ in
            syncHomeIconState()
        }
        .sheet(isPresented: $showPresetPicker) {
            PresetPickerSheet(
                selectedPreset: selectedPreset,
                onSelectPreset: { preset in
                    applyPreset(preset)
                    showPresetPicker = false
                }
            )
        }
        .onAppear {
            syncHomeIconState()
        }
    }

    private func reportLoadFailure(_ message: String) {
        DispatchQueue.main.async {
            homeScreenStatusMessage = message
            homeScreenStatusColor = .red
            isSavingHomeScreenPhoto = false
            isHomeIconActive = false
            hasActivatedHomeThisSession = false
        }
    }

    private func processPickedData(_ data: Data) {
        print("📸 HomeScreenPhotoPickerView: Processing picked photo data")
        DispatchQueue.main.async {
            handlePickedHomeScreenData(data)
            hasActivatedHomeThisSession = true
            // Clear preset selection when picking a custom photo
            homeScreenPresetSelectionRaw = ""
            print("✅ HomeScreenPhotoPickerView: Photo data processed successfully")
        }
    }

    private func syncHomeIconState() {
        if homeScreenImageAvailable || !homeScreenPresetSelectionRaw.isEmpty {
            isHomeIconActive = true
            hasActivatedHomeThisSession = true
        } else {
            isHomeIconActive = false
            hasActivatedHomeThisSession = false
        }
    }

    private func applyPreset(_ preset: PresetOption) {
        guard preset != selectedPreset else { return }

        // Light impact haptic for preset selection
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        isSavingHomeScreenPhoto = true
        homeScreenStatusMessage = "Applying \(preset.title.lowercased()) preset…"
        homeScreenStatusColor = .secondary

        applyPresetLocally(preset)
    }

    private func applyPresetLocally(_ preset: PresetOption) {
        let image = preset.generateGradientImage()

        do {
            // SIMPLE: Just save to HomeScreen folder
            // This is what the shortcut will read, whether it's a preset or custom photo
            try HomeScreenImageManager.saveHomeScreenImage(image)
            
            print("✅ Saved \(preset.title) preset to HomeScreen folder")
            print("   Path: HomeScreen/homescreen.jpg")

            homeScreenPresetSelectionRaw = preset.rawValue
            homeScreenImageAvailable = false
            
            // Update UI state
            isSavingHomeScreenPhoto = false
            homeScreenStatusMessage = nil
            homeScreenStatusColor = .gray
            
            // Force icon update
            syncHomeIconState()
            
        } catch {
            print("❌ Failed to save preset image: \(error)")
            reportLoadFailure("Failed to apply preset")
        }
    }
}

@available(iOS 16.0, *)
struct HomeScreenQuickPresetsView: View {
    @AppStorage("homeScreenPresetSelection") private var homeScreenPresetSelectionRaw = ""

    @Binding var isSavingHomeScreenPhoto: Bool
    @Binding var homeScreenStatusMessage: String?
    @Binding var homeScreenStatusColor: Color
    @Binding var homeScreenImageAvailable: Bool

    let handlePickedHomeScreenData: (Data) -> Void

    @State private var showPresetPicker = false

    private var selectedPreset: PresetOption? {
        PresetOption(rawValue: homeScreenPresetSelectionRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Presets")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: {
                showPresetPicker = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: selectedPreset != nil ? "rectangle.on.rectangle.angled.fill" : "rectangle.on.rectangle.angled")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(selectedPreset != nil ? .appAccent : .gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedPreset?.title ?? "Choose Presets")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(selectedPreset != nil ? "Tap to change preset" : "Select a gradient background")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 0)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .buttonStyle(.plain)
            .disabled(isSavingHomeScreenPhoto)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $showPresetPicker) {
            PresetPickerSheet(
                selectedPreset: selectedPreset,
                onSelectPreset: { preset in
                    applyPreset(preset)
                    showPresetPicker = false
                }
            )
        }
    }

    private func applyPreset(_ preset: PresetOption) {
        guard preset != selectedPreset else { return }

        // Light impact haptic for preset selection
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        isSavingHomeScreenPhoto = true
        homeScreenStatusMessage = "Applying \(preset.title.lowercased()) preset…"
        homeScreenStatusColor = .secondary

        applyPresetLocally(preset)
    }

    private func reportLoadFailure(_ message: String) {
        homeScreenStatusMessage = message
        homeScreenStatusColor = .red
        isSavingHomeScreenPhoto = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            homeScreenPresetSelectionRaw = selectedPreset?.rawValue ?? homeScreenPresetSelectionRaw
        }
    }

    private func applyPresetLocally(_ preset: PresetOption) {
        let image = preset.generateGradientImage()

        do {
            // SIMPLE: Just save to HomeScreen folder
            // This is what the shortcut will read, whether it's a preset or custom photo
            try HomeScreenImageManager.saveHomeScreenImage(image)
            
            print("✅ Saved \(preset.title) preset to HomeScreen folder")
            print("   Path: HomeScreen/homescreen.jpg")

            homeScreenPresetSelectionRaw = preset.rawValue
            homeScreenImageAvailable = false
            homeScreenStatusMessage = nil
            homeScreenStatusColor = .gray
            isSavingHomeScreenPhoto = false
        } catch {
            print("❌ Failed to save preset: \(error)")
            reportLoadFailure("Failed to save \(preset.title.lowercased()) preset.")
        }
    }
}

@available(iOS 16.0, *)
private struct LeadingMenuLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
            configuration.title
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 16.0, *)
struct LockScreenBackgroundPickerView: View {
    @Binding var isSavingBackground: Bool
    @Binding var statusMessage: String?
    @Binding var statusColor: Color
    @Binding var backgroundMode: LockScreenBackgroundMode
    @Binding var backgroundOption: LockScreenBackgroundOption
    @Binding var backgroundPhotoData: Data

    var backgroundPhotoAvailable: Bool

    @State private var showSourceOptions = false
    @State private var activePicker: PickerType?
    @State private var isLockIconActive = false
    @State private var hasActivatedLockThisSession = false
    @State private var isPhotoLibraryPickerPresented = false
    @State private var photoLibrarySelection: PhotosPickerItem?
    @State private var showPresetPicker = false

    private enum PickerType: Identifiable {
        case camera
        case files

        var id: String {
            switch self {
            case .camera: return "camera"
            case .files: return "files"
            }
        }
    }

    private var selectedPreset: PresetOption? {
        guard backgroundMode.presetOption != nil else { return nil }
        // Try to match the preset based on stored value
        return PresetOption.allCases.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showSourceOptions = true }) {
                HStack(spacing: 12) {
                    Image(systemName: backgroundMode == .photo && (!backgroundPhotoData.isEmpty || backgroundPhotoAvailable) ? "photo.fill" : "photo")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isLockIconActive ? .appAccent : .gray)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Lock Screen Photo")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(isSavingBackground ? "Saving…" : "Choose your own photo")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .buttonStyle(.plain)
            .disabled(isSavingBackground)
            .contentShape(Rectangle())

            if let message = statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(statusColor)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: backgroundMode)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isLockIconActive)
        .sheet(isPresented: $showPresetPicker) {
            PresetPickerSheet(
                selectedPreset: selectedPreset,
                onSelectPreset: { preset in
                    selectPreset(preset)
                    showPresetPicker = false
                }
            )
        }
        .confirmationDialog(
            "",
            isPresented: $showSourceOptions,
            titleVisibility: .hidden
        ) {
            Button(role: .none) {
                isPhotoLibraryPickerPresented = true
                showSourceOptions = false
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
                    .labelStyle(LeadingMenuLabelStyle())
            }

            Button(role: .none) {
                showSourceOptions = false
                showPresetPicker = true
            } label: {
                Label("Faith Wall Presets", systemImage: "rectangle.on.rectangle.angled")
                    .labelStyle(LeadingMenuLabelStyle())
            }

            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(
            isPresented: $isPhotoLibraryPickerPresented,
            selection: $photoLibrarySelection,
            matching: .images
        )
        .onChange(of: photoLibrarySelection) { newValue in
            guard let item = newValue else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            processPickedData(data)
                        }
                    } else {
                        await MainActor.run {
                            reportFailure("Unable to load selected photo.")
                        }
                    }
                } catch {
                    await MainActor.run {
                        reportFailure("Unable to load selected photo.")
                    }
                }

                await MainActor.run {
                    photoLibrarySelection = nil
                    isPhotoLibraryPickerPresented = false
                }
            }
        }
        .onChange(of: backgroundMode) { _ in
            syncLockIconState()
        }
        .onChange(of: backgroundPhotoData) { _ in
            syncLockIconState()
        }
        .sheet(item: $activePicker) { picker in
            switch picker {
            case .camera:
                CameraPickerView { image in
                    guard let data = image.jpegData(compressionQuality: 0.95) ?? image.pngData() else {
                        reportFailure("Unable to process captured photo.")
                        return
                    }
                    processPickedData(data)
                } onCancel: {
                    activePicker = nil
                } onDismiss: {
                    activePicker = nil
                }

            case .files:
                DocumentPickerView { data in
                    processPickedData(data)
                } onError: { message in
                    reportFailure(message)
                } onCancel: {
                    activePicker = nil
                } onDismiss: {
                    activePicker = nil
                }
            }
        }
        .onAppear {
            syncLockIconState()
        }
    }

    private func reportFailure(_ message: String) {
        statusMessage = message
        statusColor = .red
        isSavingBackground = false
        isLockIconActive = false
        hasActivatedLockThisSession = false
    }

    private func processPickedData(_ data: Data) {
        print("📸 LockScreenBackgroundPickerView: Processing picked photo data")
        print("   Data size: \(data.count) bytes")
        isSavingBackground = true
        statusMessage = "Saving background…"
        statusColor = .secondary

        Task {
            do {
                guard let image = UIImage(data: data) else {
                    throw HomeScreenImageManagerError.unableToEncodeImage
                }
                print("   Image size: \(image.size)")
                
                guard let prepared = Self.preparedBackgroundImage(from: image) else {
                    throw HomeScreenImageManagerError.unableToEncodeImage
                }
                print("   Prepared image size: \(prepared.image.size)")
                
                // Save to file system for wallpaper generation
                try HomeScreenImageManager.saveLockScreenBackgroundSource(prepared.image)
                print("✅ Saved lock screen background to TextEditor folder")
                
                if let url = HomeScreenImageManager.lockScreenBackgroundSourceURL() {
                    print("   File path: \(url.path)")
                    print("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
                }
                
                await MainActor.run {
                    // Set photo data and mode
                    backgroundPhotoData = prepared.data
                    backgroundMode = .photo
                    backgroundOption = .black // Set a default option when using photo
                    
                    // Update UI state
                    isSavingBackground = false
                    statusMessage = nil
                    statusColor = .gray
                    
                    // Activate the icon to show cyan color
                    isLockIconActive = true
                    hasActivatedLockThisSession = true
                    
                    print("✅ LockScreenBackgroundPickerView: Photo data processed successfully")
                    print("   Mode set to: .photo")
                    print("   Photo data bytes: \(backgroundPhotoData.count)")
                    print("   Icon activated: true")
                }
            } catch {
                print("❌ LockScreenBackgroundPickerView: Failed to save photo: \(error)")
                await MainActor.run {
                    reportFailure("Unable to save selected photo: \(error.localizedDescription)")
                    isSavingBackground = false
                }
            }
        }
    }

    private func selectPreset(_ preset: PresetOption) {
        print("🎨 LockScreenBackgroundPickerView: Selecting preset \(preset.title)")
        
        // Light impact haptic for preset selection
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        isSavingBackground = true
        statusMessage = "Applying \(preset.title.lowercased()) preset…"
        statusColor = .secondary
        
        // Clear photo data and file system storage
        print("   Clearing photo data and removing background file...")
        backgroundPhotoData = Data()
        HomeScreenImageManager.removeLockScreenBackgroundSource()
        
        // Generate and save the gradient image
        let image = preset.generateGradientImage()
        
        do {
            try HomeScreenImageManager.saveLockScreenBackgroundSource(image)
            print("✅ Saved gradient preset to TextEditor folder")
            
            // Set the preset mode
            backgroundOption = .black // Legacy compatibility
            backgroundMode = .photo // Use photo mode since we saved an image
            
            isSavingBackground = false
            statusMessage = nil
            statusColor = .gray
            
            print("   ✅ Preset applied")
            print("   ℹ️  User must click 'Update Wallpaper Now' to apply")
        } catch {
            print("❌ Failed to save preset: \(error)")
            isSavingBackground = false
            statusMessage = "Failed to save \(preset.title.lowercased()) preset."
            statusColor = .red
        }
        
        // Update icon state
        isLockIconActive = false
        hasActivatedLockThisSession = false
        
        // Don't trigger automatic update - let user click "Update Wallpaper Now" button
        // This matches the Home Screen preset behavior
    }

    private func syncLockIconState() {
        // Check if we have a photo in memory OR a saved background file (from preset or photo)
        let hasBackgroundFile = HomeScreenImageManager.lockScreenBackgroundSourceURL().map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let shouldActivate = backgroundMode == .photo && (!backgroundPhotoData.isEmpty || hasBackgroundFile)
        print("🔄 LockScreenBackgroundPickerView: syncLockIconState -> mode=\(backgroundMode), photoDataEmpty=\(backgroundPhotoData.isEmpty), hasFile=\(hasBackgroundFile)")
        if shouldActivate {
            isLockIconActive = true
            hasActivatedLockThisSession = true
        } else {
            isLockIconActive = false
            hasActivatedLockThisSession = false
        }
        print("   Icon active: \(isLockIconActive)")
    }

    private static func preparedBackgroundImage(from image: UIImage) -> (image: UIImage, data: Data)? {
        let sizeLimit = 2_500_000 // Keep comfortably under the 4 MB AppStorage ceiling
        let minDimension: CGFloat = 1200
        var targetMaxDimension: CGFloat = min(2048, max(image.size.width, image.size.height))

        var bestData: Data?
        var bestImage: UIImage?

        for _ in 0..<6 {
            let scale = min(1, targetMaxDimension / max(image.size.width, image.size.height))
            let targetSize = CGSize(
                width: max(1, image.size.width * scale),
                height: max(1, image.size.height * scale)
            )

            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            format.opaque = true // JPEG has no alpha channel; marking opaque saves bytes

            let normalizedImage = renderNormalizedImage(image, targetSize: targetSize, format: format)

            var quality: CGFloat = 0.8
            while quality >= 0.35 {
                if let data = normalizedImage.jpegData(compressionQuality: quality) {
                    if data.count <= sizeLimit {
                        return (normalizedImage, data)
                    }

                    if bestData == nil || data.count < (bestData?.count ?? .max) {
                        bestData = data
                        bestImage = normalizedImage
                    }
                }
                quality -= 0.1
            }

            if targetMaxDimension <= minDimension {
                // We're already quite small; give back the lowest-quality attempt we have.
                if let data = normalizedImage.jpegData(compressionQuality: 0.35) {
                    return (normalizedImage, data)
                }
                break
            }

            targetMaxDimension *= 0.75
        }

    guard let data = bestData, let bestImage else {
            guard let fallbackData = image.jpegData(compressionQuality: 0.4) else { return nil }
            return (image, fallbackData)
        }

        return (bestImage, data)
    }

    private static func renderNormalizedImage(_ image: UIImage, targetSize: CGSize, format: UIGraphicsImageRendererFormat) -> UIImage {
        if image.imageOrientation == .up {
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }

        guard let cgImage = image.cgImage else {
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }

        let exifOrientation = exifOrientation(for: image.imageOrientation)
        let ciImage = CIImage(cgImage: cgImage).oriented(forExifOrientation: exifOrientation)
        guard let outputCGImage = sharedCIContext.createCGImage(ciImage, from: ciImage.extent) else {
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }

        let orientedImage = UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            orientedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private static let sharedCIContext = CIContext(options: [.useSoftwareRenderer: false])

    private static func exifOrientation(for orientation: UIImage.Orientation) -> Int32 {
        switch orientation {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default: return 1
        }
    }
}

// MARK: - Camera Picker

@available(iOS 16.0, *)
private struct CameraPickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let onCancel: () -> Void
        private let onDismiss: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void, onDismiss: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
            self.onDismiss = onDismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            } else {
                onCancel()
            }
            picker.dismiss(animated: true) {
                self.onDismiss()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
            picker.dismiss(animated: true) {
                self.onDismiss()
            }
        }
    }
}

// MARK: - Photo Library Picker

// MARK: - Document Picker

@available(iOS 16.0, *)
private struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onError: onError, onCancel: onCancel, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.image], asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        
        // Try to set initial directory to "On My iPhone" if possible
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            controller.directoryURL = documentsURL
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (Data) -> Void
        private let onError: (String) -> Void
        private let onCancel: () -> Void
        private let onDismiss: () -> Void

        init(onPick: @escaping (Data) -> Void, onError: @escaping (String) -> Void, onCancel: @escaping () -> Void, onDismiss: @escaping () -> Void) {
            self.onPick = onPick
            self.onError = onError
            self.onCancel = onCancel
            self.onDismiss = onDismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                DispatchQueue.main.async {
                    self.onError("No file selected.")
                    self.onCancel()
                    self.onDismiss()
                }
                return
            }

            do {
                let data = try Data(contentsOf: url)
                DispatchQueue.main.async {
                    self.onPick(data)
                    self.onDismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError("Unable to read selected file.")
                    self.onDismiss()
                }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            DispatchQueue.main.async {
                self.onCancel()
                self.onDismiss()
            }
        }
    }
}

// MARK: - Preset Picker Sheet

@available(iOS 16.0, *)
struct PresetPickerSheet: View {
    let selectedPreset: PresetOption?
    let onSelectPreset: (PresetOption) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Choose a beautiful gradient background for your wallpaper")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(PresetOption.allCases) { preset in
                            Button(action: {
                                onSelectPreset(preset)
                            }) {
                                VStack(spacing: 8) {
                                    // Gradient preview
                                    ZStack {
                                        LinearGradient(
                                            colors: preset.gradientColors,
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .aspectRatio(9/16, contentMode: .fit)
                                        .cornerRadius(12)
                                        
                                        if selectedPreset == preset {
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(Color.appAccent, lineWidth: 3)
                                            
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 30))
                                                .foregroundColor(.appAccent)
                                                .background(
                                                    Circle()
                                                        .fill(Color.white)
                                                        .frame(width: 26, height: 26)
                                                )
                                        }
                                    }
                                    
                                    Text(preset.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Choose Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
