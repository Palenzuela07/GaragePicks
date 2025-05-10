import Foundation
import FirebaseAuth
import SwiftUI

enum SubscriptionStatus {
    case active
    case canceled
    case expired
    case none
    
    var icon: String {
        switch self {
        case .active:
            return "checkmark.circle.fill"
        case .canceled:
            return "exclamationmark.circle.fill"
        case .expired:
            return "xmark.circle.fill"
        case .none:
            return "questionmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .active:
            return .green
        case .canceled:
            return .orange
        case .expired:
            return .red
        case .none:
            return .secondary
        }
    }
    
    var description: String {
        switch self {
        case .active:
            return "Active"
        case .canceled:
            return "Canceled"
        case .expired:
            return "Expired"
        case .none:
            return "No Subscription"
        }
    }
}

class StripeService: ObservableObject {
    private let stripeSecretKey = StripeConfig.secretKey
    private let baseURL = StripeConfig.apiURL
    
    @Published var subscriptionStatus: SubscriptionStatus = .none
    @Published var isLoading = false
    @Published var error: String?
    @Published var subscriptionEndDate: Date?
    
    var isSubscriptionActive: Bool {
        subscriptionStatus == .active
    }
    
    func checkSubscriptionStatus(customerId: String) async {
        isLoading = true
        error = nil
        
        let endpoint = "\(baseURL)/customers/\(customerId)/subscriptions"
        guard var urlComponents = URLComponents(string: endpoint) else {
            handleError("Invalid URL")
            return
        }
        
        // Add query parameters to get all subscriptions (including canceled)
        urlComponents.queryItems = [
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "expand[]", value: "data.cancel_at")
        ]
        
        guard let url = urlComponents.url else {
            handleError("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(stripeSecretKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                handleError("Invalid response")
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let result = try decoder.decode(StripeSubscriptionResponse.self, from: data)
                
                DispatchQueue.main.async {
                    if let subscription = result.data.first {
                        let endDate = Date(timeIntervalSince1970: TimeInterval(subscription.currentPeriodEnd))
                        self.subscriptionEndDate = endDate
                        
                        // Determine subscription status
                        if subscription.status == "active" {
                            if subscription.cancelAtPeriodEnd {
                                self.subscriptionStatus = .canceled
                            } else {
                                self.subscriptionStatus = .active
                            }
                        } else if subscription.status == "canceled" {
                            self.subscriptionStatus = .expired
                        } else {
                            self.subscriptionStatus = .none
                        }
                    } else {
                        self.subscriptionStatus = .none
                        self.subscriptionEndDate = nil
                    }
                    self.isLoading = false
                }
                
            case 401:
                handleError("Authentication failed. Please check your Stripe API key.")
                
            case 404:
                handleError("Customer not found")
                
            case 429:
                handleError("Too many requests. Please try again later.")
                
            default:
                let errorResponse = try? JSONDecoder().decode(StripeErrorResponse.self, from: data)
                handleError(errorResponse?.error.message ?? "Failed to check subscription (Error \(httpResponse.statusCode))")
            }
        } catch {
            handleError(error.localizedDescription)
        }
    }
    
    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            self.error = message
            self.isLoading = false
            self.subscriptionStatus = .none
            self.subscriptionEndDate = nil
            print("Stripe Error: \(message)") // For debugging
        }
    }
}

// Stripe Response Models
struct StripeSubscriptionResponse: Codable {
    let data: [StripeSubscription]
}

struct StripeSubscription: Codable {
    let id: String
    let status: String
    let currentPeriodEnd: Int
    let cancelAtPeriodEnd: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
    }
}

struct StripeErrorResponse: Codable {
    let error: StripeError
}

struct StripeError: Codable {
    let message: String
} 