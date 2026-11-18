// OnboardingAccountViewController.swift owns native Apple and browser-based Google authentication.
import AuthenticationServices
import CryptoKit
import SwiftUI

@objc final class OnboardingAccountViewController: LoginViewController {
    private var account = OnboardingAccountModel()
    private var pendingAppleRevocationNotice = false

    override func loadView() {
        let host = UIHostingController(rootView: OnboardingAccountView(model: account))
        view = UIView()
        view.backgroundColor = .systemGroupedBackground
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
        account.controller = self
    }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {
        account.lastUsed = UserDefaults.standard.string(forKey: "last_auth_method")
        if !account.needsUsername && !account.needsLink {
            account.signup = OnboardingAccountModel.allowsAccountCreation && account.lastUsed == nil
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        if pendingAppleRevocationNotice { showAppleRevocationNoticeWhenVisible() }
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews() }

    func showAppleRevocationNoticeWhenVisible() {
        guard viewIfLoaded?.window != nil else {
            pendingAppleRevocationNotice = true
            return
        }
        pendingAppleRevocationNotice = false
        let alert = UIAlertController(title: NBLocalization.text("Finish disconnecting Apple"),
                                      message: NBLocalization.text("Your NewsBlur account has been deleted. Remove NewsBlur from Sign in with Apple in your Apple Account settings to finish disconnecting it."),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NBLocalization.text("View instructions"), style: .default) { _ in
            UIApplication.shared.open(URL(string: "https://support.apple.com/en-us/102571")!)
        })
        alert.addAction(UIAlertAction(title: NBLocalization.text("Done"), style: .cancel))
        present(alert, animated: true)
    }
}

@MainActor final class OnboardingAccountModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding, ASWebAuthenticationPresentationContextProviding {
    // OnboardingAccountViewController.swift: NewsNative only signs in to existing accounts for now. Turning this on
    // restores the email sign-up mode, its toggle, and new accounts from Apple or Google sign-in.
    static let allowsAccountCreation = false
    // OnboardingAccountViewController.swift: Apple and Google sign-in are set aside. The server only accepts Apple
    // identity tokens for its own app IDs, and Google's consent screen names the server's product, so NewsNative
    // signs in with a username or email and password until those flows are set up for this app.
    static let allowsSocialSignIn = false

    @Published var signup = OnboardingAccountModel.allowsAccountCreation && UserDefaults.standard.string(forKey: "last_auth_method") == nil
    @Published var email = ""
    // OnboardingAccountViewController.swift signs in to any NewsBlur-compatible server; blank uses the default.
    @Published var server = UserDefaults.standard.string(forKey: "custom_domain") ?? ""
    @Published var username = ""
    @Published var password = ""
    @Published var lastUsed = UserDefaults.standard.string(forKey: "last_auth_method")
    @Published var busy = false
    @Published var message: String?
    @Published var needsUsername = false
    @Published var needsLink = false
    @Published private(set) var canChooseUsername = false
    weak var controller: UIViewController?
    private var provider = ""
    private var verifier = ""
    private var state = ""
    private var ticket = ""
    private var webSession: ASWebAuthenticationSession?
    private var appleController: ASAuthorizationController?
    private var automaticAppleUsername: String?
    private let authenticationFinished: (String, Bool) -> Void
    var deletionSession: AccountDeletionSession?
    var onReauthenticated: ((String) -> Void)?

    init(authenticationFinished: @escaping (String, Bool) -> Void = { method, _ in
        UserDefaults.standard.set(method, forKey: "last_auth_method")
        NewsBlurAppDelegate.shared()?.finishAuthentication()
    }) {
        self.authenticationFinished = authenticationFinished
        super.init()
    }

