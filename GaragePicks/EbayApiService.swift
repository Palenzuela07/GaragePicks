//
//  EbayApiService.swift
//  GaragePicks
//
//  Created by Michael Palenzuela on 4/21/25.
//

import Foundation

// Simple result structures
struct EbayItem: Equatable {
    let title: String
    let price: Double
    let imageUrl: String?
    let condition: String
}

struct EbaySearchResult: Equatable {
    let averagePrice: Double
    let itemCount: Int
    let items: [EbayItem]
}

enum EbayError: Error {
    case networkError(String)
    case parsingError(String)
    case noItemsFound
    case authenticationError(String)
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

// Basic eBay API Service
class EbayApiService {
    // For development/testing
    private var useMockData = false // Set to false to use real API
    
    // OAuth credentials - Production environment
    private let clientId = "MichaelP-GaragePi-PRD-724e805e6-b141c4fa"
    private let clientSecret = "YOUR_EBAY_SANDBOX_CLIENT_SECRET" // This will be ignored as we're using a provided token
    private let scope = "https://api.ebay.com/oauth/api_scope"
    private let isSandboxMode = false // Switch to production mode
    
    // OAuth token storage - Using provided token
    private var authToken: String? = "YOUR_EBAY_USER_TOKEN"
    private var tokenExpirationDate: Date? = Date().addingTimeInterval(7200) // Set an expiration date 2 hours in the future
    
    // Public property to check if using mock data
    var isUsingMockData: Bool {
        return useMockData
    }
    
    // Method to toggle mock data
    func setUseMockData(_ value: Bool) {
        useMockData = value
        print("eBay API mock data mode set to: \(value)")
    }
    
    // OAuth token acquisition - using pre-supplied token in production mode
    private func getOAuthToken() async -> Result<String, Error> {
        // Check if we have a valid token already
        if let token = authToken, let expirationDate = tokenExpirationDate, expirationDate > Date() {
            return .success(token)
        }
        
        // If we're using a pre-supplied production token and it's expired, notify user
        if !isSandboxMode {
            // Check if token is initialized but expired
            if authToken != nil && (tokenExpirationDate == nil || tokenExpirationDate! <= Date()) {
                return .failure(EbayError.authenticationError("Pre-supplied eBay token has expired. Please provide a new token."))
            }
        }
        
        // For sandbox mode or if token isn't pre-supplied, request new token
        let baseUrl = isSandboxMode ? "https://api.sandbox.ebay.com" : "https://api.ebay.com"
        guard let url = URL(string: "\(baseUrl)/identity/v1/oauth2/token") else {
            return .failure(EbayError.authenticationError("Invalid OAuth URL"))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("Basic " + "\(clientId):\(clientSecret)".data(using: .utf8)!.base64EncodedString(), forHTTPHeaderField: "Authorization")
        
        let bodyParameters = "grant_type=client_credentials&scope=\(scope)"
        request.httpBody = bodyParameters.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(EbayError.authenticationError("Invalid response"))
            }
            
            if httpResponse.statusCode != 200 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("OAuth error response: \(responseString)")
                }
                return .failure(EbayError.authenticationError("Failed to obtain token: \(httpResponse.statusCode)"))
            }
            
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(OAuthToken.self, from: data)
            
            // Store the token and expiration
            self.authToken = tokenResponse.accessToken
            self.tokenExpirationDate = Date().addingTimeInterval(Double(tokenResponse.expiresIn - 300)) // 5 minutes buffer
            
