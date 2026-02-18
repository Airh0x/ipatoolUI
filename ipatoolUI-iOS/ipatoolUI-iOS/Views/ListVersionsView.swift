import SwiftUI

struct ListVersionsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ListVersionsViewModel
    
    init(viewModel: ListVersionsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        Form {
            Section {
                TextField(appState.localizationManager.strings.appID, text: $viewModel.appIDString)
                
                TextField(appState.localizationManager.strings.bundleID, text: $viewModel.bundleID)
                    .autocorrectionDisabled()
            } header: {
                Text(appState.localizationManager.strings.appInfo)
            } footer: {
                Text(appState.localizationManager.strings.appIDOrBundleIDRequired)
            }
            
            Section {
                Button(action: fetchVersions) {
                    HStack {
                        if viewModel.isFetching {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(appState.localizationManager.strings.fetchVersions)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isFetching || !validateInput())
            }
            
            if let status = viewModel.statusMessage {
                Section {
                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(appState.localizationManager.strings.status)
                }
            }
            
            if let error = viewModel.activeError {
                Section {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                } header: {
                    Text(appState.localizationManager.strings.error)
                }
            }
            
            if !viewModel.versions.isEmpty {
                Section {
                    ForEach(viewModel.versions, id: \.self) { version in
                        Text(version)
                            .font(.body)
                            .monospaced()
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = version
                                }) {
                                    Label(appState.localizationManager.strings.copy, systemImage: "doc.on.doc")
                                }
                                
                                Button(action: {
                                    downloadVersion(version)
                                }) {
                                    Label(appState.localizationManager.strings.download, systemImage: "arrow.down.circle")
                                }
                            }
                    }
                } header: {
                    Text(appState.localizationManager.strings.versionList)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func fetchVersions() {
        viewModel.fetchVersions()
    }
    
    private func validateInput() -> Bool {
        ValidationHelpers.isValidAppIDOrBundleID(appID: viewModel.appIDString, bundleID: viewModel.bundleID)
    }
    
    /// Starts download for the selected version.
    private func downloadVersion(_ version: String) {
        let downloadViewModel = appState.downloadViewModel
        
        // Set current app ID or bundle ID
        if let _ = Int64(viewModel.appIDString), !viewModel.appIDString.isEmpty {
            downloadViewModel.appIDString = viewModel.appIDString
            downloadViewModel.bundleIdentifier = ""
        } else if !viewModel.bundleID.trimmingCharacters(in: .whitespaces).isEmpty {
            downloadViewModel.appIDString = ""
            downloadViewModel.bundleIdentifier = viewModel.bundleID
        } else {
            // No app info set; bail
            return
        }
        
        // Set selected version
        downloadViewModel.externalVersionID = version
        
        // Start download
        downloadViewModel.download()
        
        // Switch to download screen
        appState.selectedFeature = .download
    }
}

struct ListVersionsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ListVersionsView(viewModel: ListVersionsViewModel())
        }
    }
}
