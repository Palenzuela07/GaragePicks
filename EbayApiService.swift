func createUrlComponents(keywords: String, page: Int = 1) -> URLComponents {
    var components = URLComponents(string: "https://api.ebay.com/buy/browse/v1/item_summary/search")!
    
    components.queryItems = [
        URLQueryItem(name: "q", value: keywords),
        URLQueryItem(name: "limit", value: String(limit)),
        URLQueryItem(name: "offset", value: String((page - 1) * limit)),
        URLQueryItem(name: "descriptionSearch", value: "false")
    ]
    
    return components
} 