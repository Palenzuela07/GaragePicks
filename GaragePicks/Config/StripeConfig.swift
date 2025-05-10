import Foundation

enum StripeConfig {
    // We'll store these in the keychain in production
    static let secretKey: String = {
        #if DEBUG
        return "sk_test_YOUR_TEST_KEY" // Use test key for development
        #else
        return "YOUR_STRIPE_SECRET_KEY"
        #endif
    }()
    
    static let webhookSecret: String = {
        #if DEBUG
        return "whsec_test_YOUR_TEST_WEBHOOK" // Use test webhook for development
        #else
        return "YOUR_STRIPE_WEBHOOK_SECRET"
        #endif
    }()
    
    // Base URLs
    static let apiURL = "https://api.stripe.com/v1"
    static let webhookURL = "https://garagepickapp.com/api/stripe/webhook" // Update this to your webhook endpoint
} 