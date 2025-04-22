//
//  ContentView.swift
//  GaragePicks
//
//  Created by Michael Palenzuela on 4/21/25.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var isImagePickerPresented = false
    @State private var analysisResults: String = ""
    @State private var isAnalyzing: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .cornerRadius(10)
            } else {
                Image(systemName: "photo")
                    .imageScale(.large)
                    .font(.system(size: 100))
                    .foregroundColor(.gray)
                    .frame(height: 300)
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    isImagePickerPresented = true
                }) {
                    Text("Choose Photo")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    analyzePhoto()
                }) {
                    Text(isAnalyzing ? "Analyzing..." : "Analyze")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedImage == nil ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(selectedImage == nil || isAnalyzing)
            }
            .padding(.horizontal)
            
            if !analysisResults.isEmpty {
                Text("Analysis Results:")
                    .font(.headline)
                    .padding(.top)
                
                ScrollView {
                    Text(analysisResults)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }
    
    func analyzePhoto() {
        guard let image = selectedImage else { return }
        
        isAnalyzing = true
        analysisResults = "Analyzing image..."
        
        // Convert UIImage to base64 string
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            analysisResults = "Error: Could not convert image to data"
            isAnalyzing = false
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Prepare the Vision API request
        let apiKey = "YOUR_GOOGLE_API_KEY"
        let url = URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(apiKey)")!
        
        // Break down the complex dictionary into smaller parts
        let imageContent: [String: Any] = ["content": base64Image]
        
        let labelDetection: [String: Any] = ["type": "LABEL_DETECTION", "maxResults": 10]
        let textDetection: [String: Any] = ["type": "TEXT_DETECTION", "maxResults": 5]
        let objectLocalization: [String: Any] = ["type": "OBJECT_LOCALIZATION", "maxResults": 5]
        
        let features: [[String: Any]] = [labelDetection, textDetection, objectLocalization]
        
        let request: [String: Any] = ["image": imageContent, "features": features]
        
        let requestBody: [String: Any] = ["requests": [request]]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            analysisResults = "Error: Could not serialize request"
            isAnalyzing = false
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            DispatchQueue.main.async {
                isAnalyzing = false
                
                if let error = error {
                    analysisResults = "Error: \(error.localizedDescription)"
                    return
                }
                
                // Check HTTP response status
                if let httpResponse = response as? HTTPURLResponse {
                    print("Response status code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode != 200 {
                        if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                            print("API Error Response: \(errorMessage)")
                            
                            if httpResponse.statusCode == 403 {
                                analysisResults = "API Error (403 Forbidden): Vision API access denied.\n\nTroubleshooting:\n• Verify API key is correct\n• Enable Vision API in Google Cloud Console\n• Enable billing for your Google Cloud project\n• Check API key restrictions"
                            } else {
                                analysisResults = "API Error (\(httpResponse.statusCode)): \(errorMessage)"
                            }
                        } else {
                            if httpResponse.statusCode == 403 {
                                analysisResults = "API Error (403 Forbidden): Vision API access denied.\n\nTroubleshooting:\n• Verify API key is correct\n• Enable Vision API in Google Cloud Console\n• Enable billing for your Google Cloud project\n• Check API key restrictions"
                            } else {
                                analysisResults = "API Error: Status code \(httpResponse.statusCode)"
                            }
                        }
                        return
                    }
                }
                
                guard let data = data else {
                    analysisResults = "Error: No data received"
                    return
                }
                
                // Print raw response for debugging
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("Raw API response: \(rawResponse)")
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        analysisResults = "Error: Could not parse JSON response"
                        return
                    }
                    
                    // Handle case where responses array might be empty
                    guard let responses = json["responses"] as? [[String: Any]], !responses.isEmpty else {
                        analysisResults = "Error: Empty response from API"
                        return
                    }
                    
                    guard let firstResponse = responses.first else {
                        analysisResults = "Error: Invalid response format"
                        return
                    }
                    
                    // Check if there's an error in the response
                    if let error = firstResponse["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        analysisResults = "API Error: \(message)"
                        return
                    }
                    
                    var results = ""
                    
                    // Process label annotations
                    if let labelAnnotations = firstResponse["labelAnnotations"] as? [[String: Any]] {
                        results += "Labels:\n"
                        for label in labelAnnotations {
                            if let description = label["description"] as? String,
                               let score = label["score"] as? Double {
                                let percentage = Int(score * 100)
                                results += "• \(description): \(percentage)%\n"
                            }
                        }
                        results += "\n"
                    }
                    
                    // Process text annotations
                    if let textAnnotations = firstResponse["textAnnotations"] as? [[String: Any]],
                       !textAnnotations.isEmpty,
                       let textDescription = textAnnotations[0]["description"] as? String {
                        results += "Text detected:\n\(textDescription)\n\n"
                    }
                    
                    // Process object annotations
                    if let objectAnnotations = firstResponse["localizedObjectAnnotations"] as? [[String: Any]] {
                        results += "Objects:\n"
                        for object in objectAnnotations {
                            if let name = object["name"] as? String,
                               let score = object["score"] as? Double {
                                let percentage = Int(score * 100)
                                results += "• \(name): \(percentage)%\n"
                            }
                        }
                    }
                    
                    analysisResults = results.isEmpty ? "No features detected in the image" : results
                    
                    // Print analysis results to console for debugging
                    print("===== ANALYSIS RESULTS =====")
                    print(analysisResults)
                    print("===========================")
                } catch {
                    analysisResults = "Error parsing response: \(error.localizedDescription)"
                    print("Parsing error: \(error.localizedDescription)")
                }
            }
        }
        
        task.resume()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