    // OnboardingAccountViewController.swift: the server address the form points at, or nil while it is invalid.
    var serverURL: String? {
        let trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return NewsBlurAppDelegate.defaultServerURL() }
        return NewsBlurAppDelegate.normalizedServerURL(trimmed)
    }

    func emailSignIn() {
        guard !busy else { return }
        busy = true
        message = nil
        Task {
            defer { busy = false }
            do {
                if !(needsUsername || needsLink) {
                    guard serverURL != nil else { throw OnboardingAPI.error("Invalid server address.") }
                    NewsBlurAppDelegate.shared()?.applyCustomServer(server)
                }
                if needsUsername || needsLink { try await complete() }
                else {
                    guard !username.isEmpty, !password.isEmpty, !signup || !email.isEmpty else {
                        throw OnboardingAPI.error("Fill in the fields to continue.")
                    }
                    _ = try await OnboardingAPI.request(signup ? "/api/signup" : "/api/login", body: [
                        "username": username, "password": password, "email": email, "api": "1"
                    ])
                    finish(method: "email", created: signup)
                }
            } catch { message = error.localizedDescription }
        }
    }

    func social(_ name: String) {
        guard !busy, Self.allowsSocialSignIn || deletionSession != nil else { return }
        busy = true
        message = nil
        Task {
            do {
                let result = try await prepareSocial(name)
                if name == "apple" {
                    let request = ASAuthorizationAppleIDProvider().createRequest()
                    request.requestedScopes = [.email]
                    request.nonce = result["nonce"] as? String
                    let authorization = ASAuthorizationController(authorizationRequests: [request])
                    authorization.delegate = self
                    authorization.presentationContextProvider = self
                    appleController = authorization
                    authorization.performRequests()
                } else {
                    guard let address = result["url"] as? String, let url = URL(string: address) else { throw OnboardingAPI.error("Unable to start Google sign-in.") }
                    let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "newsblur-auth") { [weak self] url, error in
                        Task { @MainActor in
                            guard let self else { return }
                            defer { self.busy = false; self.webSession = nil }
                            guard let url else {
                                if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin { self.message = error?.localizedDescription }
                                return
                            }
                            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                            guard url.scheme == "newsblur-auth", url.host == "complete",
                                  let ticket = items.first(where: { $0.name == "ticket" })?.value else {
                                self.message = items.first(where: { $0.name == "error" })?.value ?? "Google sign-in failed. Please try again."
                                return
                            }
                            self.ticket = ticket
                            do { try await self.complete() } catch { self.message = error.localizedDescription }
                        }
                    }
                    session.presentationContextProvider = self
                    session.prefersEphemeralWebBrowserSession = deletionSession != nil
                    webSession = session
                    if !session.start() { throw OnboardingAPI.error("Unable to open Google sign-in. Please try again.") }
                }
            } catch { message = error.localizedDescription; busy = false }
        }
    }

    func prepareSocial(_ name: String) async throws -> [String: Any] {
        try deletionSession?.validate()
        provider = name
        needsLink = false
        needsUsername = false
        canChooseUsername = false
        automaticAppleUsername = nil
        if name == "apple", deletionSession == nil {
            // OnboardingAccountViewController.swift never reuses a draft password signup's identity fields.
            username = ""
            password = ""
        }
        // OnboardingAccountViewController.swift binds the callback ticket to this app session.
        verifier = UUID().uuidString + UUID().uuidString
        let challenge = SHA256.hash(data: Data(verifier.utf8)).map { String(format: "%02x", $0) }.joined()
        var body = ["provider": name, "challenge": challenge]
        if deletionSession != nil { body["purpose"] = "delete_account" }
        let result = try await OnboardingAPI.request("/api/social/start", body: body)
        try deletionSession?.validate()
        guard let state = result["state"] as? String else { throw OnboardingAPI.error("Unable to start sign-in.") }
        self.state = state
        return result
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            defer { busy = false; appleController = nil }
            do {
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    throw OnboardingAPI.error("Apple did not return an identity token.")
                }
                ticket = try await exchangeAppleCredential(identityToken: credential.identityToken, authorizationCode: credential.authorizationCode)
                try await complete()
            } catch { message = error.localizedDescription }
        }
    }

    func exchangeAppleCredential(identityToken: Data?, authorizationCode: Data?) async throws -> String {
        try deletionSession?.validate()
        guard let identityToken, let token = String(data: identityToken, encoding: .utf8) else {
            throw OnboardingAPI.error("Apple did not return an identity token.")
        }
        var body = ["state": state, "id_token": token]
        // OnboardingAccountViewController.swift supplies Apple's one-time code for revocation only during account deletion.
        if deletionSession != nil, let authorizationCode,
           let code = String(data: authorizationCode, encoding: .utf8), !code.isEmpty {
            body["authorization_code"] = code
        }
        let result = try await OnboardingAPI.request("/api/social/apple", body: body)
        try deletionSession?.validate()
        guard let ticket = result["ticket"] as? String else { throw OnboardingAPI.error("Apple sign-in failed.") }
        return ticket
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        busy = false
        appleController = nil
        if (error as? ASAuthorizationError)?.code != .canceled { message = error.localizedDescription }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { self.controller?.view.window ?? ASPresentationAnchor() }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { controller?.view.window ?? ASPresentationAnchor() }

    func complete(ticket: String) async throws {
        self.ticket = ticket
        try await complete()
    }

    func connectExistingAccount() {
        guard needsUsername, !busy else { return }
        needsUsername = false
        needsLink = true
        canChooseUsername = true
        password = ""
        message = nil
    }

    func createNewAccountInstead() {
        guard needsLink, canChooseUsername, !busy else { return }
        needsLink = false
        needsUsername = true
        canChooseUsername = false
        username = ""
        password = ""
        message = nil
    }

    private func complete() async throws {
        try deletionSession?.validate()
        let automaticAppleSignup = Self.allowsAccountCreation && provider == "apple" && deletionSession == nil && !needsLink
        var result: [String: Any] = [:]
        for attempt in 0..<3 {
            if automaticAppleSignup && automaticAppleUsername == nil {
                // OnboardingAccountViewController.swift supplies an opaque username; social_auth.py uses Apple's verified email.
                let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(22)
                automaticAppleUsername = "reader_" + String(suffix)
            }
            var body = ["ticket": ticket, "verifier": verifier,
                        "username": automaticAppleSignup ? (automaticAppleUsername ?? "") : (needsUsername || needsLink ? username : ""),
                        "password": needsLink ? password : ""]
            if needsLink { body["action"] = "link" }
            result = try await OnboardingAPI.request("/api/social/complete", body: body)
            if automaticAppleSignup && result["link_required"] as? Bool == true
                && result["can_choose_username"] as? Bool == true {
                // OnboardingAccountViewController.swift retries only random-name collisions, never same-email account linking.
                guard attempt < 2, let replacementTicket = result["ticket"] as? String, !replacementTicket.isEmpty else {
                    throw OnboardingAPI.error(NBLocalization.text("The request failed. Please try again."))
                }
                ticket = replacementTicket
                automaticAppleUsername = nil
                continue
            }
            if automaticAppleSignup && result["username_required"] as? Bool == true {
                throw OnboardingAPI.error(NBLocalization.text("The request failed. Please try again."))
            }
            break
        }
        if let deletionSession {
            try deletionSession.validate()
            guard let token = result["delete_token"] as? String, !token.isEmpty else {
                throw OnboardingAPI.error("Unable to verify your account. Please try again.")
            }
            self.ticket = ""
            onReauthenticated?(token)
            return
        }
        if !Self.allowsAccountCreation && result["username_required"] as? Bool == true {
            // OnboardingAccountViewController.swift: a username request means the server would create a new account.
            cancelContinuation()
            message = NBLocalization.text("No account uses this sign-in. Sign in with an existing account.")
            return
        }
        if result["link_required"] as? Bool == true || result["username_required"] as? Bool == true {
            ticket = result["ticket"] as? String ?? ""
            needsLink = result["link_required"] as? Bool == true
            needsUsername = result["username_required"] as? Bool == true
            canChooseUsername = needsLink && (result["can_choose_username"] as? Bool == true)
            message = result["message"] as? String
            password = ""
            return
        }
        finish(method: provider, created: result["created"] as? Bool == true)
    }

    func cancelAuthentication() {
        deletionSession?.cancelled = true
        webSession?.cancel()
        webSession = nil
        appleController = nil
        busy = false
        cancelContinuation()
    }

    func cancelContinuation() {
        needsLink = false
        needsUsername = false
        canChooseUsername = false
        ticket = ""
        automaticAppleUsername = nil
        password = ""
        message = nil
    }

    private func finish(method: String, created: Bool) {
        lastUsed = method
        password = ""
        cancelContinuation()
        authenticationFinished(method, created)
        controller?.dismiss(animated: true)
    }
}

