//
//  EbayApiService.swift
//  GaragePicks
//
//  Created by Michael Palenzuela on 4/21/25.
//

import Foundation
import ObjectiveC

// Simple result structures
struct EbayItem: Equatable {
    let title: String
    let price: Double
    let imageUrl: String?
    let condition: String
    let soldDate: String?
}

struct EbaySearchResult: Equatable {
    let averagePrice: Double
    let lowestPrice: Double
    let highestPrice: Double
    let itemCount: Int
    let items: [EbayItem]
}

// Service-specific error type separate from model EbayError
enum EbayError: Error {
    case networkError(String)
    case parsingError(String)
    case noItemsFound
    case authenticationError(String)
    case rateLimitExceeded
    case httpError(Int)
    case jsonParsingError(String)
    case invalidSearchTerm
    case invalidURL
    case noDataReceived
    case invalidResponse
    case apiError(String)
    case noAccessToken
}

// OAuth Token Response
struct OAuthToken: Codable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// Associated object keys for EbaySearchResult extension

// Basic eBay API Service
class EbayApiService {
    // OAuth credentials 
    private let clientId = "MichaelP-GaragePi-PRD-724e805e6-b141c4fa" // Production Client ID
    private let clientSecret = "YOUR_EBAY_CLIENT_SECRET" // Production Client Secret
    private let scope = "https://api.ebay.com/oauth/api_scope"
    private let isSandboxMode = false // Using production mode
    
    // Flag to use mock data instead of real API
    private let useMockData = false // Use real eBay API data
    
    // OAuth token storage - Using provided token
    private var authToken: String? = nil // Set to nil to force token request
    private var tokenExpirationDate: Date? = nil // Reset expiration date
    
