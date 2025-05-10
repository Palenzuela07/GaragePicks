import SwiftUI
import FirebaseAuth
import SafariServices
import UIKit

class AuthManager: ObservableObject {
    @Published var isSignedOut = false
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            isSignedOut = true
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

struct ProfileMenuView: View {
    @Binding var isShowing: Bool
    @Binding var showProfileSettings: Bool
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager()
    @ObservedObject var stripeService: StripeService
    @State private var showSignOutError = false
    @State private var errorMessage = ""
    @State private var showSubscriptionSafari = false
    
    private let subscriptionURL = URL(string: "https://garagepickapp.com/login.html")!
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isShowing = false
                    }
                }
            
            // Menu panel
            HStack {
                Spacer()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Menu")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: {
                            withAnimation {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    
                    Divider()
                    
                    // Subscription Status
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: stripeService.subscriptionStatus.icon)
                                .foregroundColor(stripeService.subscriptionStatus.color)
                            Text("Subscription Status:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(stripeService.subscriptionStatus.description)
                                .font(.subheadline)
                                .foregroundColor(stripeService.subscriptionStatus.color)
                        }
                        
                        if let endDate = stripeService.subscriptionEndDate {
                            Text("Valid until: \(endDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // Menu Items
                    VStack(alignment: .leading, spacing: 0) {
                        MenuButton(title: "Profile & Settings", icon: "person.circle.fill") {
                            isShowing = false
                            if let url = URL(string: "https://garagepickapp.com/login.html") {
                                UIApplication.shared.open(url)
                            }
                        }
                        
                        MenuButton(title: "Subscription & Billing", icon: "creditcard.fill") {
                            isShowing = false
                            if let url = URL(string: "https://garagepickapp.com/login.html") {
                                UIApplication.shared.open(url)
                            }
                        }
                        
                        MenuButton(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right") {
                            authManager.signOut()
                        }
                    }
                    
                    Spacer()
                }
                .frame(width: 280)
                .background(Color(.systemBackground))
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .transition(.move(edge: .trailing))
        .alert("Sign Out Error", isPresented: $showSignOutError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: authManager.isSignedOut) { _, isSignedOut in
            if isSignedOut {
                withAnimation {
                    isShowing = false
                }
            }
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .frame(width: 20)
                    .alignmentGuide(.leading) { d in d[.leading] }
                
                Text(title)
                    .font(.body)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        
        Divider()
    }
}

#Preview {
    ProfileMenuView(isShowing: .constant(true), showProfileSettings: .constant(false), stripeService: StripeService())
} 