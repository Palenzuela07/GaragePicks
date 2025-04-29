import SwiftUI
import AVFoundation
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct CameraView: View {
    @Binding var selectedImages: [UIImage]
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    @State private var isCameraAuthorized = false
    @State private var isPhotoLibraryAuthorized = false
    @State private var showPhotoLibrary = false
    @State private var cameraSession: AVCaptureSession?
    @State private var cameraPreview: AVCaptureVideoPreviewLayer?
    @State private var selectedPhotos: [UIImage] = []
    @State private var selectedLibraryPhotos: [UIImage] = []
    @State private var selectedPhotoAssets: [PHAsset] = []
    @State private var selectedLibraryAssets: Set<PHAsset> = []
    @State private var photoOutput: AVCapturePhotoOutput?
    @State private var libraryPhotos: [UIImage] = []
    @State private var libraryAssets: [PHAsset] = []
    @State private var capturedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var showPhotoLimitAlert = false
    
    private let maxPhotos = 6
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    if let preview = cameraPreview {
                        CameraPreviewView(preview: preview)
                            .frame(width: geometry.size.width, height: geometry.size.width * 4/3)
                            .clipped()
                    } else {
                        Color.black
                            .frame(width: geometry.size.width, height: geometry.size.width * 4/3)
                    }

                    VStack {
                        // Top bar with blur background
                        HStack {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            Spacer()
                            if !selectedPhotos.isEmpty || !selectedLibraryPhotos.isEmpty {
                                HStack(spacing: 8) {
                                    Text("\(selectedPhotos.count + selectedLibraryPhotos.count)/\(maxPhotos)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.5))
                                        .cornerRadius(12)
                                    
                                Button(action: {
                                        selectedImages = selectedPhotos + selectedLibraryPhotos
                                        presentationMode.wrappedValue.dismiss()
                                }) {
                                    HStack(spacing: 4) {
                                            Text("Done")
                                            .font(.headline)
                                            Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(16)
                                    }
                                }
                                .padding(.trailing, 8)
                            }
                            Button(action: {
                                // Switch camera
                            }) {
                                Image(systemName: "camera.rotate")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        .padding(.top, 44)
                        .background(
                            VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                                .edgesIgnoringSafeArea(.top)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2), radius: 8, y: 2)
                        
                        // Show selected photos in a horizontal scroll view
                        if !selectedPhotos.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(selectedPhotos.enumerated()), id: \.offset) { index, photo in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: photo)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 60, height: 60)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            Button(action: {
                                                removeCapturedPhoto(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.5))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(height: 70)
                        }
                        
                        Spacer()
                        HStack(spacing: 20) {
                            Button(action: {
                                isShowingImagePicker = true
                            }) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: {
                                capturePhoto()
                            }) {
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 60, height: 60)
                                    )
                            }
                            
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.bottom, 30)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.width * 4/3)
                    .background(Color.clear)
                }
                // Photo Library
                VStack(spacing: 6) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 6)
                    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(libraryPhotos.enumerated()), id: \.offset) { idx, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(selectedLibraryAssets.contains(libraryAssets[idx]) ? Color.blue : Color.clear, lineWidth: 4)
                                        )
                                        .shadow(color: selectedLibraryAssets.contains(libraryAssets[idx]) ? Color.blue.opacity(0.2) : Color.black.opacity(0.1), radius: 8, y: 2)
                                    if selectedLibraryAssets.contains(libraryAssets[idx]) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 16, weight: .bold))
                                            )
                                            .padding(8)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleAssetSelection(libraryAssets[idx])
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
                .frame(height: 370)
                .background(
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2), radius: 8, y: -2)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            checkCameraAuthorization()
            checkPhotoLibraryAuthorization()
            setupCamera()
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImages: $selectedImages, sourceType: .photoLibrary)
        }
    }
    
    private func checkCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                isCameraAuthorized = granted
            }
        default:
            isCameraAuthorized = false
        }
    }
    
    private func checkPhotoLibraryAuthorization() {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            isPhotoLibraryAuthorized = true
            loadPhotos()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    isPhotoLibraryAuthorized = true
                    loadPhotos()
                }
            }
        default:
            isPhotoLibraryAuthorized = false
        }
    }
    
    private func setupCamera() {
        guard isCameraAuthorized else { return }
        
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            photoOutput = output
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        
        cameraSession = session
        cameraPreview = preview
    }
    
    private func capturePhoto() {
        let totalSelectedCount = selectedPhotos.count + selectedLibraryPhotos.count
        if totalSelectedCount < maxPhotos {
            guard let output = photoOutput else { return }
            
            let settings = AVCapturePhotoSettings()
            output.capturePhoto(with: settings, delegate: PhotoCaptureDelegate { image in
                if let image = image {
                    DispatchQueue.main.async {
                        selectedPhotos.append(image)
                        // Create a PHAsset for the captured photo
                        let fetchOptions = PHFetchOptions()
                        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                        fetchOptions.fetchLimit = 1
                        
                        if let asset = PHAsset.fetchAssets(with: .image, options: fetchOptions).firstObject {
                            selectedPhotoAssets.append(asset)
                        }
                    }
                }
            })
        }
    }
    
    private func loadPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 30
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        
        var tempImages: [UIImage] = []
        var tempAssets: [PHAsset] = []
        fetchResult.enumerateObjects { (asset, _, _) in
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: requestOptions) { image, _ in
                if let image = image {
                    DispatchQueue.main.async {
                        tempImages.append(image)
                        tempAssets.append(asset)
                        if tempImages.count == fetchResult.count {
                            libraryPhotos = tempImages
                            libraryAssets = tempAssets
                        }
                    }
                }
            }
        }
    }
    
    private func toggleAssetSelection(_ asset: PHAsset) {
        if selectedLibraryAssets.contains(asset) {
            selectedLibraryAssets.remove(asset)
            if let index = selectedLibraryPhotos.firstIndex(where: { _ in true }) {
                selectedLibraryPhotos.remove(at: index)
            }
        } else {
            let totalSelectedCount = selectedPhotos.count + selectedLibraryPhotos.count
            if totalSelectedCount < maxPhotos {
                selectedLibraryAssets.insert(asset)
                fetchFullSizeImage(for: asset)
            }
        }
    }
    
    private func fetchFullSizeImage(for asset: PHAsset) {
        let totalSelectedCount = selectedPhotos.count + selectedLibraryPhotos.count
        if totalSelectedCount < maxPhotos {
            let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
            
            manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                        selectedLibraryPhotos.append(image)
                    }
                }
            }
        }
    }
    
    // Add a function to remove a captured photo
    private func removeCapturedPhoto(at index: Int) {
        if index < selectedPhotos.count {
            selectedPhotos.remove(at: index)
            if index < selectedPhotoAssets.count {
                selectedPhotoAssets.remove(at: index)
            }
        }
    }
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            completion(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completion(nil)
            return
        }
        
        completion(image)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let preview: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// VisualEffectBlur for SwiftUI
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// Helper extension for safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 