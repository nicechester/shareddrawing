import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit
import Observation

enum AuthError: LocalizedError {
    case missingClientID
    case noPresentingViewController
    case missingIDToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Google Sign-In client ID not found in Firebase configuration"
        case .noPresentingViewController:
            return "Unable to present sign-in sheet"
        case .missingIDToken:
            return "Failed to retrieve ID token from Google Sign-In"
        case .cancelled:
            return "Sign-in was cancelled by the user"
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
                self?.currentUserName = user.displayName
                self?.currentUserEmail = user.email
                // Check if user is anonymous
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

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingClientID
        }

        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let topVC = Self.topViewController() else {
            throw AuthError.noPresentingViewController
        }

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)
        } catch let error as NSError where error.code == GIDSignInError.Code.canceled.rawValue {
            throw AuthError.cancelled
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingIDToken
        }

        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)

        // Try to link to current anonymous user
        if let anonUser = Auth.auth().currentUser, anonUser.isAnonymous {
            do {
                _ = try await anonUser.link(with: credential)
                currentUserID = anonUser.uid
                currentUserName = result.user.profile?.givenName
                currentUserEmail = result.user.profile?.email
                isAnonymous = false
            } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                // Credential already linked elsewhere, sign in normally
                _ = try await Auth.auth().signIn(with: credential)
                if let firebaseUser = Auth.auth().currentUser {
                    currentUserID = firebaseUser.uid
                    currentUserName = firebaseUser.displayName
                    currentUserEmail = firebaseUser.email
                    isAnonymous = false
                }
            }
        } else {
            // No anonymous user or already authenticated, sign in normally
            _ = try await Auth.auth().signIn(with: credential)
            if let firebaseUser = Auth.auth().currentUser {
                currentUserID = firebaseUser.uid
                currentUserName = firebaseUser.displayName
                currentUserEmail = firebaseUser.email
                isAnonymous = false
            }
        }
    }

    func signOut() async throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
        try await signInAnonymously()
    }

    static func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return nil
        }

        var topViewController = windowScene.windows.first?.rootViewController

        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }

        if let navigationController = topViewController as? UINavigationController {
            topViewController = navigationController.visibleViewController
        }

        if let tabBarController = topViewController as? UITabBarController {
            topViewController = tabBarController.selectedViewController
        }

        return topViewController
    }
}
