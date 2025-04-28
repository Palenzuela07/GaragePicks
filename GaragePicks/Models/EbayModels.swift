import Foundation
import ObjectiveC

// Rename to avoid conflict with EbaySearchResult in EbayApiService.swift
struct EbayResponseResult: Codable {
    var itemSummaries: [EbayItemSummary]?
    var total: Int?
    var limit: Int?
    var offset: Int?
    var next: String?
    
    // Extra fields that might be in the response
    var warning: [EbayWarning]?
    var error: EbayModelError?
    
    enum CodingKeys: String, CodingKey {
        case itemSummaries, total, limit, offset, next, warning, error
    }
}

struct EbayWarning: Codable {
    var message: String?
    var category: String?
    var domain: String?
    var errorId: Int?
    var parameters: [EbayParameter]?
    
    enum CodingKeys: String, CodingKey {
        case message, category, domain, errorId, parameters
    }
}

struct EbayParameter: Codable {
    var name: String?
    var value: String?
    
    enum CodingKeys: String, CodingKey {
        case name, value
    }
}

// Rename to avoid conflict with EbayError in EbayApiService.swift
struct EbayModelError: Codable {
    var message: String?
    var category: String?
    var domain: String?
    var errorId: Int?
    var parameters: [EbayParameter]?
    
    enum CodingKeys: String, CodingKey {
        case message, category, domain, errorId, parameters
    }
}

struct EbayItemSummary: Codable, Identifiable {
    var id: String
    var title: String?
    var price: EbayPrice?
    var image: EbayImage?
    var itemHref: String?
    var itemWebUrl: String?
    var seller: EbaySeller?
    var condition: String?
    var conditionId: String?
    var thumbnailImages: [EbayImage]?
    var shippingOptions: [EbayShippingOption]?
    var bidCount: Int?
    var currentBidPrice: EbayPrice?
    var itemAffiliateWebUrl: String?
    var itemCreationDate: String?
    var itemEndDate: String?
    var availableCoupons: Bool?
    var priorityListing: Bool?
    var topRatedBuyingExperience: Bool?
    var buyingOptions: [String]?
    var categories: [EbayCategory]?
    var compatibilityProperties: [EbayCompatibilityProperty]?
    var marketingPrice: EbayMarketingPrice?
    var itemLocationCountry: String?
    var itemLocationZip: String?
    var additionalImages: [EbayImage]?
    var shortDescription: String?
    var subtitle: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "itemId"
        case title, price, image, itemHref, itemWebUrl, seller, condition, conditionId
        case thumbnailImages, shippingOptions, bidCount, currentBidPrice, itemAffiliateWebUrl
        case itemCreationDate, itemEndDate, availableCoupons, priorityListing
        case topRatedBuyingExperience, buyingOptions, categories, compatibilityProperties
        case marketingPrice, itemLocationCountry, itemLocationZip, additionalImages
        case shortDescription, subtitle
    }
}

struct EbayPrice: Codable {
    var value: String?
    var currency: String?
    
    enum CodingKeys: String, CodingKey {
        case value, currency
    }
}

struct EbayImage: Codable {
    var imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case imageUrl
    }
}

struct EbaySeller: Codable {
    var username: String?
    var feedbackPercentage: String?
    var feedbackScore: Int?
    
    enum CodingKeys: String, CodingKey {
        case username, feedbackPercentage, feedbackScore
    }
}

struct EbayShippingOption: Codable {
    var shippingCost: EbayPrice?
    var shippingCostType: String?
    var type: String?
    
    enum CodingKeys: String, CodingKey {
        case shippingCost, shippingCostType, type
    }
}

struct EbayCategory: Codable {
    var categoryId: String?
    var categoryName: String?
    
    enum CodingKeys: String, CodingKey {
        case categoryId, categoryName
    }
}

struct EbayCompatibilityProperty: Codable {
    var name: String?
    var value: String?
    
    enum CodingKeys: String, CodingKey {
        case name, value
    }
}

struct EbayMarketingPrice: Codable {
    var discountAmount: EbayPrice?
    var discountPercentage: String?
    var originalPrice: EbayPrice?
    
    enum CodingKeys: String, CodingKey {
        case discountAmount, discountPercentage, originalPrice
    }
}

// Extension for price statistics
extension EbayResponseResult {
    private static var averagePriceKey = "averagePriceKey"
    private static var lowestPriceKey = "lowestPriceKey"
    private static var highestPriceKey = "highestPriceKey"
    private static var itemCountKey = "itemCountKey"
    
    var averagePrice: Double {
        get { return objc_getAssociatedObject(self, &EbayResponseResult.averagePriceKey) as? Double ?? 0.0 }
        set { objc_setAssociatedObject(self, &EbayResponseResult.averagePriceKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
    
    var lowestPrice: Double {
        get { return objc_getAssociatedObject(self, &EbayResponseResult.lowestPriceKey) as? Double ?? 0.0 }
        set { objc_setAssociatedObject(self, &EbayResponseResult.lowestPriceKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
    
    var highestPrice: Double {
        get { return objc_getAssociatedObject(self, &EbayResponseResult.highestPriceKey) as? Double ?? 0.0 }
        set { objc_setAssociatedObject(self, &EbayResponseResult.highestPriceKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
    
    var itemCount: Int {
        get { return objc_getAssociatedObject(self, &EbayResponseResult.itemCountKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &EbayResponseResult.itemCountKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

// Helper extensions for EbayItemSummary
extension EbayItemSummary {
    // Get a formatted price string
    var formattedPrice: String {
        if let priceValue = price?.value, let priceCurrency = price?.currency {
            return "\(priceCurrency) \(priceValue)"
        } else if let bidPriceValue = currentBidPrice?.value, let bidPriceCurrency = currentBidPrice?.currency {
            return "\(bidPriceCurrency) \(bidPriceValue)"
        } else {
            return "Price unavailable"
        }
    }
    
    // Get the price as a Double
    var priceValue: Double {
        if let priceStr = price?.value, let price = Double(priceStr) {
            return price
        } else if let bidPriceStr = currentBidPrice?.value, let bidPrice = Double(bidPriceStr) {
            return bidPrice
        }
        return 0.0
    }
    
    // Get image URL
    var imageUrl: String? {
        if let url = image?.imageUrl {
            return url
        } else if let url = thumbnailImages?.first?.imageUrl {
            return url
        }
        return nil
    }
    
    // Get a formatted sold date (or nil if not available)
    var soldDate: String? {
        guard let dateString = itemEndDate else { return nil }
        
        // Convert ISO date to readable format
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        guard let date = formatter.date(from: dateString) else {
            return nil
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        
        return displayFormatter.string(from: date)
    }
} 