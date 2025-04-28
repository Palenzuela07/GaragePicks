//
//  ContentView.swift
//  GaragePicks
//
//  Created by Michael Palenzuela on 4/21/25.
//

import SwiftUI
import PhotosUI
import UIKit
import WebKit

#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var isImagePickerPresented = false
    @State private var isCameraPresented = false
    @State private var analysisResults: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var identifiedItems: [String] = []
    @State private var itemPriceResults: [String: EbaySearchResult] = [:]
    @State private var activeTab: Int = 0 // 0 = Image, 1 = Results, 2 = Pricing
    
    // Pricing-related state
    @State private var selectedItemForPricing: String? = nil
    @State private var priceResults: EbaySearchResult? = nil
    @State private var isPriceLoading: Bool = false
    @State private var priceError: String? = nil
    @State private var displayedListingCount: Int = 10 // Initial number of listings to show
    @State private var isLoadingMore: Bool = false
    @State private var hasMoreResults: Bool = false
    @State private var currentPage: Int = 1
    @State private var isWebViewPresented: Bool = false
    @State private var webViewURL: URL? = nil
    
    private let ebayService = EbayApiService()
    
    // MARK: - eBay Deep Link Helpers
    
    // Helper to create the URL components for a search
    private func createSearchComponents(for searchTerm: String, page: Int) -> URLComponents {
        var components = URLComponents(string: "https://api.ebay.com/buy/browse/v1/item_summary/search")!
        
        // Offset calculation for pagination (0-based)
        let offset = (page - 1) * 100
        
        // Basic query parameters
        components.queryItems = [
            URLQueryItem(name: "q", value: searchTerm),
            URLQueryItem(name: "limit", value: "100"), // Max results per page
            URLQueryItem(name: "offset", value: "\(offset)"), // Pagination offset
            URLQueryItem(name: "fieldgroups", value: "FULL"),
            URLQueryItem(name: "descriptionSearch", value: "false") // Only search item titles
        ]
        
        // Filter for completed AND sold items (both are required to match eBay website)
        components.queryItems?.append(URLQueryItem(name: "filter", value: "itemLocationCountry:US"))
        components.queryItems?.append(URLQueryItem(name: "filter", value: "buyingOptions:{FIXED_PRICE|AUCTION}"))
        components.queryItems?.append(URLQueryItem(name: "filter", value: "deliveryCountry:US"))
        components.queryItems?.append(URLQueryItem(name: "filter", value: "conditionIds:{1000|1500|2000|2500|3000|4000|5000|6000}"))
        components.queryItems?.append(URLQueryItem(name: "filter", value: "soldItemsOnly:true")) 
        
        // Sort by recently sold first (most recent ending date)
        components.queryItems?.append(URLQueryItem(name: "sort", value: "-endedDate"))
        
        return components
    }
    
    // Direct URL for comparison with eBay app
    private func createEbayWebUrlForSoldItems(_ searchTerm: String) -> URL {
        let encodedTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.ebay.com/sch/i.html?_nkw=\(encodedTerm)&LH_Complete=1&LH_Sold=1&_sop=10")!
    }
    
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
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create the web URL for eBay with proper sold items filter
        let webUrl = createEbayWebUrlForSoldItems(cleanedTerm)
        
        // Try the eBay app URL first with sold parameters
        if let appUrl = URL(string: "ebay://search?query=\(cleanedTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&LH_Complete=1&LH_Sold=1") {
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
        VStack(spacing: 0) {
            // Tab buttons at top - add pricing tab
            HStack {
                TabButton(title: "Image", isActive: activeTab == 0) {
                    activeTab = 0
                }
                
                TabButton(title: "Analysis", isActive: activeTab == 1) {
                    activeTab = 1
                }
                
                TabButton(title: "eBay", isActive: activeTab == 2) {
                    activeTab = 2
                }
            }
            .padding(.horizontal)
            
            ZStack(alignment: .bottom) {
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
        }
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraView(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $isWebViewPresented) {
            if let url = webViewURL {
                EbayWebView(url: url, onDismiss: {
                    isWebViewPresented = false 
                })
            }
        }
        .onChange(of: identifiedItems) { newItems in
            // When items are identified, switch to the analysis tab
            if !newItems.isEmpty {
                activeTab = 1
                // Fetch price data for each identified item if not already fetched
                for item in newItems {
                    if itemPriceResults[item] == nil {
                        fetchQuickPriceForIdentifiedItem(item)
                    }
                }
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
        VStack(spacing: 24) {
            Spacer(minLength: 40)
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 420)
                    .cornerRadius(10)
                    .padding(.horizontal, 8)
            } else {
                Image(systemName: "photo")
                    .imageScale(.large)
                    .font(.system(size: 100))
                    .foregroundColor(.gray)
                    .frame(height: 300)
            }
            HStack(spacing: 20) {
                Button(action: {
                    isCameraPresented = true
                }) {
                    Image(systemName: "camera")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                Button(action: {
                    analyzePhoto()
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                        Text(isAnalyzing ? "Analyzing..." : "Analyze")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedImage == nil ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(selectedImage == nil || isAnalyzing)
            }
            .padding(.horizontal)
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }
    
    var analysisTabContent: some View {
        VStack(spacing: 16) {
            // Show the selected image at the top
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .cornerRadius(10)
                    .padding(.horizontal, 8)
            }
            // Show price stats if available
            if let priceResults = priceResults {
                HStack(spacing: 24) {
                    VStack {
                        Text("Low")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.2f", priceResults.lowestPrice))")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    VStack {
                        Text("Mean")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.2f", priceResults.averagePrice))")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    VStack {
                        Text("High")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.2f", priceResults.highestPrice))")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 8)
            }
            // Existing analysis results
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
            // Existing identified items
            if !identifiedItems.isEmpty {
                VStack(alignment: .leading) {
                    Text("Identified Items (tap to search eBay):")
                        .font(.headline)
                        .padding(.horizontal)
                    ForEach(identifiedItems, id: \.self) { item in
                        Button(action: {
                            openEbayWebViewForItem(item)
                        }) {
                            HStack {
                                Text(item)
                                    .lineLimit(2)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if let stats = itemPriceResults[item] {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Low: $\(String(format: "%.2f", stats.lowestPrice))")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                        Text("High: $\(String(format: "%.2f", stats.highestPrice))")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                                Image(systemName: "tag")
                                    .foregroundColor(.blue)
                                Text("Search Completed & Sold")
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
                        .padding(.bottom, 8)
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
        VStack(alignment: .center, spacing: 20) {
            if let selectedItem = selectedItemForPricing {
                // Header with item name
                HStack {
                    Button(action: {
                        activeTab = 1 // Go back to analysis tab
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing, 8)
                    
                    Text(selectedItem)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Direct WebView instead of API results
                Button(action: {
                    // Open in external web browser instead of Google search
                    let cleanedTerm = selectedItem
                        .replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: """
 ", with: "")
                        
 .replacingOccurrences(of:
 """, with: "")
                        .replacingOccurrences(of: "'", with: "")
                        .replacingOccurrences(of: "'", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let url = createEbayWebUrlForSoldItems(cleanedTerm)
                    UIApplication.shared.open(url)
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Open in Web Browser")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: {
                    openEbayWebViewForItem(selectedItem)
                }) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Open Web View")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Instructions
                VStack(spacing: 16) {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("Tap the button above to see eBay's completed and sold listings for this item.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding()
                }
                .frame(maxHeight: .infinity)
                
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
    }
    
    // Open eBay WebView for a specific item
    private func openEbayWebViewForItem(_ item: String) {
        // Clean the search term
        let cleanedTerm = cleanSearchTerm(item)
        
        // Set the selected item for the pricing tab
        selectedItemForPricing = item
        
        // Create the eBay URL
        webViewURL = createEbayWebUrlForSoldItems(cleanedTerm)
        isWebViewPresented = true
        activeTab = 2
    }
    
    // MARK: - Helper Methods
    
    // Load more items from the current results
    private func loadMoreItems() {
        // Increase the number of displayed items
        let newCount = min(displayedListingCount + 10, priceResults?.items.count ?? 0)
        displayedListingCount = newCount
    }
    
    // Load the next page of results from eBay
    private func loadNextPage() {
        guard let selectedItem = selectedItemForPricing, !isLoadingMore else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        Task {
            await fetchMoreResultsForItem(selectedItem, page: currentPage)
        }
    }
    
    // MARK: - Existing Methods
    
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
    
    // Fetch price for a single item
    func fetchPriceForItem(_ item: String) {
        // Reset pagination state
        currentPage = 1
        displayedListingCount = 10
        hasMoreResults = false
        isPriceLoading = true
        selectedItemForPricing = item
        priceError = nil
        let cleanedTerm = cleanSearchTerm(item)
        Task {
            let components = createSearchComponents(for: cleanedTerm, page: 1)
            if let url = components.url {
                print("🔗 API URL: \(url.absoluteString)")
            }
            let result = await ebayService.searchWithCustomComponents(components, itemLimit: 100)
            DispatchQueue.main.async {
                isPriceLoading = false
                isLoadingMore = false
                switch result {
                case .success(let searchResult):
                    priceResults = searchResult
                    itemPriceResults[item] = searchResult
                    if searchResult.items.count == 100 {
                        hasMoreResults = true
                    }
                    print("Found \(searchResult.itemCount) items for \(item) with price range: $\(String(format: "%.2f", searchResult.lowestPrice)) - $\(String(format: "%.2f", searchResult.highestPrice))")
                case .failure(let error):
                    var errorMessage = "No price data available"
                    if let ebayError = error as? EbayError {
                        switch ebayError {
                        case .noItemsFound:
                            errorMessage = "No sold items found on eBay"
                        case .networkError(let message), .parsingError(let message), .authenticationError(let message):
                            errorMessage = message
                        case .rateLimitExceeded:
                            errorMessage = "Too many requests to eBay. Please try again later."
                        case .httpError(let code):
                            errorMessage = "Server error (\(code)). Please try again."
                        case .jsonParsingError(let message):
                            errorMessage = "Error parsing data: \(message)"
                        case .invalidSearchTerm:
                            errorMessage = "Invalid search term. Please try with different keywords."
                        case .invalidURL:
                            errorMessage = "Invalid URL configuration."
                        case .noDataReceived:
                            errorMessage = "No data received from server."
                        case .invalidResponse:
                            errorMessage = "Received invalid response from server."
                        case .apiError(let message):
                            errorMessage = "API error: \(message)"
                        case .noAccessToken:
                            errorMessage = "Authentication error. Please try again."
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    priceError = errorMessage
                    print("eBay search error for \(item): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Load additional pages of results
    private func fetchMoreResultsForItem(_ item: String, page: Int) async {
        let cleanedTerm = cleanSearchTerm(item)
        
        let components = createSearchComponents(for: cleanedTerm, page: page)
        
        // Print the URL for debugging
        if let url = components.url {
            print("🔗 Loading more results URL: \(url.absoluteString)")
        }
        
        let result = await ebayService.searchWithCustomComponents(components, itemLimit: 100)
        
        DispatchQueue.main.async {
            isLoadingMore = false
            
            switch result {
            case .success(let searchResult):
                // Update existing results with the new page
                if let existingResults = priceResults {
                    // Keep statistics from first page but add new items
                    var updatedItems = existingResults.items
                    updatedItems.append(contentsOf: searchResult.items)
                    
                    // Create a new result with the combined items
                    priceResults = EbaySearchResult(
                        averagePrice: existingResults.averagePrice,
                        lowestPrice: existingResults.lowestPrice,
                        highestPrice: existingResults.highestPrice,
                        itemCount: updatedItems.count,
                        items: updatedItems
                    )
                    
                    // Update hasMoreResults flag
                    hasMoreResults = searchResult.items.count == 100
                    
                    print("Loaded page \(page) with \(searchResult.items.count) additional items")
                } else {
                    // Unlikely case: No existing results but pagination worked
                    priceResults = searchResult
                    hasMoreResults = searchResult.items.count == 100
                }
                
            case .failure(let error):
                // Show error but keep existing results
                print("Error loading more results: \(error.localizedDescription)")
                hasMoreResults = false
            }
        }
    }
    
    private func fetchQuickPriceForIdentifiedItem(_ item: String) {
        let cleanedTerm = cleanSearchTerm(item)
        Task {
            let components = createSearchComponents(for: cleanedTerm, page: 1)
            let result = await ebayService.searchWithCustomComponents(components, itemLimit: 30)
            DispatchQueue.main.async {
                if case .success(let searchResult) = result {
                    itemPriceResults[item] = searchResult
                }
            }
        }
    }
    
    private func cleanSearchTerm(_ term: String) -> String {
        term.replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIViewController {
        if sourceType == .camera {
            let picker = UIImagePickerController()
            picker.delegate = context.coordinator
            picker.sourceType = sourceType
            return picker
        } else {
            var config = PHPickerConfiguration()
            config.filter = .images
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
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

// MARK: - Custom Components
struct EbayWebView: View {
    let url: URL
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            WebViewContainer(url: url)
                .edgesIgnoringSafeArea(.bottom)
                .navigationBarTitle("eBay Search", displayMode: .inline)
                .navigationBarItems(trailing: Button("Done") {
                    onDismiss()
                })
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewContainer
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Page loaded successfully
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }
    }
}

struct EbayListingCell: View {
    let item: EbayItem
    
    var body: some View {
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
                    
                    // Display sold date with more prominence
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
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
}
