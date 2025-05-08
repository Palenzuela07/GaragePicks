import SwiftUI
import FirebaseAuth

struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showChangePassword = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    private var userEmail: String {
        Auth.auth().currentUser?.email ?? "No email found"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account Information")) {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(userEmail)
                            .foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("Security")) {
                    DisclosureGroup("Change Password", isExpanded: $showChangePassword) {
                        VStack(spacing: 16) {
                            SecureField("Current Password", text: $currentPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                            
                            SecureField("New Password", text: $newPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                            
                            SecureField("Confirm New Password", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                            
                            Button(action: changePassword) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Text("Update Password")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading || !isValidPasswordForm)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Profile & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var isValidPasswordForm: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 6
    }
    
    private func changePassword() {
        guard isValidPasswordForm else { return }
        
        isLoading = true
        
        // Get current user
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            showError(title: "Error", message: "No user found")
            isLoading = false
            return
        }
        
        // Reauthenticate user before changing password
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        
        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                showError(title: "Authentication Error", message: error.localizedDescription)
                isLoading = false
                return
            }
            
            // Change password
            user.updatePassword(to: newPassword) { error in
                isLoading = false
                
                if let error = error {
                    showError(title: "Password Update Error", message: error.localizedDescription)
                } else {
                    // Success
                    alertTitle = "Success"
                    alertMessage = "Your password has been updated."
                    showAlert = true
                    
                    // Clear form
                    currentPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                    showChangePassword = false
                }
            }
        }
    }
    
    private func showError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    ProfileSettingsView()
} 