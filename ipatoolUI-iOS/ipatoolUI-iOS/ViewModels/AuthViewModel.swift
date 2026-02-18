import Foundation
import Combine

@MainActor
final class AuthViewModel: BaseViewModel {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var authCode: String = ""
    @Published var isWorking: Bool = false
    @Published var countryCode: String? = nil
    
    private var hasBootstrapped = false
    
    override init() {
        super.init()
        statusMessage = localizationManager.strings.unauthenticated
    }
    
    func login() {
        guard ValidationHelpers.isValidEmailAndPassword(email: email, password: password) else {
            activeError = .serverError(400, localizationManager.strings.emailPasswordRequired)
            return
        }
        runAsync(
            setLoading: { [weak self] in
                self?.isWorking = true
                self?.isLoading = true
            },
            unsetLoading: { [weak self] in
                self?.isWorking = false
                self?.isLoading = false
            },
            operation: { [weak self] in
                guard let self else { return }
                let response = try await apiService.login(
                    email: self.email,
                    password: self.password,
                    authCode: self.authCode.isEmpty ? nil : self.authCode
                )
                if response.success {
                    let accountEmail = response.email ?? self.email
                    self.statusMessage = "\(accountEmail) \(self.localizationManager.strings.signedInAs)"
                    self.email = accountEmail
                    self.password = ""
                    self.authCode = ""
                    self.countryCode = response.countryCode
                    await self.fetchInfo(showProgress: false)
                } else {
                    self.activeError = .serverError(401, self.localizationManager.strings.loginFailed)
                }
            }
        )
    }
    
    func fetchInfo(showProgress: Bool = true) async {
        if showProgress {
            isWorking = true
            isLoading = true
        }
        clearError()
        
        do {
            let response = try await apiService.getAuthInfo()
            let accountEmail = response.email ?? localizationManager.strings.unknown
            statusMessage = "\(localizationManager.strings.activeSession) \(accountEmail)"
            if accountEmail != localizationManager.strings.unknown {
                email = accountEmail
            }
            countryCode = response.countryCode
        } catch {
            handleError(error)
        }
        
        if showProgress {
            isWorking = false
            isLoading = false
        }
    }
    
    func revoke() {
        runAsync(
            setLoading: { [weak self] in
                self?.isWorking = true
                self?.isLoading = true
            },
            unsetLoading: { [weak self] in
                self?.isWorking = false
                self?.isLoading = false
            },
            operation: { [weak self] in
                guard let self else { return }
                try await apiService.revokeAuth()
                self.statusMessage = self.localizationManager.strings.authDeleted
                self.email = ""
                self.password = ""
                self.authCode = ""
                self.countryCode = nil
            }
        )
    }
    
    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        Task {
            await fetchInfo(showProgress: false)
        }
    }
}
