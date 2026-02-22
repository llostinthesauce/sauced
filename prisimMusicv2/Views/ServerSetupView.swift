import SwiftUI

struct ServerSetupView: View {
    @Environment(NavidromeClient.self) var client

    @State private var serverURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isPinging = false
    @State private var errorMessage: String = ""

    var body: some View {
        ZStack {
            // Background gradient matching app aesthetic
            LinearGradient(
                colors: [Color.purple.opacity(0.8), Color.indigo.opacity(0.6), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo / Title
                VStack(spacing: 12) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)

                    Text("Prism Music")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Connect to your Navidrome server")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Fields
                VStack(spacing: 14) {
                    SetupField(
                        icon: "server.rack",
                        placeholder: "Server URL (e.g. http://10.0.0.5:4533)",
                        text: $serverURL,
                        keyboardType: .URL
                    )

                    SetupField(
                        icon: "person.fill",
                        placeholder: "Username",
                        text: $username
                    )

                    SetupField(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $password,
                        isSecure: true
                    )
                }
                .padding(.horizontal)

                // Error
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Connect Button
                Button {
                    Task { await connect() }
                } label: {
                    Group {
                        if isPinging {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Connect")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(serverURL.isEmpty || username.isEmpty || isPinging)
                .padding(.horizontal)

                Spacer()
            }
        }
    }

    func connect() async {
        isPinging = true
        errorMessage = ""

        // Stage credentials into client so ping() can use them,
        // but roll back if the ping fails (keeps baseURL empty → stays on setup screen)
        let prevURL = client.baseURL
        let prevUser = client.username
        let prevPass = client.password

        client.baseURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        client.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        client.password = password

        let success = await client.ping()
        isPinging = false

        if !success {
            client.baseURL = prevURL
            client.username = prevUser
            client.password = prevPass
            errorMessage = "Connection failed. Check your URL and credentials."
        }
        // On success: credentials are saved (via didSet), baseURL is non-empty → PrismMusicApp switches view
    }
}

private struct SetupField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 20)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .foregroundStyle(.white)
        }
        .padding()
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}
