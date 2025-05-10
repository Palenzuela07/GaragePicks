import SwiftUI

struct SubscriptionRequiredView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                
                Text("Premium Feature")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("This feature requires an active subscription")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Feature list
            VStack(alignment: .leading, spacing: 16) {
                Text("Subscription includes:")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                FeatureRow(icon: "camera.viewfinder", text: "Unlimited photo analysis")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Real-time price tracking")
                FeatureRow(icon: "tag", text: "Advanced eBay search integration")
                FeatureRow(icon: "dollarsign.circle", text: "Price history and trends")
            }
            .padding(.horizontal)
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: {
                    isLoading = true
                    // Open subscription URL
                    if let url = URL(string: "https://garagepickapp.com/login.html") {
                        UIApplication.shared.open(url)
                    }
                    isLoading = false
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Subscribe Now")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Maybe Later")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .padding(24)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    SubscriptionRequiredView()
} 