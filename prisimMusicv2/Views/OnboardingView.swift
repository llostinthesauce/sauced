import SwiftUI

/// Shown on first launch to guide users through server setup.
struct OnboardingView: View {
    @Environment(NavidromeClient.self) var client
    
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isPinging = false
    @State private var pingStatus: String?
    @State private var succeeded = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo / Icon area
                VStack(spacing: 12) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.white)
                        .shadow(color: .blue.opacity(0.5), radius: 20, x: 0, y: 10)
                    
                    Text("Sauced")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Your Navidrome music player")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.bottom, 48)
                
                // Fields
                VStack(spacing: 16) {
                    OnboardingField(
                        icon: "server.rack",
                        placeholder: "Server URL (e.g. http://10.0.0.5:4533)",
                        text: $serverURL,
                        keyboard: .URL
                    )
                    OnboardingField(
                        icon: "person.fill",
                        placeholder: "Username",
                        text: $username
                    )
                    OnboardingField(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $password,
                        isSecure: true
                    )
                }
                .padding(.horizontal, 28)
                
                // Status message
                if let status = pingStatus {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(succeeded ? .green : .red.opacity(0.9))
                        .padding(.top, 12)
                        .transition(.opacity)
                }
                
                Spacer()
                
                // Connect button
                Button {
                    Task { await connect() }
                } label: {
                    ZStack {
                        if isPinging {
                            ProgressView().tint(.white)
                        } else {
                            Text("Connect")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "667eea").opacity(0.4), radius: 16, x: 0, y: 8)
                }
                .disabled(serverURL.isEmpty || username.isEmpty || isPinging)
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .animation(.easeInOut, value: pingStatus)
    }
    
    private func connect() async {
        isPinging = true
        pingStatus = nil
        
        client.baseURL = serverURL
        client.username = username
        client.password = password
        
        let ok = await client.ping()
        
        if ok {
            succeeded = true
            pingStatus = "✓ Connected! Welcome to Sauced."
            UserDefaults.standard.set(true, forKey: "onboarding_complete")
        } else {
            succeeded = false
            pingStatus = "Connection failed — check your URL and credentials."
        }
        
        isPinging = false
    }
}

// MARK: - Field Component

private struct OnboardingField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundStyle(.white)
                    .tint(.white)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(.white)
                    .tint(.white)
            }
        }
        .padding(16)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Color hex helper (local to this file if not already available)
private extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: s).scanHexInt64(&n)
        let r = Double((n >> 16) & 0xff) / 255
        let g = Double((n >> 8) & 0xff) / 255
        let b = Double(n & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}