// OnboardingAccountViewController.swift binds deletion to the existing authenticated browsing session.
@MainActor final class AccountDeletionSession {
    let username = NewsBlurAppDelegate.shared()?.activeUsername
    let server = NewsBlurAppDelegate.shared()?.url
    private let generation = NewsBlurAppDelegate.shared()?.feedsViewController.feedListAccountGeneration
    var cancelled = false

    func validate() throws {
        let app = NewsBlurAppDelegate.shared()
        guard !cancelled, let username, !username.isEmpty, username == app?.activeUsername,
              server == app?.url, generation == app?.feedsViewController.feedListAccountGeneration else {
            throw OnboardingAPI.error("Your account session changed. Close this dialog and try again.")
        }
    }
}

@MainActor final class AccountDeletionModel: ObservableObject {
    @Published var providers: [String] = []
    @Published var loading = true
    @Published var deleting = false
    @Published var confirmation = ""
    @Published var message: String?
    @Published private(set) var isVerified = false
    @Published private(set) var useLegacyDeletion = false
    let authentication = OnboardingAccountModel()
    let session = AccountDeletionSession()
    private var deleteToken: String?
    private let onDeleted: (Bool) -> Void
    var onLegacy: (() -> Void)?

    init(onDeleted: @escaping (Bool) -> Void) {
        self.onDeleted = onDeleted
        authentication.deletionSession = session
        authentication.onReauthenticated = { [weak self] token in
            self?.deleteToken = token
            self?.isVerified = true
            self?.message = nil
        }
    }

