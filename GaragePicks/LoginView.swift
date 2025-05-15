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
    @State private var showResetAlert = false
    @State private var resetEmail = ""
    @State private var resetMessage: String?
    
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
                
                // Forgot Password Button
                Button("Forgot Password?") {
                    if let url = URL(string: "https://garagepickapp.com/reset-password.html") {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundColor(.blue)
                .padding(.top, 8)
                
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
            // Password Reset Alert
            .alert("Reset Password", isPresented: $showResetAlert, actions: {
                TextField("Enter your email", text: $resetEmail)
                Button("Send Reset Link") {
                    sendPasswordReset()
                }
                Button("Cancel", role: .cancel) { }
            }, message: {
                if let msg = resetMessage {
                    Text(msg)
                }
            })
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
                // Check for specific error codes for wrong password, user not found, invalid email, or invalid credential
                let nsError = error as NSError
                let errorDescription = error.localizedDescription.lowercased()
                if nsError.code == AuthErrorCode.wrongPassword.rawValue ||
                    nsError.code == AuthErrorCode.userNotFound.rawValue ||
                    nsError.code == AuthErrorCode.invalidEmail.rawValue ||
                    nsError.code == AuthErrorCode.invalidCredential.rawValue ||
                    errorDescription.contains("malformed") ||
                    errorDescription.contains("invalid") ||
                    errorDescription.contains("badly formatted") {
                    errorMessage = "Incorrect password or email"
                } else {
                    errorMessage = error.localizedDescription
                }
                print("❌ Sign in error: \(error.localizedDescription)")
            } else {
                print("✅ Sign in successful!")
                isShowingMainView = true
            }
        }
    }
    
    private func sendPasswordReset() {
        guard !resetEmail.isEmpty else {
            resetMessage = "Please enter your email."
            return
        }
        Auth.auth().sendPasswordReset(withEmail: resetEmail) { error in
            if let error = error {
                resetMessage = error.localizedDescription
            } else {
                resetMessage = "A password reset link has been sent to your email."
            }
        }
    }
}

#Preview {
    LoginView()
} 