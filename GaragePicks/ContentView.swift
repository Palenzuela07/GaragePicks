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
    @State private var identifiedItems: [String] = []
    @State private var selectedItemForPricing: String? = nil
    @State private var priceResults: EbaySearchResult? = nil
    @State private var isPriceLoading: Bool = false
    @State private var priceError: String? = nil
    @State private var searchQuery: String? = nil
    @State private var activeTab: Int = 0 // 0 = Image, 1 = Results, 2 = Pricing
    @State private var itemPrices: [String: (isLoading: Bool, result: EbaySearchResult?, error: String?)] = [:]
    @State private var displayedListingCount: Int = 5 // Number of listings to display initially
    @State private var loadedItemLimit: Int = 25 // Default number of eBay results to load
    
    private let ebayService = EbayApiService()
    
    // Computed property for sorted items by average price (highest to lowest)
    private var sortedItemsByPrice: [String] {
        // Create a list of tuples with (item, price) for sorting
        let itemsWithPrices = identifiedItems.map { item -> (String, Double) in
            if let priceData = itemPrices[item], let result = priceData.result {
                return (item, result.averagePrice)
            } else {
                return (item, -1) // -1 for items without price data yet
            }
        }
        
        // Sort items by price (highest first), with unpriced items at the end
        let sortedItems = itemsWithPrices.sorted { item1, item2 in
            // If both have valid prices, compare them
            if item1.1 >= 0 && item2.1 >= 0 {
                return item1.1 > item2.1 // Descending order
            }
            // If only one has a valid price, prioritize it
            else if item1.1 >= 0 {
                return true
            }
            else if item2.1 >= 0 {
                return false
            }
            // If neither has a price, keep original order
            else {
                return identifiedItems.firstIndex(of: item1.0)! < identifiedItems.firstIndex(of: item2.0)!
            }
        }
        
        // Return just the item names
        return sortedItems.map { $0.0 }
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
                
                TabButton(title: "Pricing", isActive: activeTab == 2) {
                    activeTab = 2
                }
            }
            .padding(.horizontal)
            
            // Main content area
            ScrollView {
                if activeTab == 0 {
                    imageTabContent
                } else if activeTab == 1 {
                    analysisTabContent
                } else {
                    pricingTabContent
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
        .onChange(of: isPriceLoading) { isLoading in
            // When pricing results are loaded, switch to pricing tab
            if !isLoading && priceResults != nil {
                activeTab = 2
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
                    Text("Identified Items:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(sortedItemsByPrice, id: \.self) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item)
                                    .lineLimit(2)
                                    .font(.headline)
                                Spacer()
                            }
                            
                            if let itemData = itemPrices[item] {
                                if itemData.isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView("Loading prices...")
                                            .font(.caption)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                } else if let result = itemData.result {
                                    HStack(alignment: .top) {
                                        // Price info
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Average: $\(String(format: "%.2f", result.averagePrice))")
                                                .fontWeight(.bold)
                                            HStack {
                                                Text("Low: $\(String(format: "%.2f", result.lowestPrice))")
                                                Spacer()
                                                Text("High: $\(String(format: "%.2f", result.highestPrice))")
                                            }
                                            .font(.caption)
                                            Text("Based on \(result.itemCount) sales")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            
                                            // Add similarity/confidence indicator
                                            let confidence = calculateConfidence(item: item, results: result)
                                            HStack {
                                                Text("Match confidence:")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                                ConfidenceIndicator(level: confidence)
                                            }
                                            .padding(.top, 2)
                                        }
                                        
                                        Spacer()
                                        
                                        // Thumbnail image (if available)
                                        if let firstItem = result.items.first, let imageUrl = firstItem.imageUrl, let url = URL(string: imageUrl) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView()
                                                        .frame(width: 50, height: 50)
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 50, height: 50)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                case .failure:
                                                    EmptyView()
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                            .frame(width: 50, height: 50)
                                            .background(Color(.systemGray5))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    
                                    // Show best matching item details
                                    if let bestMatch = result.items.first {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Best match:")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text(bestMatch.title)
                                                .font(.caption)
                                                .lineLimit(2)
                                                .padding(.bottom, 2)
                                            
                                            if !bestMatch.condition.isEmpty {
                                                Text("Condition: \(bestMatch.condition)")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                    
                                    Button(action: {
                                        selectedItemForPricing = item
                                        priceResults = result
                                        displayedListingCount = 5 // Reset to initial count when changing items
                                        activeTab = 2 // Go to pricing tab
                                    }) {
                                        Text("View Details")
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                } else if let error = itemData.error {
                                    HStack {
                                        Text("⚠️ \(error)")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                        Spacer()
                                        Button(action: {
                                            fetchPriceForItem(item)
                                        }) {
                                            Text("Retry")
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                                .font(.caption)
                                        }
                                    }
                                }
                            } else {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        fetchPriceForItem(item)
                                    }) {
                                        Text("Check Price")
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
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
    
    var pricingTabContent: some View {
        VStack(spacing: 16) {
            if let priceResults = priceResults, let selectedItem = selectedItemForPricing {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Price Results for: \(selectedItem)")
                        .font(.headline)
                    
                    if let query = searchQuery {
                        Text("Search terms: \(query)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Average Price: $\(String(format: "%.2f", priceResults.averagePrice))")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            HStack {
                                Text("Low: $\(String(format: "%.2f", priceResults.lowestPrice))")
                                Spacer()
                                Text("High: $\(String(format: "%.2f", priceResults.highestPrice))")
                            }
                            .font(.subheadline)
                            
                            Text("Based on \(priceResults.itemCount) sold listings")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if !priceResults.items.isEmpty {
                        Text("Recent Sales:")
                            .font(.headline)
                            .padding(.top, 12)
                        
                        ForEach(priceResults.items.prefix(displayedListingCount), id: \.title) { item in
                            HStack(alignment: .top, spacing: 12) {
                                // Image of the item
                                ZStack {
                                    if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .frame(width: 80, height: 80)
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            case .failure:
                                                Image(systemName: "photo")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 40, height: 40)
                                                    .foregroundColor(.gray)
                                                    .frame(width: 80, height: 80)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                    } else {
                                        Image(systemName: "photo")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(.gray)
                                            .frame(width: 80, height: 80)
                                    }
                                }
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                // Item details
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("$\(String(format: "%.2f", item.price))")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                        
                                        Spacer()
                                        
                                        // Always display sold date with more prominence
                                        HStack(spacing: 4) {
                                            Image(systemName: "calendar")
                                                .font(.caption)
                                            Text(item.soldDate ?? "Recently")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(4)
                                    }
                                    
                                    Text(item.title)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                    
                                    HStack {
                                        Text(item.condition)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(4)
                                            
                                        Spacer()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.vertical, 4)
                        }
                        
                        // "Load More" button
                        if priceResults.items.count > displayedListingCount {
                            Button(action: {
                                // Increase displayed items count (with a reasonable maximum)
                                displayedListingCount = min(displayedListingCount + 5, priceResults.items.count)
                            }) {
                                HStack {
                                    Text("Load More Results")
                                    Image(systemName: "arrow.down.circle.fill")
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                        }
                        
                        // "Load More from eBay" button (only if we're displaying all current results)
                        if displayedListingCount >= priceResults.items.count && loadedItemLimit < 200 {
                            Button(action: {
                                // Load more items from eBay API
                                fetchMoreEbayResults()
                            }) {
                                HStack {
                                    Text("Search for More on eBay")
                                    Image(systemName: "magnifyingglass.circle.fill")
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                        }
                        
                        // Display count information
                        Text("Showing \(min(displayedListingCount, priceResults.items.count)) of \(priceResults.items.count) items")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("No individual listings available to display")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Button(action: {
                    activeTab = 1 // Go back to analysis tab
                }) {
                    Text("← Back to Analysis")
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
            } else if isPriceLoading {
                VStack(spacing: 16) {
                    ProgressView("Loading price data...")
                        .padding()
                    if let item = selectedItemForPricing {
                        Text("Searching for: \(item)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            } else if let error = priceError {
                VStack {
                    Text("Error:")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    
                    Button(action: {
                        activeTab = 1 // Go back to analysis tab
                    }) {
                        Text("← Back to Analysis")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                }
            } else {
                VStack {
                    Text("Select an item to check pricing")
                        .foregroundColor(.gray)
                        .padding()
                    
                    Button(action: {
                        activeTab = 1
                    }) {
                        Text("← Go to Item Selection")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical)
        .onAppear {
            print("Pricing tab appeared. isPriceLoading: \(isPriceLoading), has results: \(priceResults != nil), has error: \(priceError != nil)")
        }
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
            
            // Automatically fetch prices for each item
            for item in items {
                fetchPriceForItem(item)
            }
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
    
    // Fetch price for a single item
    func fetchPriceForItem(_ item: String) {
        // Set loading state for this item
        itemPrices[item] = (isLoading: true, result: nil, error: nil)
        
        // Clean up the search query - more thorough cleaning
        let cleanQuery = item
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: " - ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            let result = await ebayService.searchCompletedItems(keyword: cleanQuery)
            
            DispatchQueue.main.async {
                switch result {
                case .success(let searchResult):
                    // Update the price info for this item
                    itemPrices[item] = (isLoading: false, result: searchResult, error: nil)
                    print("Found \(searchResult.itemCount) items for \(item) with price range: $\(searchResult.lowestPrice) - $\(searchResult.highestPrice)")
                    
                case .failure(let error):
                    var errorMessage = "No price data available"
                    
                    if let ebayError = error as? EbayError {
                        switch ebayError {
                        case .noItemsFound:
                            errorMessage = "No items found on eBay"
                        case .networkError(let message), .parsingError(let message), .authenticationError(let message):
                            errorMessage = message
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    // Update the error state for this item
                    itemPrices[item] = (isLoading: false, result: nil, error: errorMessage)
                    print("eBay search error for \(item): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Add this function to calculate match confidence
    private func calculateConfidence(item: String, results: EbaySearchResult) -> Double {
        // Simple implementation for now - can be enhanced with more sophisticated matching
        
        // Start with base confidence level depending on number of results
        var confidence = min(0.5 + (Double(results.itemCount) / 20.0), 0.9)
        
        // Check if item name appears in the first result title (best match)
        if let firstTitle = results.items.first?.title.lowercased() {
            let itemWords = item.lowercased().split(separator: " ")
            var wordMatchCount = 0
            
            for word in itemWords where word.count > 3 {  // Only consider meaningful words
                if firstTitle.contains(word.lowercased()) {
                    wordMatchCount += 1
                }
            }
            
            // Boost confidence based on word matches
            let matchRatio = Double(wordMatchCount) / Double(max(1, itemWords.count))
            confidence = min(confidence + (matchRatio * 0.4), 1.0)
        }
        
        // Price consistency also factors into confidence
        let priceRange = results.highestPrice - results.lowestPrice
        let priceVariation = priceRange / max(1.0, results.averagePrice)
        
        // If prices are consistent (low variation), increase confidence
        if priceVariation < 0.5 {
            confidence = min(confidence + 0.1, 1.0)
        } else if priceVariation > 1.0 {
            // High variation might indicate mixed results
            confidence = max(confidence - 0.1, 0.0)
        }
        
        return confidence
    }
    
    // Add a confidence indicator view
    struct ConfidenceIndicator: View {
        let level: Double  // 0.0 to 1.0
        
        var body: some View {
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Rectangle()
                        .fill(colorForLevel(index: index))
                        .frame(width: 10, height: 6)
                        .cornerRadius(1)
                }
                
                Text(confidenceText)
                    .font(.caption2)
                    .foregroundColor(confidenceColor)
                    .padding(.leading, 4)
            }
        }
        
        private var confidenceText: String {
            if level < 0.3 {
                return "Low"
            } else if level < 0.6 {
                return "Medium"
            } else if level < 0.8 {
                return "Good"
            } else {
                return "High"
            }
        }
        
        private var confidenceColor: Color {
            if level < 0.3 {
                return .red
            } else if level < 0.6 {
                return .orange
            } else if level < 0.8 {
                return .blue
            } else {
                return .green
            }
        }
        
        private func colorForLevel(index: Int) -> Color {
            let threshold = Double(index + 1) / 5.0
            if level >= threshold {
                return confidenceColor
            } else {
                return Color(.systemGray5)
            }
        }
    }
    
    // Add this new function to load more results from eBay
    private func fetchMoreEbayResults() {
        guard let item = selectedItemForPricing else { return }
        
        // Double the number of items to load
        loadedItemLimit = min(loadedItemLimit * 2, 200)
        isPriceLoading = true
        
        Task {
            // Use the same cleanQuery logic as in fetchPriceForItem
            let cleanQuery = item
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: " - ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                
            let result = await ebayService.searchCompletedItems(keyword: cleanQuery, itemLimit: loadedItemLimit)
            
            DispatchQueue.main.async {
                isPriceLoading = false
                
                switch result {
                case .success(let searchResult):
                    priceResults = searchResult
                    itemPrices[item] = (isLoading: false, result: searchResult, error: nil)
                    print("Loaded \(searchResult.itemCount) items from eBay")
                    
                    // Reset displayed count to show we have new items
                    displayedListingCount = min(displayedListingCount + 5, searchResult.items.count)
                    
                case .failure(let error):
                    print("Error loading more results: \(error.localizedDescription)")
                    // Keep existing results but show error
                    var errorMessage = "Failed to load more results"
                    if let ebayError = error as? EbayError {
                        switch ebayError {
                        case .noItemsFound:
                            errorMessage = "No additional items found"
                        case .networkError(let message), .parsingError(let message), .authenticationError(let message):
                            errorMessage = message
                        }
                    }
                    // Show error alert or message
                    priceError = errorMessage
                }
            }
        }
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
