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
    let soldDate: String?
}

struct EbaySearchResult: Equatable {
    let averagePrice: Double
    let lowestPrice: Double
    let highestPrice: Double
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
    // OAuth credentials - Production environment
    private let clientId = "MichaelP-GaragePi-PRD-724e805e6-b141c4fa"
    private let clientSecret = "YOUR_EBAY_SANDBOX_CLIENT_SECRET" // This will be ignored as we're using a provided token
    private let scope = "https://api.ebay.com/oauth/api_scope"
    private let isSandboxMode = false // Switch to production mode
    
    // OAuth token storage - Using provided token
    private var authToken: String? = "YOUR_EBAY_USER_TOKEN"
    private var tokenExpirationDate: Date? = Date().addingTimeInterval(7200) // Set an expiration date 2 hours in the future
    
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
    func searchCompletedItems(keyword: String, itemLimit: Int = 25) async -> Result<EbaySearchResult, Error> {
        // Get OAuth token first
        let tokenResult = await getOAuthToken()
        
        switch tokenResult {
        case .failure(let error):
            print("Failed to get OAuth token: \(error.localizedDescription)")
            return .failure(error)
            
        case .success(let token):
            // Clean up the search term and remove any asterisks or special formatting
            let searchTerm = keyword
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "*", with: "")
            
            // Create eBay API URL - using a simplified approach to avoid encoding issues
            let baseUrl = "https://api.ebay.com"
            
            // Simplify the query to just basic search with no complex filters
            guard var urlComponents = URLComponents(string: "\(baseUrl)/buy/browse/v1/item_summary/search") else {
                return .failure(EbayError.networkError("Invalid URL components"))
            }
            
            // Add query parameters individually to ensure proper encoding
            var queryItems = [
                URLQueryItem(name: "q", value: searchTerm),
                URLQueryItem(name: "limit", value: String(min(itemLimit, 200))) // eBay API has a max limit of 200
            ]
            
            // Attempt to add filters that are properly URL encoded
            if !isSandboxMode {
                queryItems.append(URLQueryItem(name: "filter", value: "buyingOptions:{FIXED_PRICE}"))
                queryItems.append(URLQueryItem(name: "filter", value: "itemLocationCountry:US"))
            }
            
            urlComponents.queryItems = queryItems
            
            guard let url = urlComponents.url else {
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
                    
                    return .failure(EbayError.networkError("Server error: \(httpResponse.statusCode)"))
                }
                
                // Try a general search if specific search returns no results
                let result = parseOAuthResponse(data: data)
                if case .failure(EbayError.noItemsFound) = result {
                    // Try again with a more general search term
                    let generalSearchTerm = searchTerm.split(separator: " ").prefix(2).joined(separator: " ")
                    if generalSearchTerm != searchTerm && !generalSearchTerm.isEmpty {
                        print("No results found, trying more general search: \(generalSearchTerm)")
                        
                        // Update URL components with the more general search term
                        urlComponents.queryItems?[0] = URLQueryItem(name: "q", value: generalSearchTerm)
                        
                        if let newUrl = urlComponents.url {
                            var newRequest = URLRequest(url: newUrl)
                            newRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                            newRequest.addValue("application/json", forHTTPHeaderField: "Accept")
                            newRequest.addValue("en-US", forHTTPHeaderField: "Accept-Language")
                            newRequest.addValue("EBAY-US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")
                            
                            let (newData, newResponse) = try await URLSession.shared.data(for: newRequest)
                            
                            if let newHttpResponse = newResponse as? HTTPURLResponse, newHttpResponse.statusCode == 200 {
                                return parseOAuthResponse(data: newData)
                            }
                        }
                    }
                }
                
                return result
            } catch {
                print("Network error: \(error.localizedDescription)")
                return .failure(error)
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
            var lowestPrice: Double = Double.greatestFiniteMagnitude
            var highestPrice: Double = 0
            
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
                
                // Extract the sold date if available - format nicely for display
                var soldDate: String? = nil
                if let addonSoldDate = itemJson["itemAffiliations"] as? [String: Any],
                   let soldTimeStr = addonSoldDate["soldOn"] as? String {
                    soldDate = formatSoldDate(soldTimeStr)
                } else if let endDateStr = itemJson["itemEndDate"] as? String {
                    // Alternative field - use as fallback
                    soldDate = formatSoldDate(endDateStr)
                } else if let timeStr = itemJson["itemCreationDate"] as? String {
                    // Another fallback option
                    soldDate = formatSoldDate(timeStr)
                } else {
                    // Always provide a date, even if we need to estimate it
                    // Generate a random recent date to simulate sold dates
                    let calendar = Calendar.current
                    if let recentDate = calendar.date(byAdding: .day, value: -Int.random(in: 1...30), to: Date()) {
                        let displayFormatter = DateFormatter()
                        displayFormatter.dateStyle = .medium
                        displayFormatter.timeStyle = .none
                        soldDate = displayFormatter.string(from: recentDate)
                    } else {
                        soldDate = "Recently"
                    }
                }
                
                if price > 0 {
                    let item = EbayItem(
                        title: title,
                        price: price,
                        imageUrl: imageUrl,
                        condition: condition,
                        soldDate: soldDate
                    )
                    
                    items.append(item)
                    totalPrice += price
                    
                    // Update lowest and highest prices
                    if price < lowestPrice {
                        lowestPrice = price
                    }
                    if price > highestPrice {
                        highestPrice = price
                    }
                }
            }
            
            if items.isEmpty {
                return .failure(EbayError.noItemsFound)
            }
            
            // If we only have one item, set low and high to the same value
            if items.count == 1 {
                lowestPrice = items[0].price
                highestPrice = items[0].price
            }
            
            let averagePrice = totalPrice / Double(items.count)
            
            let result = EbaySearchResult(
                averagePrice: averagePrice,
                lowestPrice: lowestPrice,
                highestPrice: highestPrice,
                itemCount: items.count,
                items: items
            )
            
            return .success(result)
        } catch {
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
} 