    // OAuth token acquisition - using pre-supplied token in production mode
    private func getOAuthToken() async -> Result<String, Error> {
        print("🔑 Starting OAuth token request process")
        
        // Check if we have a valid token already
        if let token = authToken, let expirationDate = tokenExpirationDate, expirationDate > Date() {
            print("✅ Using existing valid token that expires at \(expirationDate)")
            return .success(token)
        }
        
        print("⚠️ No valid token found, requesting new token")
        
        // For sandbox mode or if token isn't pre-supplied, request new token
        let baseUrl = isSandboxMode ? "https://api.sandbox.ebay.com" : "https://api.ebay.com"
        guard let url = URL(string: "\(baseUrl)/identity/v1/oauth2/token") else {
            print("❌ Invalid OAuth URL")
            return .failure(EbayError.authenticationError("Invalid OAuth URL"))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Encode credentials for Basic Authentication
        let credentials = "\(clientId):\(clientSecret)".data(using: .utf8)!.base64EncodedString()
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        print("🔄 Making OAuth request to: \(url)")
        print("🔑 Using client ID: \(clientId)")
        
        let bodyParameters = "grant_type=client_credentials&scope=\(scope)"
        request.httpBody = bodyParameters.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response from OAuth endpoint")
                return .failure(EbayError.authenticationError("Invalid response"))
            }
            
            print("📊 OAuth response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ OAuth error response: \(responseString)")
                }
                return .failure(EbayError.authenticationError("Failed to obtain token: \(httpResponse.statusCode)"))
            }
            
            // Print the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📝 Raw OAuth response: \(responseString)")
            }
            
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(OAuthToken.self, from: data)
            
            // Store the token and expiration
            self.authToken = tokenResponse.accessToken
            self.tokenExpirationDate = Date().addingTimeInterval(Double(tokenResponse.expiresIn - 300)) // 5 minutes buffer
            
            print("✅ Successfully obtained new token, expires in \(tokenResponse.expiresIn) seconds")
            print("🔑 Token type: \(tokenResponse.tokenType)")
            if let expiry = self.tokenExpirationDate {
                print("⏰ Token will expire at: \(expiry)")
            }
            
            return .success(tokenResponse.accessToken)
        } catch {
            print("❌ OAuth error: \(error.localizedDescription)")
            return .failure(EbayError.authenticationError("OAuth error: \(error.localizedDescription)"))
        }
    }
    
    // Check if the current token is valid
    private func isTokenValid() -> Bool {
        guard let token = authToken, let expirationDate = tokenExpirationDate else {
            return false
        }
        
        // Check if token is still valid with a 5-minute buffer
        return expirationDate > Date().addingTimeInterval(300)
    }
    
    // Refresh the OAuth token
    private func refreshToken() async -> Result<Void, Error> {
        let tokenResult = await getOAuthToken()
        
        switch tokenResult {
        case .success:
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // Basic function to search eBay
    func searchCompletedItems(keyword: String, itemLimit: Int = 50) async -> Result<EbaySearchResult, Error> {
        print("🔍 Searching for items: \(keyword) with limit \(itemLimit)")
        
        // Check if token is valid, if not refresh it
        if !isTokenValid() {
            let tokenResult = await refreshToken()
            switch tokenResult {
            case .success:
                print("✅ Token refreshed successfully")
            case .failure(let error):
                print("❌ Failed to refresh token: \(error.localizedDescription)")
                return .failure(error)
            }
        }
        
        guard let accessToken = self.authToken else {
            print("❌ No access token available")
            return .failure(EbayError.noAccessToken)
        }
        
        // Clean up the search term
        let searchTerm = keyword
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
        
        print("🔍 Search term: \(searchTerm)")
        
        // Create URL with appropriate query parameters based on eBay Browse API
        guard var components = URLComponents(string: "https://api.ebay.com/buy/browse/v1/item_summary/search") else {
            return .failure(EbayError.invalidURL)
        }
        
        // Basic query parameters
        components.queryItems = [
            URLQueryItem(name: "q", value: searchTerm),
            URLQueryItem(name: "limit", value: String(min(itemLimit, 200))),
            // Request full item details including aspects for more comprehensive data
            URLQueryItem(name: "fieldgroups", value: "FULL")
        ]
        
        // According to documentation, we can use filters to get more specific results
        // Include both auction and fixed-price formats to get more complete data
        components.queryItems?.append(URLQueryItem(name: "filter", value: "buyingOptions:{AUCTION|FIXED_PRICE}"))
        
        // Filter for US marketplace for more consistent results
        components.queryItems?.append(URLQueryItem(name: "filter", value: "itemLocationCountry:US"))
        
        guard let url = components.url else {
            print("❌ Failed to create URL")
            return .failure(EbayError.invalidURL)
        }
        
        print("🔗 API URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // According to documentation, must specify marketplace ID
        request.addValue("EBAY_US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                return .failure(EbayError.invalidResponse)
            }
            
            print("🌐 API Response Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // Parse the response with proper price calculations
                return parseSearchResponse(data: data)
            } else if httpResponse.statusCode == 429 {
                print("⚠️ Rate limit exceeded")
                if let errorText = String(data: data, encoding: .utf8) {
                    print("❌ API Error: \(errorText)")
                }
                return .failure(EbayError.rateLimitExceeded)
            } else {
                if let errorText = String(data: data, encoding: .utf8) {
                    print("❌ API Error: \(errorText)")
                }
                return .failure(EbayError.httpError(httpResponse.statusCode))
            }
        } catch {
            print("❌ Network Error: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    // Updated parsing function for OAuth response format
    private func parseOAuthResponse(data: Data) -> Result<EbaySearchResult, Error> {
        do {
            // Log a preview of the response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                let maxLength = min(500, jsonString.count)
                let previewString = String(jsonString.prefix(maxLength))
                print("📦 JSON Preview: \(previewString)...")
            }
            
            // Decode the JSON data into our model
            let decoder = JSONDecoder()
            var responseResult = try decoder.decode(EbayResponseResult.self, from: data)
            
            // Handle warnings and errors in the response
            if let warning = responseResult.warning, !warning.isEmpty {
                print("⚠️ API Warning: \(warning.first?.message ?? "Unknown warning")")
            }
            
            if let error = responseResult.error {
                print("❌ API Error: \(error.message ?? "Unknown error")")
                return .failure(EbayError.apiError(error.message ?? "Unknown error"))
            }
            
            // Check if we have any items
            guard let items = responseResult.itemSummaries, !items.isEmpty else {
                print("📭 No items found in response")
                return .failure(EbayError.noItemsFound)
            }
            
            print("🔢 Found \(items.count) total items")
            
            // Calculate price statistics from the returned items
            var lowestPrice = Double.greatestFiniteMagnitude
            var highestPrice = 0.0
            var totalPrice = 0.0
            var itemCount = 0
            var validItems = [EbayItem]()
            
            // Process each item to extract price data
            for item in items {
                // Extract price and create EbayItem objects
                let priceValue = item.priceValue
                if priceValue > 0 {
                    lowestPrice = min(lowestPrice, priceValue)
                    highestPrice = max(highestPrice, priceValue)
                    totalPrice += priceValue
                    itemCount += 1
                    
                    // Create simple EbayItem object from EbayItemSummary
                    let ebayItem = EbayItem(
                        title: item.title ?? "Unknown",
                        price: priceValue,
                        imageUrl: item.imageUrl,
                        condition: item.condition ?? "Not specified",
                        soldDate: item.soldDate
                    )
                    validItems.append(ebayItem)
                }
            }
            
            // If no valid items with prices were found, return an error
            if itemCount == 0 {
                print("❌ No items with valid prices found")
                return .failure(EbayError.noItemsFound)
            }
            
            // Calculate average price
            let averagePrice = totalPrice / Double(itemCount)
            
            print("💰 Price statistics: Avg=$\(String(format: "%.2f", averagePrice)), Range: $\(String(format: "%.2f", lowestPrice))-$\(String(format: "%.2f", highestPrice)), Count: \(itemCount)")
            
            // Create a result with calculated price statistics
            let result = EbaySearchResult(
                averagePrice: averagePrice,
                lowestPrice: lowestPrice,
                highestPrice: highestPrice,
                itemCount: itemCount,
                items: validItems
            )
            
            return .success(result)
        } catch {
            print("❌ JSON Parsing Error: \(error.localizedDescription)")
            return .failure(EbayError.parsingError(error.localizedDescription))
        }
    }
    
    // Helper to format eBay dates nicely 
    private func formatSoldDate(_ dateString: String) -> String {
        // eBay API typically returns ISO 8601 format dates
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            
            return displayFormatter.string(from: date)
        }
        
        // If parsing fails, just use a recent placeholder
        let calendar = Calendar.current
        if let recentDate = calendar.date(byAdding: .day, value: -Int.random(in: 1...14), to: Date()) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            
            return displayFormatter.string(from: recentDate)
        }
        
        return "Recently"
    }
    
    // Basic parsing function for legacy Finding API (keeping for fallback if needed)
    private func parseResponse(data: Data) -> Result<EbaySearchResult, Error> {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let findCompletedItemsResponse = json?["findCompletedItemsResponse"] as? [[String: Any]],
                  let response = findCompletedItemsResponse.first,
                  let searchResult = response["searchResult"] as? [String: Any],
                  let countStr = searchResult["@count"] as? String,
                  let count = Int(countStr) else {
                return .failure(EbayError.parsingError("Failed to parse response"))
            }
            
            if count == 0 {
                return .failure(EbayError.noItemsFound)
            }
            
            guard let itemsJson = searchResult["item"] as? [[String: Any]] else {
                return .failure(EbayError.parsingError("No items in response"))
            }
            
            var items: [EbayItem] = []
            var totalPrice: Double = 0
            
            for itemJson in itemsJson {
                // Basic item parsing
                let title = itemJson["title"] as? String ?? "Unknown"
                
                let sellingStatus = itemJson["sellingStatus"] as? [String: Any]
                let convertedPrice = sellingStatus?["convertedCurrentPrice"] as? [String: Any]
                let priceValue = convertedPrice?["__value__"] as? String
                let price = Double(priceValue ?? "0") ?? 0
                
                let condition = (itemJson["condition"] as? [String: Any])?["conditionDisplayName"] as? String ?? "Not specified"
                let imageUrl = itemJson["galleryURL"] as? String
                
                if price > 0 {
                    let item = EbayItem(
                        title: title,
                        price: price,
                        imageUrl: imageUrl,
                        condition: condition,
                        soldDate: nil
                    )
                    
                    items.append(item)
                    totalPrice += price
                }
            }
            
            if items.isEmpty {
                return .failure(EbayError.noItemsFound)
            }
            
            let averagePrice = totalPrice / Double(items.count)
            
            let result = EbaySearchResult(
                averagePrice: averagePrice,
                lowestPrice: averagePrice,
                highestPrice: averagePrice,
                itemCount: items.count,
                items: items
            )
            
            return .success(result)
        } catch {
            return .failure(EbayError.parsingError(error.localizedDescription))
        }
    }
    
    private func generateMockResults(for keyword: String, count: Int) -> Result<EbaySearchResult, Error> {
        print("🔄 Generating mock results for: \(keyword)")
        
        // Create random number of items between 5 and count
        let itemCount = min(max(5, Int.random(in: 5...count)), 25)
        
        // Determine more realistic base price based on product type keywords
        let keywordLower = keyword.lowercased()
        var basePrice: Double = 25.0 // Default base price
        
        // Common electronics
        if keywordLower.contains("iphone") || keywordLower.contains("smartphone") {
            basePrice = 300.0
        } else if keywordLower.contains("ipad") || keywordLower.contains("tablet") {
            basePrice = 250.0
        } else if keywordLower.contains("laptop") || keywordLower.contains("macbook") {
            basePrice = 600.0
        } else if keywordLower.contains("camera") || keywordLower.contains("lens") {
            basePrice = 150.0
        } else if keywordLower.contains("tv") || keywordLower.contains("television") {
            basePrice = 200.0
        } else if keywordLower.contains("gaming") || keywordLower.contains("console") || keywordLower.contains("playstation") || keywordLower.contains("xbox") {
            basePrice = 250.0
        } 
        // Clothing and accessories
        else if keywordLower.contains("shoes") || keywordLower.contains("sneakers") {
            basePrice = 70.0
        } else if keywordLower.contains("watch") {
            basePrice = 120.0
        } else if keywordLower.contains("jacket") || keywordLower.contains("coat") {
            basePrice = 60.0
        } 
        // Home items
        else if keywordLower.contains("furniture") || keywordLower.contains("chair") || keywordLower.contains("sofa") {
            basePrice = 150.0
        } else if keywordLower.contains("kitchen") || keywordLower.contains("appliance") {
            basePrice = 80.0
        }
        // Add some randomness to the base price
        basePrice *= Double.random(in: 0.9...1.1)
        
        // Get a few working image URLs
        let imageURLs = [
            "https://placehold.co/200x200/png?text=\(keyword.replacingOccurrences(of: " ", with: "+"))",
            "https://dummyimage.com/200x200/000/fff&text=\(keyword.replacingOccurrences(of: " ", with: "+"))",
            "https://picsum.photos/seed/\(keyword.replacingOccurrences(of: " ", with: ""))/200/200",
            "https://via.placeholder.com/200/444444/FFFFFF/?text=\(keyword.replacingOccurrences(of: " ", with: "+"))"
        ]
        
        // Create mock items
        var items: [EbayItem] = []
        var totalPrice: Double = 0
        var lowestPrice = Double.greatestFiniteMagnitude
        var highestPrice: Double = 0
        
        for i in 1...itemCount {
            // Create price with some variation, but keep it somewhat realistic
            let variationFactor = Double.random(in: 0.85...1.15)
            let condition = ["New", "Used - Like New", "Used - Good", "Used - Fair"].randomElement() ?? "Used"
            
            // Used items should be cheaper
            let conditionFactor = condition.contains("New") ? 1.0 : 
                                  condition.contains("Like New") ? 0.9 :
                                  condition.contains("Good") ? 0.8 : 0.7
            
            let price = basePrice * variationFactor * conditionFactor
            
            // Create better titles
            let qualifiers = ["Authentic", "Genuine", "Official", "Premium", "Deluxe", "Standard", "Classic"]
            let qualifier = qualifiers.randomElement() ?? ""
            let itemSpecific = i % 2 == 0 ? "Model \(2020 + i % 5)" : "Series \(Int.random(in: 1...10))"
            
            // Select a random image URL
            let imageUrl = imageURLs.randomElement() ?? imageURLs[0]
            
            // Create mock item
            let item = EbayItem(
                title: "\(qualifier) \(keyword) \(itemSpecific) - \(condition)",
                price: price,
                imageUrl: imageUrl,
                condition: condition,
                soldDate: formatMockSoldDate()
            )
            
            items.append(item)
            totalPrice += price
            
            // Update price ranges
            lowestPrice = min(lowestPrice, price)
            highestPrice = max(highestPrice, price)
        }
        
        // Calculate average price
        let averagePrice = totalPrice / Double(itemCount)
        
        // Create mock search result
        let result = EbaySearchResult(
            averagePrice: averagePrice,
            lowestPrice: lowestPrice,
            highestPrice: highestPrice,
            itemCount: itemCount,
            items: items
        )
        
        print("✅ Created \(itemCount) mock results with price range: $\(String(format: "%.2f", lowestPrice)) - $\(String(format: "%.2f", highestPrice))")
        return .success(result)
    }
    
    private func formatMockSoldDate() -> String {
        // Generate a random recent date
        let calendar = Calendar.current
        if let recentDate = calendar.date(byAdding: .day, value: -Int.random(in: 1...30), to: Date()) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: recentDate)
        }
        return "Recently"
    }
    
    // Parse the response from the eBay Browse API search
    private func parseSearchResponse(data: Data) -> Result<EbaySearchResult, Error> {
        do {
            // Log a preview of the response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                let maxLength = min(500, jsonString.count)
                let previewString = String(jsonString.prefix(maxLength))
                print("📦 JSON Preview: \(previewString)...")
            }
            
            // Decode the JSON data into our model
            let decoder = JSONDecoder()
            var responseResult = try decoder.decode(EbayResponseResult.self, from: data)
            
            // Handle warnings and errors in the response
            if let warning = responseResult.warning, !warning.isEmpty {
                print("⚠️ API Warning: \(warning.first?.message ?? "Unknown warning")")
            }
            
            if let error = responseResult.error {
                print("❌ API Error: \(error.message ?? "Unknown error")")
                return .failure(EbayError.apiError(error.message ?? "Unknown error"))
            }
            
            // Check if we have any items
            guard let items = responseResult.itemSummaries, !items.isEmpty else {
                print("📭 No items found in response")
                return .failure(EbayError.noItemsFound)
            }
            
            print("🔢 Found \(items.count) total items")
            
            // Calculate price statistics from the returned items
            var lowestPrice = Double.greatestFiniteMagnitude
            var highestPrice = 0.0
            var totalPrice = 0.0
            var itemCount = 0
            var validItems = [EbayItem]()
            
            // Process each item to extract price data
            for item in items {
                // Extract price and create EbayItem objects
                let priceValue = item.priceValue
                if priceValue > 0 {
                    lowestPrice = min(lowestPrice, priceValue)
                    highestPrice = max(highestPrice, priceValue)
                    totalPrice += priceValue
                    itemCount += 1
                    
                    // Create simple EbayItem object from EbayItemSummary
                    let ebayItem = EbayItem(
                        title: item.title ?? "Unknown",
                        price: priceValue,
                        imageUrl: item.imageUrl,
                        condition: item.condition ?? "Not specified",
                        soldDate: item.soldDate
                    )
                    validItems.append(ebayItem)
                }
            }
            
            // If no valid items with prices were found, return an error
            if itemCount == 0 {
                print("❌ No items with valid prices found")
                return .failure(EbayError.noItemsFound)
            }
            
            // Calculate average price
            let averagePrice = totalPrice / Double(itemCount)
            
            print("💰 Price statistics: Avg=$\(String(format: "%.2f", averagePrice)), Range: $\(String(format: "%.2f", lowestPrice))-$\(String(format: "%.2f", highestPrice)), Count: \(itemCount)")
            
            // Create a result with calculated price statistics
            let result = EbaySearchResult(
                averagePrice: averagePrice,
                lowestPrice: lowestPrice,
                highestPrice: highestPrice,
                itemCount: itemCount,
                items: validItems
            )
            
            return .success(result)
        } catch {
            print("❌ JSON Parsing Error: \(error.localizedDescription)")
            return .failure(EbayError.parsingError(error.localizedDescription))
        }
    }
} 
