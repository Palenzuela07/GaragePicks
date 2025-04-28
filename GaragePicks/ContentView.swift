//
//  ContentView.swift
//  GaragePicks
//
//  Created by Michael Palenzuela on 4/21/25.
//

import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var isImagePickerPresented = false
    @State private var analysisResults: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var identifiedItems: [String] = []
    @State private var activeTab: Int = 0 // 0 = Image, 1 = Results
    
    private let ebayService = EbayApiService()
    
    // MARK: - eBay Deep Link Helpers
    
    // Opens the eBay app with the given search term, falls back to Safari if the app isn't installed
    private func openEbaySearch(for searchTerm: String) {
        // Clean the search term by removing quotation marks
        let cleanedTerm = searchTerm
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: """
            , with: "")
            .replacingOccurrences(of:
 """, with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "'", with: "")
        
        // Create the web URL for eBay (this will always work)
        let webUrl = URL(string: "https://www.ebay.com/sch/i.html?_nkw=\(cleanedTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&LH_Sold=1")!
        
        // Try the eBay app URL first
        if let appUrl = URL(string: "ebay://search?query=\(cleanedTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&LH_Sold=1") {
            // Check if we can open the eBay app URL
            if UIApplication.shared.canOpenURL(appUrl) {
                UIApplication.shared.open(appUrl, options: [:]) { success in
                    // If opening the app URL fails, fall back to web
                    if !success {
                        UIApplication.shared.open(webUrl)
                    }
                }
                return
            }
        }
        
        // Fall back to web URL if app URL isn't available or can't be opened
        UIApplication.shared.open(webUrl)
    }
    
    var body: some View {
        VStack {
            // Tab buttons at top
            HStack {
                TabButton(title: "Image", isActive: activeTab == 0) {
                    activeTab = 0
                }
                
                TabButton(title: "Analysis", isActive: activeTab == 1) {
                    activeTab = 1
                }
            }
            .padding(.horizontal)
            
            // Main content area
            ScrollView {
                if activeTab == 0 {
                    imageTabContent
                } else {
                    analysisTabContent
                }
            }
        }
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .onChange(of: identifiedItems) { _ in
            // When items are identified, switch to the analysis tab
            if !identifiedItems.isEmpty {
                activeTab = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Handle app returning to foreground if needed
        }
    }
    
    // MARK: - Tab Content Views
    
    var imageTabContent: some View {
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
        }
        .padding()
    }
    
    var analysisTabContent: some View {
        VStack(spacing: 16) {
            if !analysisResults.isEmpty {
                VStack(alignment: .leading) {
                    Text("Analysis Results:")
                        .font(.headline)
                    
                    Text(analysisResults)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            
            if !identifiedItems.isEmpty {
                VStack(alignment: .leading) {
                    Text("Identified Items (tap to search eBay):")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(identifiedItems, id: \.self) { item in
                        Button(action: {
                            openEbaySearch(for: item)
                        }) {
                            HStack {
                                Text(item)
                                    .lineLimit(2)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.blue)
                                
                                Text("Search eBay")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                    }
                }
            }
            
            if isAnalyzing {
                ProgressView("Analyzing image...")
                    .padding()
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Helper Methods
    
    func analyzePhoto() {
        guard let image = selectedImage else { return }
        
        isAnalyzing = true
        analysisResults = "Analyzing image with ChatGPT..."
        identifiedItems = []
        
        // Convert UIImage to base64 string
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            analysisResults = "Error: Could not convert image to data"
            isAnalyzing = false
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Prepare the ChatGPT API request
        let apiKey = "YOUR_OPENAI_API_KEY"
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        // Create the request body
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": "You are an expert at identifying products, especially items found at garage sales, thrift stores, and discount shops. Identify all products in the image, listing the specific product names that could be searched on eBay. Be specific about brands, models, and types. Format your response with an introductory line followed by a numbered list of identified items."
            ],
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": "Identify all products in this image. List them specifically by name as they would appear in an eBay search."
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64Image)"
                        ]
                    ]
                ]
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 1000
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            analysisResults = "Error: Could not serialize request"
            isAnalyzing = false
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            DispatchQueue.main.async {
                isAnalyzing = false
                
                if let error = error {
                    analysisResults = "Error: \(error.localizedDescription)"
                    print("Network error: \(error.localizedDescription)")
                    return
                }
                
                // Check HTTP response status
                if let httpResponse = response as? HTTPURLResponse {
                    print("Response status code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode != 200 {
                        if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                            print("API Error Response: \(errorMessage)")
                            analysisResults = "API Error (\(httpResponse.statusCode)): \(errorMessage)"
                        } else {
                            analysisResults = "API Error: Status code \(httpResponse.statusCode)"
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
                    
                    // Extract the response content
                    guard let choices = json["choices"] as? [[String: Any]],
                          let firstChoice = choices.first,
                          let message = firstChoice["message"] as? [String: Any],
                          let content = message["content"] as? String else {
                        analysisResults = "Error: Invalid response format"
                        return
                    }
                    
                    // Set the full response as analysis results
                    analysisResults = content
                    
                    // Process the response to extract individual items
                    extractItemsFromResponse(content)
                    
                    // Print analysis results to console for debugging
                    print("===== ANALYSIS RESULTS =====")
                    print(content)
                    print("===========================")
                } catch {
                    analysisResults = "Error parsing response: \(error.localizedDescription)"
                    print("Parsing error: \(error.localizedDescription)")
                }
            }
        }
        
        task.resume()
    }
    
    // Helper function to extract individual items from ChatGPT's response
    func extractItemsFromResponse(_ response: String) {
        // Split by new lines
        let lines = response.components(separatedBy: .newlines)
        
        // Look for numbered or bulleted list items
        var items: [String] = []
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Match numbered items (1. Item) or bulleted items (• Item, - Item, * Item)
            if let match = trimmedLine.range(of: #"^(\d+\.|\•|\-|\*)\s+"#, options: .regularExpression) {
                // Get the text after the prefix
                let itemStart = trimmedLine.index(match.upperBound, offsetBy: 0)
                let itemText = String(trimmedLine[itemStart...])
                
                if !itemText.isEmpty {
                    items.append(itemText)
                }
            }
        }
        
        // If we couldn't find list items, try to extract product mentions
        if items.isEmpty {
            // Use a simplified approach if no list format was found
            items = extractProductMentions(response)
        }
        
        DispatchQueue.main.async {
            self.identifiedItems = items
        }
    }
    
    // Fallback function to extract product mentions if no list format is found
    func extractProductMentions(_ text: String) -> [String] {
        // Split by common separators
        let separators = CharacterSet(charactersIn: ",;\n")
        let components = text.components(separatedBy: separators)
        
        // Filter out very short components and trim whitespace
        return components
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { $0.count > 5 } // Only include items with some substance
            .prefix(10) // Limit to 10 items
            .map { String($0) }
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

// MARK: - Tab Button Component
struct TabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(isActive ? .bold : .regular)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(isActive ? Color.blue : Color(.systemGray5))
                .foregroundColor(isActive ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

#Preview {
    ContentView()
}
