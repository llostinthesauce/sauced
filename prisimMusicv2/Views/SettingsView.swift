import SwiftUI

struct SettingsView: View {
    @Environment(NavidromeClient.self) var client
    @Environment(ThemeStore.self) var themeStore

    @State private var serverURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var pingStatus: String = ""
    @State private var isPinging = false
    @State private var crossfadeDuration: Double = UserDefaults.standard.double(forKey: "crossfade_seconds")
    @State private var cacheSize: String = "Calculating..."

    var body: some View {
        Form {
            // MARK: - Themes
            Section("Appearance") {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        themeStore.selectedTheme = theme
                    } label: {
                        HStack(spacing: 14) {
                            // Color swatch
                            HStack(spacing: 0) {
                                ForEach(Array(theme.swatchColors.enumerated()), id: \.offset) { _, color in
                                    color
                                }
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(.separator, lineWidth: 0.5)
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.rawValue)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(theme.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if themeStore.selectedTheme == theme {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(theme.primaryAccent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // MARK: - Playback
            Section("Playback") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Crossfade")
                        Spacer()
                        Text(crossfadeDuration == 0 ? "Off" : "\(Int(crossfadeDuration))s")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $crossfadeDuration, in: 0...12, step: 1)
                        .onChange(of: crossfadeDuration) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "crossfade_seconds")
                        }
                }
            }
            
            // MARK: - Cache
            Section("Storage") {
                HStack {
                    Text("Image Cache")
                    Spacer()
                    Text(cacheSize)
                        .foregroundStyle(.secondary)
                }
                
                Button(role: .destructive) {
                    ImageCacheManager.shared.clearAll()
                    updateCacheSize()
                } label: {
                    Text("Clear Image Cache")
                }
            }

            // MARK: - Server Connection
            Section("Server Connection") {
                TextField("Server URL (e.g. http://10.0.0.5:4533)", text: $serverURL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                TextField("Username", text: $username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("Password", text: $password)
            }

            Section {
                Button {
                    Task { await saveAndPing() }
                } label: {
                    if isPinging {
                        ProgressView()
                    } else {
                        Text("Test Connection & Save")
                    }
                }
                .disabled(serverURL.isEmpty || username.isEmpty)

                if !pingStatus.isEmpty {
                    Text(pingStatus)
                        .foregroundStyle(pingStatus.contains("Success") ? .green : .red)
                        .font(.caption)
                }
            } footer: {
                Text("Enter your Navidrome admin or user credentials.")
            }

            Section("About") {
                Text("Sauced v1.0")
                Text("A Navidrome Music Player for iOS")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            serverURL = client.baseURL
            username = client.username
            password = client.password
            updateCacheSize()
        }
    }
    
    private func updateCacheSize() {
        let bytes = ImageCacheManager.shared.diskCacheSize
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        cacheSize = formatter.string(fromByteCount: bytes)
    }

    func saveAndPing() async {
        isPinging = true
        pingStatus = "Testing..."

        client.baseURL = serverURL
        client.username = username
        client.password = password

        let success = await client.ping()

        isPinging = false
        if success {
            pingStatus = "Success! Connected to Navidrome."
        } else {
            pingStatus = "Connection Failed. Check URL and credentials."
        }
    }
}

