import SwiftUI
import AVFoundation
import PhotosUI

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
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                // Take photo
                                capturePhoto()
                            }) {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 50, height: 50)
                                    )
                            }
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.width * 4/3)
                    .background(Color.clear)
                }
                // Photo Library
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(selectedPhotos, id: \.self) { image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .onTapGesture {
                                        selectedLibraryPhoto = image
                                    }
                                if selectedLibraryPhoto == image {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.white)
                                                .font(.system(size: 14, weight: .bold))
                                        )
                                        .padding(6)
                                }
                            }
                        }
                    }
                }
                .frame(height: 80)
                .background(Color.black)
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
        fetchOptions.fetchLimit = 10
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        
        fetchResult.enumerateObjects { (asset, _, _) in
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: requestOptions) { image, _ in
                if let image = image {
                    DispatchQueue.main.async {
                        selectedPhotos.append(image)
                    }
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