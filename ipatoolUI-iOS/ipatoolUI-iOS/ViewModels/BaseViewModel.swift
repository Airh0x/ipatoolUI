import Foundation
import Combine

@MainActor
class BaseViewModel: ObservableObject {
    @Published var statusMessage: String?
    @Published var activeError: APIError?
    @Published var isLoading: Bool = false
    
    let apiService = APIService.shared
    let localizationManager = LocalizationManager.shared
    
    func handleError(_ error: Error) {
        if let apiError = error as? APIError {
            activeError = apiError
        } else {
            activeError = .networkError(error)
        }
    }
    
    func resetLoadingState() {
        isLoading = false
        statusMessage = nil
    }
    
    func clearError() {
        activeError = nil
    }
    
    /// Runs an async operation with loading state and error handling. Use setLoading/unsetLoading for custom flags (e.g. isSearching).
    func runAsync(
        setLoading: (() -> Void)? = nil,
        unsetLoading: (() -> Void)? = nil,
        operation: @escaping () async throws -> Void
    ) {
        setLoading?() ?? { isLoading = true }()
        clearError()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await operation()
            } catch {
                self.handleError(error)
            }
            unsetLoading?() ?? { self.isLoading = false }()
        }
    }
}
