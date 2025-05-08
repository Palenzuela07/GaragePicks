import SwiftUI
import FirebaseAuth
import FirebaseCore

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isShowingMainView = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isFirebaseConnected = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo and Title
                VStack(spacing: 10) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("GaragePicks")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top, 50)
                
                // Firebase Connection Status
                HStack {
                    Image(systemName: isFirebaseConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isFirebaseConnected ? .green : .red)
                    Text(isFirebaseConnected ? "Connected to Firebase" : "Not connected to Firebase")
                        .font(.caption)
                        .foregroundColor(isFirebaseConnected ? .green : .red)
                }
                .padding(.bottom, 10)
                
                // Login Form
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .disabled(isLoading)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.password)
                        .disabled(isLoading)
                }
                .padding(.horizontal, 30)
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal, 30)
                }
                
                // Login Button
                Button(action: {
                    signIn()
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isLoading ? Color.gray : Color.blue)
                .cornerRadius(10)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                .padding(.horizontal, 30)
                
                // Sign Up Link
                VStack(spacing: 5) {
                    Text("Don't have an account?")
                        .foregroundColor(.secondary)
                    
                    Link("Sign Up Now", destination: URL(string: "https://garagepickapp.com/login.html?form=signup")!)
                        .foregroundColor(.blue)
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $isShowingMainView) {
                ContentView()
            }
            .onAppear {
                checkFirebaseConnection()
            }
        }
    }
    
    private func checkFirebaseConnection() {
        if let app = FirebaseApp.app() {
            print("✅ Firebase is connected!")
            print("📱 App name: \(app.name)")
            print("🔑 Project ID: \(app.options.projectID ?? "unknown")")
            isFirebaseConnected = true
        } else {
            print("❌ Firebase is not connected!")
            isFirebaseConnected = false
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            
            if let error = error {
                errorMessage = error.localizedDescription
                print("❌ Sign in error: \(error.localizedDescription)")
            } else {
                print("✅ Sign in successful!")
                isShowingMainView = true
            }
        }
    }
}

#Preview {
    LoginView()
} 