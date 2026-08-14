import Foundation
import FirebaseAuth
import AuthenticationServices
import UIKit
import CryptoKit
import Observation

enum AuthError: LocalizedError {
    case missingIDToken
    case cancelled
    case appleSignInFailed

    var errorDescription: String? {
        switch self {
        case .missingIDToken:
            return "Failed to retrieve ID token"
        case .cancelled:
            return "Sign-in was cancelled by the user"
        case .appleSignInFailed:
            return "Apple Sign-In failed"
        }
    }
}

@Observable
class AuthService {
    var currentUserID: String?
    var currentUserName: String?
    var currentUserEmail: String?
    var isAnonymous = true
    var isAuthenticated: Bool { currentUserID != nil }

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private static let emailKey = "authServiceEmail"
    private static let nameKey = "authServiceName"
    private var currentNonce: String?
    private var appleSignInDelegate: AppleSignInDelegate?

    init() {
        setupAuthStateListener()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUserID = user?.uid
            if let user = user {
                self?.currentUserName = user.displayName ?? UserDefaults.standard.string(forKey: Self.nameKey)
                self?.currentUserEmail = user.email ?? UserDefaults.standard.string(forKey: Self.emailKey)
                self?.isAnonymous = user.isAnonymous
            } else {
                self?.currentUserName = nil
                self?.currentUserEmail = nil
                self?.isAnonymous = true
            }
        }
    }

    func signInAnonymously() async throws {
        let result = try await Auth.auth().signInAnonymously()
        currentUserID = result.user.uid
        isAnonymous = true
    }

    func signInWithApple() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            let delegate = AppleSignInDelegate(continuation: continuation)
            appleSignInDelegate = delegate
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }

        guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleIDCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.appleSignInFailed
        }

        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: appleIDCredential.fullName)

        if let anonUser = Auth.auth().currentUser, anonUser.isAnonymous {
            do {
                _ = try await anonUser.link(with: credential)
                currentUserID = anonUser.uid
                currentUserName = appleIDCredential.fullName.flatMap { PersonNameComponentsFormatter().string(from: $0).nilIfEmpty }
                currentUserEmail = appleIDCredential.email
                persistUserData()
                isAnonymous = false
            } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                _ = try await Auth.auth().signIn(with: credential)
                if let firebaseUser = Auth.auth().currentUser {
                    currentUserID = firebaseUser.uid
                    currentUserName = firebaseUser.displayName
                    currentUserEmail = firebaseUser.email
                    persistUserData()
                    isAnonymous = false
                }
            }
        } else {
            _ = try await Auth.auth().signIn(with: credential)
            if let firebaseUser = Auth.auth().currentUser {
                currentUserID = firebaseUser.uid
                currentUserName = firebaseUser.displayName
                currentUserEmail = firebaseUser.email
                persistUserData()
                isAnonymous = false
            }
        }
    }

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
        UserDefaults.standard.removeObject(forKey: Self.emailKey)
        UserDefaults.standard.removeObject(forKey: Self.nameKey)
        try await signInAnonymously()
    }

    func signOut() async throws {
        try Auth.auth().signOut()
        UserDefaults.standard.removeObject(forKey: Self.emailKey)
        UserDefaults.standard.removeObject(forKey: Self.nameKey)
        try await signInAnonymously()
    }

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func persistUserData() {
        if let email = currentUserEmail {
            UserDefaults.standard.set(email, forKey: Self.emailKey)
        }
        if let name = currentUserName {
            UserDefaults.standard.set(name, forKey: Self.nameKey)
        }
    }
}

// MARK: - Apple Sign-In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let continuation: CheckedContinuation<ASAuthorization, Error>

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