            return .success(tokenResponse.accessToken)
        } catch {
            return .failure(EbayError.authenticationError("OAuth error: \(error.localizedDescription)"))
        }
    }
    
    // Basic function to search eBay
    func searchCompletedItems(keyword: String) async -> Result<EbaySearchResult, Error> {
        // Use mock data if enabled
        if useMockData {
            print("Using mock data for search: \"\(keyword)\"")
            return createMockData(keyword: keyword)
        }
        
        // Get OAuth token first
        let tokenResult = await getOAuthToken()
        
        switch tokenResult {
        case .failure(let error):
            print("Failed to get OAuth token: \(error.localizedDescription)")
            // Fall back to mock data on authentication error
            return createMockData(keyword: keyword)
            
        case .success(let token):
            // Clean up the search term
            let searchTerm = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Create eBay API URL - now using OAuth with sandbox support
            let baseUrl = isSandboxMode ? "https://api.sandbox.ebay.com" : "https://api.ebay.com"
            
            // Sandbox usually doesn't have real data, so we need to modify our filters
            var urlString: String
            if isSandboxMode {
                // Simpler query for sandbox - no filters as sandbox likely doesn't have soldItems
                urlString = "\(baseUrl)/buy/browse/v1/item_summary/search?q=\(searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=10"
                print("Using simplified query for sandbox")
            } else {
                // Production query with soldItems filter
                urlString = "\(baseUrl)/buy/browse/v1/item_summary/search?q=\(searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&filter=soldItems:true&limit=10"
            }
            
            guard let url = URL(string: urlString) else {
                return .failure(EbayError.networkError("Invalid URL"))
            }
            
            print("Requesting URL: \(url)")
            
            var request = URLRequest(url: url)
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            // Additional headers required by eBay API
            request.addValue("en-US", forHTTPHeaderField: "Accept-Language")
            request.addValue("EBAY-US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
            
            do {
                // API request with OAuth token
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    return .failure(EbayError.networkError("Invalid response"))
                }
                
                print("Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Error response: \(responseString)")
                        
                        // Check for specific error signatures
                        if responseString.contains("Service call has exceeded") || responseString.contains("RateLimiter") {
                            return .failure(EbayError.networkError("Rate limit exceeded. Please try again later."))
                        }
                    }
                    
                    // Check if we should fall back to mock data on server error
                    if httpResponse.statusCode == 500 || httpResponse.statusCode == 401 {
                        print("Server error \(httpResponse.statusCode) - falling back to mock data")
                        return createMockData(keyword: keyword)
                    }
                    
                    return .failure(EbayError.networkError("Server error: \(httpResponse.statusCode)"))
                }
                
                // JSON parsing updated for OAuth response format
                return parseOAuthResponse(data: data)
            } catch {
                print("Network error: \(error.localizedDescription)")
                // Fall back to mock data on error
                print("Network error - falling back to mock data")
                return createMockData(keyword: keyword)
            }
        }
    }
    
    // Updated parsing function for OAuth response format
    private func parseOAuthResponse(data: Data) -> Result<EbaySearchResult, Error> {
        do {
            // Debug: Print the raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw eBay response: \(responseString)")
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // Debug: Check if we have the expected keys
            if let json = json {
                print("Response keys: \(json.keys.joined(separator: ", "))")
            }
            
            // Handle case where API returns success but no items
            if let total = json?["total"] as? Int, total == 0 {
                print("eBay API returned zero results")
                return .failure(EbayError.noItemsFound)
            }
            
            guard let itemSummaries = json?["itemSummaries"] as? [[String: Any]],
                  !itemSummaries.isEmpty else {
                print("No itemSummaries found in response")
                return .failure(EbayError.noItemsFound)
            }
            
            var items: [EbayItem] = []
            var totalPrice: Double = 0
            
            for itemJson in itemSummaries {
                // Basic item parsing adapted for Browse API response
                let title = itemJson["title"] as? String ?? "Unknown"
                
                var price: Double = 0
                if let priceObj = itemJson["price"] as? [String: Any],
                   let value = priceObj["value"] as? String {
                    price = Double(value) ?? 0
                }
                
                let condition = (itemJson["condition"] as? String) ?? "Not specified"
                let imageUrl = (itemJson["image"] as? [String: Any])?["imageUrl"] as? String
                
                if price > 0 {
                    let item = EbayItem(
                        title: title,
                        price: price,
                        imageUrl: imageUrl,
                        condition: condition
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
                itemCount: items.count,
                items: items
            )
            
            return .success(result)
        } catch {
            return .failure(EbayError.parsingError(error.localizedDescription))
        }
    }
    
    // Mock data for testing
    private func createMockData(keyword: String) -> Result<EbaySearchResult, Error> {
        // Create more items and better pricing estimates based on the keyword
        var basePrice = 29.99 // default base price
        
        // Adjust price based on keywords
        let lowercaseKeyword = keyword.lowercased()
        if lowercaseKeyword.contains("jordan") || lowercaseKeyword.contains("nike") {
            basePrice = 179.99
        } else if lowercaseKeyword.contains("iphone") || lowercaseKeyword.contains("apple") {
            basePrice = 349.99
        } else if lowercaseKeyword.contains("vintage") || lowercaseKeyword.contains("antique") {
            basePrice = 89.99
        } else if lowercaseKeyword.contains("game") || lowercaseKeyword.contains("console") {
            basePrice = 149.99
        } else if lowercaseKeyword.contains("jewelry") || lowercaseKeyword.contains("gold") {
            basePrice = 249.99
        }
        
        // Generate 3-7 items with price variations
        let itemCount = Int.random(in: 3...7)
        var items: [EbayItem] = []
        
        for i in 1...itemCount {
            // Add some random price variation (±20%)
            let variation = Double.random(in: -0.2...0.2)
            let price = basePrice * (1.0 + variation)
            
            // Pick a condition
            let conditions = ["New", "Used", "Very Good", "Good", "Acceptable", "Like New"]
            let condition = conditions[Int.random(in: 0..<conditions.count)]
            
            // Create title with variations
            var title = keyword
            if i % 3 == 0 {
                title += " - Authentic"
            } else if i % 3 == 1 {
                title += " - Great Deal"
            }
            title += " (Item \(i))"
            
            let item = EbayItem(
                title: title,
                price: price,
                imageUrl: "https://example.com/image\(i).jpg",
                condition: condition
            )
            
            items.append(item)
        }
        
        let totalPrice = items.reduce(0.0) { $0 + $1.price }
        let averagePrice = totalPrice / Double(items.count)
        
        let result = EbaySearchResult(
            averagePrice: averagePrice,
            itemCount: items.count,
            items: items
        )
        
        return .success(result)
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
                        condition: condition
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
                itemCount: items.count,
                items: items
            )
            
            return .success(result)
        } catch {
            return .failure(EbayError.parsingError(error.localizedDescription))
        }
    }
} 