    func load() async {
        loading = true
        message = nil
        defer { loading = false }
        do {
            try session.validate()
            guard let server = session.server, let url = URL(string: server + "/api/social/account") else {
                throw OnboardingAPI.error("Invalid server address.")
            }
            let (data, response) = try await OnboardingAPI.session.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
            try session.validate()
            guard let http = response as? HTTPURLResponse else { throw OnboardingAPI.error("Unable to load your account. Please try again.") }
            if http.statusCode == 404 || ((200...299).contains(http.statusCode) && http.mimeType == "text/html") {
                useLegacyDeletion = true
            } else {
                guard (200...299).contains(http.statusCode),
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      json["code"] as? Int == 1, let linked = json["providers"] as? [String] else {
                    throw OnboardingAPI.error("Unable to load your account. Please try again.")
                }
                providers = linked.contains("apple") ? ["apple"] : linked.filter { $0 == "google" }
                useLegacyDeletion = providers.isEmpty
            }
            if useLegacyDeletion { onLegacy?() }
        } catch { message = error.localizedDescription }
    }

    func deleteAccount() async {
        guard !deleting, isVerified, let deleteToken, confirmation == "Delete" else { return }
        deleting = true
        message = nil
        defer { deleting = false }
        do {
            try session.validate()
            let result = try await OnboardingAPI.request("/api/social/delete_account", body: ["delete_token": deleteToken, "confirm": "Delete"])
            try session.validate()
            self.deleteToken = nil
            isVerified = false
            onDeleted(result["apple_revocation_required"] as? Bool == true)
        } catch {
            self.deleteToken = nil
            isVerified = false
            confirmation = ""
            message = error.localizedDescription
        }
    }

