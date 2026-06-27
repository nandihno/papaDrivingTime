import SwiftUI

struct SettingsView: View {
    @AppStorage("drivingProvider") private var drivingProviderRaw = DrivingProvider.apple.rawValue
    @AppStorage("googleMapsApiKey") private var googleMapsApiKey = ""

    private var provider: DrivingProvider {
        DrivingProvider(rawValue: drivingProviderRaw) ?? .apple
    }

    var body: some View {
        Form {
            Section {
                Picker("Routing Provider", selection: $drivingProviderRaw) {
                    Text("Apple Maps").tag(DrivingProvider.apple.rawValue)
                    Text("Google Maps").tag(DrivingProvider.google.rawValue)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Provider")
            } footer: {
                Text("Apple Maps requires no API key. Google Maps uses the Routes API v2 and requires a key below.")
            }

            if provider == .google {
                Section {
                    SecureField("Google Routes API Key", text: $googleMapsApiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Google Maps API Key")
                } footer: {
                    Text("Required when using Google Maps. Get a key from the Google Cloud Console with the Routes API enabled.")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
