import Foundation
import FirebaseAuth
import SwiftUI

enum LocalSubscriptionStatus {
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
    
    @Published var subscriptionStatus: LocalSubscriptionStatus = .none
    @Published var isLoading = false
    @Published var error: String?
    @Published var subscriptionEndDate: Date?
    
    var isSubscriptionActive: Bool {
        subscriptionStatus == .active
    }
    
    func checkSubscriptionStatus(customerId: String) async {
        isLoading = true
        error = nil
        
        // Get the current user's email from Firebase
        guard let email = Auth.auth().currentUser?.email else {
            handleError("No user email found")
            return
        }
        
        do {
            let status = try await checkServerSubscriptionStatus(email: email)
            
            DispatchQueue.main.async {
                if let subscription = status.subscription {
                    // Parse the end date if available
                    if let endDateStr = subscription.currentPeriodEnd {
                        let formatter = ISO8601DateFormatter()
                        self.subscriptionEndDate = formatter.date(from: endDateStr)
                    }
                    
                    // Map server status to local enum
                    switch subscription.status {
                    case "active":
                        self.subscriptionStatus = subscription.cancelAtPeriodEnd ? .canceled : .active
                    case "canceled":
                        self.subscriptionStatus = .expired
                    default:
                        self.subscriptionStatus = .none
                    }
                } else {
                    self.subscriptionStatus = .none
                    self.subscriptionEndDate = nil
                }
                
                if let errorMessage = status.error {
                    self.error = errorMessage
                }
                
                self.isLoading = false
            }
        } catch {
            handleError(error.localizedDescription)
        }
    }
    
    private func checkServerSubscriptionStatus(email: String) async throws -> ServerSubscriptionStatus {
        guard let url = URL(string: "https://garagepickapp.com/api/subscription-status?email=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ServerSubscriptionStatus.self, from: data)
    }
    
    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            self.error = message
            self.isLoading = false
            self.subscriptionStatus = .none
            self.subscriptionEndDate = nil
            print("Subscription Error: \(message)") // For debugging
        }
    }
}

// Server Response Models
struct ServerSubscriptionStatus: Codable {
    let hasSubscription: Bool
    let subscription: Subscription?
    let message: String?
    let error: String?
    
    struct Subscription: Codable {
        let id: String
        let status: String
        let currentPeriodEnd: String?
        let cancelAtPeriodEnd: Bool
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