    func cancel() {
        session.cancelled = true
        deleteToken = nil
        isVerified = false
        authentication.cancelAuthentication()
    }
}

@objc final class AccountDeletionController: UIViewController {
    private(set) var model: AccountDeletionModel!

    @objc(presentFromController:) static func present(from controller: UIViewController) {
        let deletion = AccountDeletionController()
        deletion.modalPresentationStyle = .formSheet
        deletion.preferredContentSize = CGSize(width: 520, height: 560)
        deletion.isModalInPresentation = true
        controller.present(deletion, animated: true)
    }

    override func loadView() {
        model = AccountDeletionModel { [weak self] needsAppleRevocation in
            guard let self else { return }
            self.dismiss(animated: true) {
                guard (try? self.model.session.validate()) != nil, let app = NewsBlurAppDelegate.shared() else { return }
                // OnboardingAccountViewController.swift invalidates queued account work before returning to login after deletion.
                app.cancelOfflineQueue()
                app.feedsViewController.resetForAccountChange()
                app.feedDetailViewController.resetForAccountChange()
                app.activeUsername = nil
                app.activeStory = nil
                UserDefaults.standard.removeObject(forKey: "active_username")
                app.showLogin()
                if needsAppleRevocation {
                    (app.loginViewController as? OnboardingAccountViewController)?.showAppleRevocationNoticeWhenVisible()
                }
            }
        }
        model.onLegacy = { [weak self] in
            guard let self, let server = self.model.session.server else { return }
            self.dismiss(animated: true) {
                guard (try? self.model.session.validate()) != nil, let url = URL(string: server + "/profile/delete_account") else { return }
                NewsBlurAppDelegate.shared()?.show(inAppBrowser: url, withCustomTitle: "Delete Account", fromSender: nil)
            }
        }
        model.authentication.controller = self
        let host = UIHostingController(rootView: AccountDeletionView(model: model, cancel: { [weak self] in
            self?.model.cancel()
            self?.dismiss(animated: true)
        }))
        view = UIView()
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
    }
}

private struct AccountDeletionView: View {
    @ObservedObject var model: AccountDeletionModel
    @ObservedObject var authentication: OnboardingAccountModel
    let cancel: () -> Void

