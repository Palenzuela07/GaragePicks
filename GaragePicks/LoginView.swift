import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isShowingMainView = false
    
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
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.password)
                }
                .padding(.horizontal, 30)
                
                // Login Button
                Button(action: {
                    // TODO: Implement actual login logic
                    isShowingMainView = true
                }) {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
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
        }
    }
}

#Preview {
    LoginView()
} 