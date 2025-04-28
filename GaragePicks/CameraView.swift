import SwiftUI
import AVFoundation
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct CameraView: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    @State private var isCameraAuthorized = false
    @State private var isPhotoLibraryAuthorized = false
    @State private var showPhotoLibrary = false
    @State private var cameraSession: AVCaptureSession?
    @State private var cameraPreview: AVCaptureVideoPreviewLayer?
    @State private var selectedPhotos: [UIImage] = []
    @State private var selectedLibraryPhoto: UIImage? = nil
    @State private var selectedPhotoAssets: [PHAsset] = []
    
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
                            if selectedLibraryPhoto != nil {
                                Button(action: {
                                    if let selected = selectedLibraryPhoto {
                                        selectedImage = selected
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Text("Next")
                                            .font(.headline)
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(16)
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
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                // Take photo
                                capturePhoto()
                            }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                                    .shadow(color: Color.black.opacity(0.25), radius: 8, y: 2)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                            .frame(width: 60, height: 60)
                                    )
                            }
                            Spacer()
                        }
                        .padding(.bottom, 36)
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
                            ForEach(Array(selectedPhotos.enumerated()), id: \.offset) { idx, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(selectedLibraryPhoto == image ? Color.blue : Color.clear, lineWidth: 4)
                                        )
                                        .shadow(color: selectedLibraryPhoto == image ? Color.blue.opacity(0.2) : Color.black.opacity(0.1), radius: 8, y: 2)
                                        .onTapGesture {
                                            fetchFullSizeImage(for: selectedPhotoAssets[idx])
                                        }
                                    if selectedLibraryPhoto == image {
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
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        
        cameraSession = session
        cameraPreview = preview
    }
    
    private func capturePhoto() {
        // Implement photo capture
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
                            selectedPhotos = tempImages
                            selectedPhotoAssets = tempAssets
                        }
                    }
                }
            }
        }
    }
    
    private func fetchFullSizeImage(for asset: PHAsset) {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true
        let targetSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    selectedLibraryPhoto = image
                    selectedImage = image
                }
            }
        }
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