    init(model: AccountDeletionModel, cancel: @escaping () -> Void) {
        self.model = model
        self.authentication = model.authentication
        self.cancel = cancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(NBLocalization.text("Delete account")).font(.title2.weight(.semibold))
                Spacer()
                Button(NBLocalization.text("Cancel"), action: cancel).disabled(model.deleting)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: model.isVerified ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.minus")
                        .font(.system(size: 42, weight: .light)).foregroundStyle(DiscoverColors.textSecondary).accessibilityHidden(true)
                    Text(model.isVerified ? NBLocalization.text("Your identity is verified") : NBLocalization.text("Verify your identity first"))
                        .font(.title3.weight(.semibold))
                    Text(NBLocalization.text("Deleting your account permanently removes your feeds, saved stories, and account data. This cannot be undone."))
                        .foregroundStyle(DiscoverColors.textSecondary)
                    if model.loading { ProgressView("Loading account…").frame(maxWidth: .infinity).padding() }
                    else if model.isVerified {
                        Text(String(format: NBLocalization.text("Type %1$@ to permanently delete %2$@."),
                                    "Delete", model.session.username ?? NBLocalization.text("your account"))).font(.subheadline)
                        TextField(text: $model.confirmation) { Text(verbatim: "Delete") }
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .padding(14).background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("account-deletion.confirmation")
                        Button(role: .destructive) { Task { await model.deleteAccount() } } label: {
                            Text(NBLocalization.text("Permanently delete account")).fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.borderedProminent).tint(.red)
                            .disabled(model.confirmation != "Delete" || model.deleting)
                            .accessibilityIdentifier("account-deletion.submit")
                        if model.deleting { ProgressView("Deleting account…") }
                    } else {
                        ForEach(model.providers, id: \.self) { provider in
                            Button { authentication.social(provider) } label: {
                                HStack(spacing: 12) {
                                    if provider == "apple" { Image(systemName: "apple.logo").font(.title2) }
                                    else { Image("google-signin").resizable().frame(width: 22, height: 22) }
                                    Text(provider == "apple" ? NBLocalization.text("Verify with Apple") : NBLocalization.text("Verify with Google")).fontWeight(.semibold)
                                    Spacer()
                                }.padding(16).background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).disabled(authentication.busy)
                        }
                        if authentication.busy { ProgressView("Verifying your identity…") }
                        if model.providers.isEmpty && model.message != nil {
                            Button(NBLocalization.text("Try again")) { Task { await model.load() } }
                        }
                    }
                    if let message = model.message ?? authentication.message {
                        Text(message).font(.subheadline).foregroundStyle(.red).accessibilityIdentifier("account-deletion.error")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(28).foregroundStyle(DiscoverColors.textPrimary)
            .background(DiscoverColors.background.ignoresSafeArea())
            .task { await model.load() }
    }
}

struct OnboardingAccountView: View {
    @State private var language = NBLocalization.language
    @ObservedObject var model: OnboardingAccountModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingProjectInformation = false
    private var continuation: Bool { model.needsUsername || model.needsLink }
    // OnboardingAccountViewController.swift: native grouped styling that follows the app's Auto, Light or Dark
    // theme and matches LaunchScreen.xib's system grouped background.
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    Picker(NBLocalization.text("Language"), selection: $language) {
                        Text(NBLocalization.automaticLabel).tag("auto")
                        ForEach(NBLocalization.languages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: language) { _, value in NBLocalization.apply(value, pending: true) }
                    .disabled(model.busy)
                    VStack(spacing: 12) {
                        Image(uiImage: UIImage(named: "logo_512.png") ?? UIImage(systemName: "newspaper")!)
                            .resizable().scaledToFit().frame(width: 112, height: 112)
                            .accessibilityHidden(true)
                        Text(verbatim: "NewsNative")
                            .font(.largeTitle.bold())
                    }.padding(.top, 12)
                    VStack(alignment: .leading, spacing: 14) {
                        Text(continuation ? (model.needsLink ? NBLocalization.text("Connect your account") : NBLocalization.text("Choose your username")) : (model.signup ? NBLocalization.text("Create an account") : NBLocalization.text("Welcome back")))
                            .font(.title2.bold())
                        if !continuation && OnboardingAccountModel.allowsSocialSignIn {
                            VStack(alignment: .trailing, spacing: 6) {
                                SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: { _ in })
                                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black).frame(height: 50)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                                    .overlay { Button { model.social("apple") } label: { Color.clear.contentShape(Rectangle()) }.accessibilityLabel(NBLocalization.text("Sign in with Apple")) }
                                if model.lastUsed == "apple" { badge }
                            }
                            VStack(alignment: .trailing, spacing: 6) {
                                Button { model.social("google") } label: {
                                    HStack(spacing: 12) { Image("google-signin").resizable().frame(width: 20, height: 20); Text(NBLocalization.text("Sign in with Google")).font(.system(size: 17, weight: .medium)) }.frame(maxWidth: .infinity).frame(height: 50)
                                        .foregroundStyle(.primary).background(Color(.tertiarySystemFill)).clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                if model.lastUsed == "google" { badge }
                            }
                            HStack { Rectangle().frame(height: 0.5); Text(NBLocalization.text("or")).font(.caption); Rectangle().frame(height: 0.5) }.foregroundStyle(.secondary)
                        }
                        if !continuation {
                            field(NBLocalization.text("Server URL"), text: $model.server)
                                .keyboardType(.URL).textContentType(.URL)
                                .accessibilityIdentifier("onboarding.server")
                        }
                        if model.signup && !continuation {
                            field("Email", text: $model.email).keyboardType(.emailAddress).textContentType(.emailAddress)
                        }
                        if model.needsLink {
                            Text(NBLocalization.text("Enter your existing NewsBlur username or email and NewsBlur password."))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        field(model.needsUsername || (model.signup && !continuation) ? "Username" : "Username or email", text: $model.username).textContentType(.username)
                        if !model.needsUsername {
                            SecureField(model.needsLink ? "NewsBlur password" : "Password", text: $model.password,
                                        prompt: Text(model.needsLink ? NBLocalization.text("NewsBlur password") : NBLocalization.text("Password")))
                                .textContentType(model.signup && !continuation ? .newPassword : .password)
                                .padding(14).background(Color(.tertiarySystemFill)).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        if !continuation && model.lastUsed == "email" { HStack { Spacer(); badge } }
                        if let message = model.message {
                            Text(message).font(.subheadline).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                        }
                        Button { model.emailSignIn() } label: {
                            Text(continuation ? NBLocalization.text("Continue") : model.signup ? NBLocalization.text("Create account") : NBLocalization.text("Sign in"))
                                .font(.headline).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        if model.busy { ProgressView("Signing in…").frame(maxWidth: .infinity) }
                        if model.needsUsername {
                            Button(NBLocalization.text("Connect an existing account")) { model.connectExistingAccount() }
                                .accessibilityIdentifier("onboarding.connect-existing-account")
                        }
                        if model.needsLink && model.canChooseUsername {
                            Button(NBLocalization.text("Create a new account instead")) { model.createNewAccountInstead() }
                                .accessibilityIdentifier("onboarding.create-new-account")
                        }
                        if continuation { Button(NBLocalization.text("Use another sign-in method")) { model.cancelContinuation() } }
                        HStack {
                            // OnboardingAccountViewController.swift sends password resets to the server typed above.
                            if model.needsLink || (!continuation && !model.signup),
                               let server = model.serverURL, let resetURL = URL(string: server + "/profile/forgot_password") {
                                Link(NBLocalization.text("Forgot Password"), destination: resetURL)
                            }
                            Spacer()
                            Button(NBLocalization.text("More Information")) { showingProjectInformation = true }
                                .accessibilityIdentifier("onboarding.more-information")
                        }.font(.subheadline)
                    }.padding(20)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                        .disabled(model.busy)
                    if !continuation && OnboardingAccountModel.allowsAccountCreation {
                        Button(model.signup ? NBLocalization.text("Already have an account? Sign in") : NBLocalization.text("New to NewsBlur? Create an account")) {
                            model.signup.toggle(); model.message = nil
                        }.disabled(model.busy)
                    }
                }.padding(24).frame(maxWidth: 520).frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }.background(Color(.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showingProjectInformation) { ProjectInformationView() }
    }
    private var badge: some View { Text(NBLocalization.text("Last used")).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 3).background(Color(.tertiarySystemFill)).clipShape(Capsule()) }
    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text, prompt: Text(title)).textInputAutocapitalization(.never).autocorrectionDisabled()
            .padding(14).background(Color(.tertiarySystemFill)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// OnboardingAccountViewController.swift explains NewsNative's relationship to NewsBlur and carries the copyright
// and license notices from clients/ios/LICENSE.md, which NewsBlur's MIT License requires in copies of the software.
struct ProjectInformationView: View {
    @Environment(\.dismiss) private var dismiss

    static let license = """
        The MIT License

        Copyright (c) 2026 Mike Waters
        Copyright (c) 2009 Samuel Clay, NewsBlur <samuel@newsblur.com>.

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated \
        documentation files (the "Software"), to deal in the Software without restriction, including without limitation \
        the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and \
        to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions \
        of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED \
        TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL \
        THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF \
        CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER \
        DEALINGS IN THE SOFTWARE.
        """

    // OnboardingAccountViewController.swift lists the bundled libraries in Other Sources/ with their copyright holders.
    static let components: [(name: String, notice: String)] = [
        ("AFNetworking", "Copyright (c) 2011–2016 Alamofire Software Foundation. MIT License."),
        ("ARChromeActivity", "Copyright (c) 2012 Alex Robinson. MIT License."),
        ("ABTableViewCell", "Copyright (c) 2008 Loren Brichter. MIT License."),
        ("FMDB", "Copyright (c) 2008–2014 Flying Meat Inc. MIT License."),
        ("Google Toolbox for Mac (NSString+HTML)", "Copyright 2006–2008 Google Inc. Apache License 2.0."),
        ("JNWThrottledBlock", "Copyright (c) Jonathan Willing. MIT License."),
        ("MBProgressHUD", "Copyright (c) 2009–2016 Matej Bukovinski. MIT License."),
        ("MCSwipeTableViewCell", "Copyright (c) 2013 Mad Castle. MIT License."),
        ("NSString+HTML", "Copyright (c) 2010 Michael Waterfall. MIT License."),
        ("1Password App Extension", "Copyright (c) 2014–2020 AgileBits Inc. MIT License."),
        ("PINCache", "Copyright (c) Pinterest, Inc. Apache License 2.0."),
        ("Reachability", "Copyright (c) 2011 Tony Million. BSD License."),
        ("SAConfettiView", "Copyright (c) Sudeep Agarwal. MIT License."),
        ("SBJson", "Copyright (c) 2009–2011 Stig Brautaset. BSD License."),
        ("SloppySwiper", "Copyright (c) Arkadiusz Holko. MIT License."),
        ("THCircularProgressView", "Copyright (c) 2013 Tiago Henriques. MIT License."),
        ("TUSafariActivity", "Copyright (c) 2012 ThinkUltimate. BSD License."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section(NBLocalization.text("An independent project"),
                            NBLocalization.text("NewsNative is an independent app made by Mike Waters. It is not affiliated with, endorsed, or supported by NewsBlur, Inc. or Samuel Clay."))
                    section(NBLocalization.text("Derived from NewsBlur"),
                            NBLocalization.text("NewsNative is built from the open-source NewsBlur iOS app (github.com/samuelclay/NewsBlur), which Samuel Clay publishes under the MIT License. It has been modified to use native iOS styling and design."))
                    section(NBLocalization.text("Compatible with NewsBlur"),
                            NBLocalization.text("Sign in with an existing account on a NewsBlur server, either newsblur.com or a self-hosted installation. Your account, subscriptions and stories are stored and served by the server you choose. NewsNative does not operate a server of its own, and support for your account comes from that server's operator."))
                    section(NBLocalization.text("Name and icon"),
                            NBLocalization.text("The NewsNative name, app icon and logo are © 2026 Mike Waters, all rights reserved. They are not covered by the MIT License, so modified versions of this app must use a different name and icon."))
                    section(NBLocalization.text("Trademarks"),
                            NBLocalization.text("NewsBlur is the name of a service and app by NewsBlur, Inc. It appears in NewsNative only to describe compatibility."))
                    section(NBLocalization.text("Copyright"),
                            "NewsNative © 2026 Mike Waters.\nNewsBlur © 2009 Samuel Clay, NewsBlur.")
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NBLocalization.text("License")).font(.headline)
                        Text(NBLocalization.text("NewsNative's source code is released under the MIT License, the same license as the NewsBlur code it is built from."))
                            .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: Self.license)
                            .font(.footnote.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NBLocalization.text("Open-source components")).font(.headline)
                        ForEach(Self.components, id: \.name) { component in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: component.name).font(.subheadline.weight(.semibold))
                                Text(verbatim: component.notice).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }.padding(20).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(NBLocalization.text("About NewsNative"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NBLocalization.text("Done")) { dismiss() }
                }
            }
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
