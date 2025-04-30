import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct CameraView: View {
    @Binding var selectedImages: [UIImage]
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    @State private var isPhotoLibraryAuthorized = false
    @State private var showPhotoLibrary = false
    @State private var selectedPhotos: [UIImage] = []
    @State private var selectedLibraryPhotos: [UIImage] = []
    @State private var selectedPhotoAssets: [PHAsset] = []
    @State private var selectedLibraryAssets: Set<PHAsset> = []
    @State private var libraryPhotos: [UIImage] = []
    @State private var libraryAssets: [PHAsset] = []
    @State private var isShowingImagePicker = false
    @State private var showPhotoLimitAlert = false
    
    private let maxPhotos = 6
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                        // Top bar with blur background
                        HStack {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.title2)
                            .foregroundColor(.primary)
                                    .padding()
                            }
                            Spacer()
                            if !selectedPhotos.isEmpty || !selectedLibraryPhotos.isEmpty {
                                HStack(spacing: 8) {
                                    Text("\(selectedPhotos.count + selectedLibraryPhotos.count)/\(maxPhotos)")
                                        .font(.headline)
                                .foregroundColor(.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                .background(Color(.systemGray6))
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
                                .background(Color(.systemBackground))
                                    .cornerRadius(16)
                                    }
                                }
                                .padding(.trailing, 8)
                            }
                        }
                        .padding(.top, 44)
                        .background(
                    VisualEffectBlur(blurStyle: .systemMaterial)
                                .edgesIgnoringSafeArea(.top)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color(.systemGray4), radius: 8, y: 2)
                        
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
                        
                // Photo Library
                VStack(spacing: 6) {
                    Capsule()
                        .fill(Color(.systemGray4))
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
                                        .shadow(color: selectedLibraryAssets.contains(libraryAssets[idx]) ? Color.blue.opacity(0.2) : Color(.systemGray4), radius: 8, y: 2)
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
                .frame(height: max(geometry.size.height - 200, 0))
                .background(
                    VisualEffectBlur(blurStyle: .systemMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color(.systemGray4), radius: 8, y: -2)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            checkPhotoLibraryAuthorization()
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
                    DispatchQueue.main.async {
                        self.isPhotoLibraryAuthorized = true
                        self.loadPhotos()
                    }
                }
            }
        default:
            isPhotoLibraryAuthorized = false
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
    
    private func removeCapturedPhoto(at index: Int) {
        if index < selectedPhotos.count {
            selectedPhotos.remove(at: index)
            }
        }
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