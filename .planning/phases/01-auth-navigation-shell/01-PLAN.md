---
phase: 01-auth-navigation-shell
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Circles/Secrets.plist
  - Circles/Services/SupabaseService.swift
  - Circles/Auth/AuthManager.swift
  - Circles/Auth/AuthView.swift
  - Circles/Navigation/MainTabView.swift
  - Circles/Home/HomeView.swift
  - Circles/Community/CommunityView.swift
  - Circles/Profile/ProfileView.swift
  - Circles/ContentView.swift
  - Circles/CirclesApp.swift
  - Circles/Info.plist
autonomous: false
requirements:
  - PHASE1-AUTH-APPLE
  - PHASE1-AUTH-GOOGLE
  - PHASE1-AUTH-PERSIST
  - PHASE1-NAV-SHELL
  - PHASE1-EMPTY-STATES
  - PHASE1-SUPABASE-CONFIG

must_haves:
  truths:
    - "App launches and shows a loading indicator while restoring session — no flash of sign-in screen for authenticated users"
    - "Unauthenticated user sees a sign-in screen with Sign in with Apple and Continue with Google buttons"
    - "Sign in with Apple completes end-to-end and lands the user on the tab bar shell"
    - "Google Sign-In completes end-to-end and lands the user on the tab bar shell"
    - "Killing and relaunching the app while authenticated skips the sign-in screen entirely"
    - "Tab bar shows three tabs: Home, Community, Profile — each with a styled empty state"
    - "App builds clean (zero errors, zero Swift 6 concurrency warnings) and runs in Simulator"

  artifacts:
    - path: "Circles/Services/SupabaseService.swift"
      provides: "SupabaseClient singleton, Secrets.plist loading"
      exports: ["SupabaseService.shared", "SupabaseService.shared.client"]
    - path: "Circles/Auth/AuthManager.swift"
      provides: "@Observable @MainActor session state, sign-in/out methods"
      exports: ["AuthManager", "AuthManager.session", "AuthManager.isLoading", "AuthManager.isAuthenticated"]
    - path: "Circles/Auth/AuthView.swift"
      provides: "Sign-in screen with Apple + Google buttons"
    - path: "Circles/Navigation/MainTabView.swift"
      provides: "TabView shell with Home / Community / Profile tabs"
    - path: "Circles/ContentView.swift"
      provides: "Root auth router: loading → AuthView or MainTabView"
    - path: "Circles/Info.plist"
      provides: "REVERSED_CLIENT_ID URL scheme for Google OAuth callback"

  key_links:
    - from: "CirclesApp.swift"
      to: "AuthManager"
      via: ".environment(authManager)"
      pattern: "\\.environment\\(authManager\\)"
    - from: "ContentView.swift"
      to: "AuthManager.isAuthenticated"
      via: "@Environment(AuthManager.self)"
      pattern: "@Environment\\(AuthManager\\.self\\)"
    - from: "AuthView.swift"
      to: "SupabaseService.shared.client.auth"
      via: "signInWithIdToken"
      pattern: "signInWithIdToken"
    - from: "AuthManager.swift"
      to: "SupabaseService.shared.client.auth.authStateChanges"
      via: "for await loop"
      pattern: "authStateChanges"
---

<objective>
Build a running Circles iOS app with production-ready authentication (Sign in with Apple + Google OAuth), automatic session persistence across app launches, and a styled three-tab navigation shell. After this phase the app is fully interactive: users can sign in, the app remembers them between launches, and each tab shows a designed empty state that reflects the Circles visual identity.

Purpose: Establishes the auth backbone and navigation skeleton that every subsequent phase builds on. Getting Swift 6 concurrency right here prevents compounding errors in later phases.

Output:
- SupabaseService singleton (Secrets.plist → SupabaseClient)
- AuthManager: @Observable @MainActor class owning session state
- AuthView: Sign-in screen with Apple + Google buttons, Circles visual identity
- MainTabView: Home / Community / Profile tab shell
- HomeView / CommunityView / ProfileView: Styled empty states
- ContentView: Auth router (loading → sign-in or tab bar)
- CirclesApp: Injects AuthManager into SwiftUI environment
- Info.plist: REVERSED_CLIENT_ID URL scheme for Google OAuth
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/01-auth-navigation-shell/01-RESEARCH.md

<!-- Existing source files being replaced/extended -->
@Circles/CirclesApp.swift
@Circles/ContentView.swift
</context>

<interfaces>
<!-- Key contracts and types the executor needs. No codebase exploration required. -->

SUPABASE SDK (already installed via SPM, v2.42.0):
```swift
// SupabaseClient is Sendable — safe as a global let constant in Swift 6
import Supabase
let client = SupabaseClient(supabaseURL: URL, supabaseKey: String)
client.auth.authStateChanges  // AsyncStream<(AuthChangeEvent, Session?)>
try await client.auth.signInWithIdToken(credentials: OpenIDConnectCredentials)
try await client.auth.signOut()
try await client.auth.update(user: UserAttributes)
```

AUTH CHANGE EVENTS to handle in AuthManager.listenToAuthChanges():
```swift
// Handle these three — ignore others (passwordRecovery, userUpdated, etc.)
.initialSession  // fires on cold launch with Keychain-restored session
.signedIn        // fires after signInWithIdToken succeeds
.signedOut       // fires after signOut()
```

GOOGLE SIGN-IN (v9.1.0 — must be added via SPM before execution):
```swift
import GoogleSignIn
import GoogleSignInSwift

// SDK reads iOS client ID from REVERSED_CLIENT_ID in Info.plist CFBundleURLTypes
let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
let idToken = result.user.idToken!.tokenString
let accessToken = result.user.accessToken.tokenString
// Then: client.auth.signInWithIdToken(credentials: OpenIDConnectCredentials(provider: .google, idToken:, accessToken:))
```

SIGN IN WITH APPLE:
```swift
import AuthenticationServices
// SignInWithAppleButton(onRequest:, onCompletion:) — native SwiftUI component
// credential.identityToken -> idToken string
// credential.fullName -> only non-nil on FIRST sign-in — save immediately
// Then: client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken:))
```

OBSERVABLE PATTERN (Swift 6 / iOS 17+):
```swift
// In AuthManager: @Observable @MainActor final class AuthManager { ... }
// In CirclesApp: @State private var authManager = AuthManager()
//                .environment(authManager)
// In views: @Environment(AuthManager.self) private var auth
// NOT: @StateObject / @EnvironmentObject (pre-iOS 17 pattern)
```
</interfaces>

<!-- ============================================================
     WAVE 0 — PREREQUISITES
     Human-only setup that cannot be automated.
     Must complete before any code tasks run.
     ============================================================ -->

<tasks>

<task type="checkpoint:human-action" gate="blocking">
  <name>Wave 0 — Task 1: Create Secrets.plist with real Supabase keys</name>
  <what-must-exist>
    Circles/Secrets.plist (gitignored) containing SUPABASE_URL, SUPABASE_ANON_KEY, GEMINI_API_KEY.
    This file is the pre-execution blocker — SupabaseService.swift throws a fatalError if it is missing.
    Claude cannot create this file because the values come from your Supabase dashboard.
  </what-must-exist>
  <how-to-do-it>
    1. Open Xcode → right-click the "Circles" group in the Project Navigator → New File → Property List
    2. Name it exactly "Secrets" (Xcode adds .plist)
    3. Add these three keys as String values:
       - Key: SUPABASE_URL     → Value: your Supabase project URL (e.g. https://xxxx.supabase.co)
       - Key: SUPABASE_ANON_KEY → Value: your Supabase project anon key
       - Key: GEMINI_API_KEY   → Value: your Gemini API key (can be a placeholder for now)
    4. Confirm Secrets.plist appears in the Circles target's "Copy Bundle Resources" build phase
    5. Confirm Secrets.plist is NOT tracked by git: run `git status` — it should not appear
       If it appears: add `Circles/Secrets.plist` to .gitignore immediately
  </how-to-do-it>
  <resume-signal>Type "secrets ready" when Secrets.plist exists with real SUPABASE_URL and SUPABASE_ANON_KEY</resume-signal>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <name>Wave 0 — Task 2: Add GoogleSignIn-iOS 9.1.0 via SPM</name>
  <what-must-exist>
    GoogleSignIn and GoogleSignInSwift packages linked in the Circles target.
    These are required for Task 5 (AuthView) to compile.
  </what-must-exist>
  <how-to-do-it>
    1. In Xcode: File → Add Package Dependencies
    2. Enter URL: https://github.com/google/GoogleSignIn-iOS
    3. Select version rule: "Up to Next Major Version" from 9.1.0
    4. When prompted for products: check BOTH "GoogleSignIn" and "GoogleSignInSwift"
    5. Click Add Package
    6. Verify: Circles target → General → Frameworks, Libraries → GoogleSignIn and GoogleSignInSwift appear
  </how-to-do-it>
  <resume-signal>Type "googlesignin added" when both GoogleSignIn and GoogleSignInSwift are in Frameworks, Libraries</resume-signal>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <name>Wave 0 — Task 3: Enable Xcode capabilities and configure Google OAuth</name>
  <what-must-exist>
    Three things must be in place before auth can work end-to-end:
    A) "Sign in with Apple" capability on the Circles target
    B) Google Cloud Console iOS OAuth Client ID created for bundle app.joinlegacy
    C) REVERSED_CLIENT_ID registered in Info.plist (Claude will write the plist entry in Task 6,
       but you must supply the actual REVERSED_CLIENT_ID value here first)
  </what-must-exist>
  <how-to-do-it>
    A — Sign in with Apple:
    1. Xcode → Circles target → Signing & Capabilities
    2. Click "+ Capability" → search "Sign in with Apple" → double-click to add
    3. (Optional but recommended) verify developer.apple.com → Identifiers → app.joinlegacy has
       "Sign in with Apple" enabled

    B — Google Cloud Console (new iOS client — do NOT reuse the web client):
    1. Go to console.cloud.google.com → select your Legacy project
    2. APIs & Services → Credentials → Create Credentials → OAuth client ID
    3. Application type: iOS
    4. Bundle ID: app.joinlegacy
    5. Download the config or note the Client ID and REVERSED_CLIENT_ID
       REVERSED_CLIENT_ID format: com.googleusercontent.apps.XXXXXXXXX-XXXXXXXXXXXXXXXX

    C — Supabase Dashboard:
    1. Authentication → Providers → Google
    2. Enable Google provider if not already enabled
    3. Enter the iOS Client ID in the "iOS Client ID" field
    4. Enable "Skip nonce check" (required for native iOS sign-in)
    5. Authentication → Providers → Apple → enter bundle ID app.joinlegacy in Client IDs

    Note your REVERSED_CLIENT_ID — Claude will need it in Task 6 (Info.plist update).
  </how-to-do-it>
  <resume-signal>Type "capabilities done" and include your REVERSED_CLIENT_ID value (e.g. "capabilities done, REVERSED_CLIENT_ID=com.googleusercontent.apps.12345-abcde")</resume-signal>
</task>

<!-- ============================================================
     WAVE 1 — SUPABASE SERVICE + AUTH MANAGER
     Pure Swift — no UI. Can be written once Wave 0 checkpoints pass.
     ============================================================ -->

<task type="auto" tdd="false">
  <name>Wave 1 — Task 4: Create SupabaseService singleton</name>
  <files>Circles/Services/SupabaseService.swift</files>
  <action>
    Create the directory Circles/Services/ if it does not exist (it won't — this is a clean project).

    Write Circles/Services/SupabaseService.swift:

    - `import Supabase`
    - `final class SupabaseService: @unchecked Sendable` — @unchecked is safe because the
      single `client` property is itself Sendable and is set once in init, never mutated
    - `static let shared = SupabaseService()` — singleton
    - `let client: SupabaseClient` — the underlying Supabase client
    - `private init()` — loads Secrets.plist from Bundle.main, calls fatalError if missing or
      malformed. Required keys: SUPABASE_URL (String → URL), SUPABASE_ANON_KEY (String).
      GEMINI_API_KEY is loaded but stored separately (not needed for SupabaseClient init).
    - After loading keys: `client = SupabaseClient(supabaseURL: url, supabaseKey: key)`

    Do NOT create a module-level `let supabase = ...` global. All callers use
    `SupabaseService.shared.client`. This matches CLAUDE.md naming convention.

    Do NOT add any auth logic here — that lives in AuthManager.
  </action>
  <verify>
    Project builds with no errors after adding SupabaseService.swift.
    Run: Cmd+B in Xcode (or `xcodebuild -scheme Circles -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20`)
  </verify>
  <done>
    Circles/Services/SupabaseService.swift exists, builds cleanly, exposes SupabaseService.shared.client,
    throws fatalError on missing Secrets.plist.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Wave 1 — Task 5: Create AuthManager</name>
  <files>Circles/Auth/AuthManager.swift</files>
  <action>
    Create the directory Circles/Auth/ if it does not exist.

    Write Circles/Auth/AuthManager.swift:

    ```swift
    import Supabase
    import Observation

    @Observable
    @MainActor
    final class AuthManager {
        var session: Session? = nil
        var isLoading: Bool = true
        var authError: Error? = nil

        init() {
            Task { await listenToAuthChanges() }
        }

        var isAuthenticated: Bool { session != nil }

        // MARK: - Auth State

        private func listenToAuthChanges() async {
            for await (event, session) in await SupabaseService.shared.client.auth.authStateChanges {
                guard [.initialSession, .signedIn, .signedOut].contains(event) else { continue }
                self.session = session
                self.isLoading = false
            }
        }

        // MARK: - Sign Out

        func signOut() async {
            do {
                try await SupabaseService.shared.client.auth.signOut()
            } catch {
                authError = error
            }
        }
    }
    ```

    Key requirements:
    - `@Observable` + `@MainActor` — these two together satisfy Swift 6 strict concurrency.
      All `self.session = session` mutations happen on the main actor automatically because
      the for-await loop is inside a @MainActor context.
    - `isLoading = true` initially prevents AuthView flash on cold launch for signed-in users.
    - Only handle `.initialSession`, `.signedIn`, `.signedOut` events — ignore others.
    - `authError` is exposed so AuthView can display errors without needing its own try/catch
      on signOut. Sign-in errors are handled locally in AuthView (Apple/Google both have
      distinct error types; centralizing them would require an error enum — not worth it MVP).
    - Do NOT implement signInWithApple or signInWithGoogle here — those live in AuthView
      because they need SwiftUI view context (button callbacks, UIViewController access).
  </action>
  <verify>
    Project builds with no errors. AuthManager.swift added to Xcode target (verify it appears
    in Build Phases → Compile Sources).
  </verify>
  <done>
    Circles/Auth/AuthManager.swift exists. AuthManager is @Observable @MainActor with session,
    isLoading, isAuthenticated, authError, signOut(). Builds with zero Swift 6 concurrency warnings.
  </done>
</task>

<!-- ============================================================
     WAVE 2 — AUTH UI
     Depends on Wave 1 (uses AuthManager, SupabaseService).
     ============================================================ -->

<task type="auto" tdd="false">
  <name>Wave 2 — Task 6: Create AuthView (sign-in screen)</name>
  <files>Circles/Auth/AuthView.swift</files>
  <action>
    Write Circles/Auth/AuthView.swift — the sign-in screen shown to unauthenticated users.

    VISUAL DESIGN:
    - Background: deep navy/midnight (`Color(hex: "0D1021")` — define a Color extension if not present)
    - Centered layout, full screen
    - Top section (40% of screen): App icon / logo treatment.
      Use a VStack with: a moon+stars SF Symbol (moon.stars.fill, large, amber/orange tint),
      the word "Circles" in a large serif-ish font (Font.system(.largeTitle, design: .serif, weight: .semibold)),
      a subtitle in light gray: "Your Islamic accountability circle"
    - Bottom section (60%): Auth buttons stacked vertically with 12pt gap
    - Footer: small gray legal text "By continuing, you agree to our Terms and Privacy Policy"

    AUTH BUTTONS:
    1. Sign in with Apple button:
       ```swift
       SignInWithAppleButton { request in
           request.requestedScopes = [.email, .fullName]
       } onCompletion: { [self] result in
           Task { await handleAppleSignIn(result: result) }
       }
       .signInWithAppleButtonStyle(.white)
       .frame(height: 50)
       .cornerRadius(12)
       ```

    2. Google Sign-In button:
       ```swift
       Button(action: { Task { await signInWithGoogle() } }) {
           HStack(spacing: 10) {
               Image(systemName: "globe")   // placeholder; GoogleSignInSwift's GoogleSignInButton
                   .foregroundColor(.white)  // can be used instead if preferred
               Text("Continue with Google")
                   .foregroundColor(.white)
                   .font(.system(.body, weight: .medium))
           }
           .frame(maxWidth: .infinity)
           .frame(height: 50)
           .background(Color.white.opacity(0.15))
           .cornerRadius(12)
           .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))
       }
       ```
       NOTE: If GoogleSignInButton (from GoogleSignInSwift) is preferred over a custom button,
       use it — but style may conflict with dark background. Custom button above matches design.

    3. Error display: if `showError` is true, show a red text label below buttons with `errorMessage`.

    SIGN IN WITH APPLE HANDLER:
    ```swift
    @MainActor
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        do {
            guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = credential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8)
            else { return }

            try await SupabaseService.shared.client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )

            // Apple only sends fullName on FIRST sign-in — capture immediately or lose it forever
            if let fullName = credential.fullName {
                var parts: [String] = []
                if let given = fullName.givenName { parts.append(given) }
                if let family = fullName.familyName { parts.append(family) }
                if !parts.isEmpty {
                    try await SupabaseService.shared.client.auth.update(
                        user: UserAttributes(data: ["full_name": .string(parts.joined(separator: " "))])
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    ```

    GOOGLE SIGN-IN HANDLER:
    ```swift
    @MainActor
    private func signInWithGoogle() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController
        else { return }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else { return }
            let accessToken = result.user.accessToken.tokenString

            try await SupabaseService.shared.client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    ```

    VIEW STATE:
    - `@State private var showError = false`
    - `@State private var errorMessage = ""`
    - No loading spinner needed — the sign-in sheet itself acts as UI feedback

    IMPORTS: SwiftUI, AuthenticationServices, GoogleSignIn, GoogleSignInSwift, Supabase

    INFO.PLIST UPDATE (do this in this same task):
    The REVERSED_CLIENT_ID from Wave 0 Task 3 must be registered as a URL scheme so the
    Google OAuth callback can return to the app. Add to Circles/Info.plist:

    ```xml
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>REVERSED_CLIENT_ID_FROM_WAVE_0_TASK_3</string>
            </array>
        </dict>
    </array>
    ```

    Replace REVERSED_CLIENT_ID_FROM_WAVE_0_TASK_3 with the actual value the user provided
    at Wave 0 Task 3 resume (format: com.googleusercontent.apps.XXXXX-XXXXX).

    If Info.plist does not yet exist (Xcode 26 may use Info.plist-less targets with build
    settings), create it and add it to the target. Check first with:
    `ls Circles/Info.plist` — if it does not exist, Xcode's build settings hold the plist
    data; in that case add a new Info.plist file and wire it in Xcode target settings.
  </action>
  <verify>
    Project builds with no errors or warnings.
    Smoke check: In Simulator, AuthView should be visible (once ContentView routing is wired
    in Wave 4). At this stage, build success is sufficient.
  </verify>
  <done>
    Circles/Auth/AuthView.swift exists with Apple + Google sign-in handlers.
    Info.plist contains CFBundleURLTypes with REVERSED_CLIENT_ID.
    Zero Swift 6 concurrency warnings. Builds clean.
  </done>
</task>

<!-- ============================================================
     WAVE 3 — TAB BAR SHELL + EMPTY STATE SCREENS
     Independent of Wave 2. Can run in parallel with Wave 2.
     ============================================================ -->

<task type="auto" tdd="false">
  <name>Wave 3 — Task 7: Create MainTabView + styled empty state screens</name>
  <files>
    Circles/Navigation/MainTabView.swift,
    Circles/Home/HomeView.swift,
    Circles/Community/CommunityView.swift,
    Circles/Profile/ProfileView.swift
  </files>
  <action>
    Create these four files. The empty state screens must reflect the Circles visual identity —
    NOT just "Hello World" placeholders.

    ---- MainTabView.swift ----

    Create Circles/Navigation/MainTabView.swift:

    ```swift
    import SwiftUI

    struct MainTabView: View {
        var body: some View {
            TabView {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }

                CommunityView()
                    .tabItem { Label("Community", systemImage: "person.2.fill") }

                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.circle.fill") }
            }
            .tint(Color(hex: "E8834B"))  // Warm orange/amber accent
        }
    }
    ```

    ---- HomeView.swift ----

    Create Circles/Home/HomeView.swift. This will become the daily habit check-in screen in
    Phase 2. Empty state must show the time-of-day greeting pattern (Phase 2 will make it
    dynamic; for now derive the greeting from current hour using a computed var).

    ```swift
    import SwiftUI

    struct HomeView: View {
        @Environment(AuthManager.self) private var auth

        private var greeting: String {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 0..<6:   return "Peaceful Night"
            case 6..<12:  return "Good Morning"
            case 12..<15: return "Peaceful Afternoon"
            case 15..<18: return "Blessed Asr"
            case 18..<21: return "Blessed Evening"
            default:      return "Peaceful Night"
            }
        }

        private var greetingEmoji: String {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 0..<6:   return "🌙"
            case 6..<12:  return "☀️"
            case 12..<15: return "🕌"
            case 15..<18: return "🤲"
            case 18..<21: return "🌅"
            default:      return "🌙"
            }
        }

        private var firstName: String {
            // Extract first name from Supabase user metadata; fall back to "Friend"
            // Phase 2 will refine this once User model is built
            let fullName = auth.session?.user.userMetadata["full_name"]?.stringValue
                        ?? auth.session?.user.email?.components(separatedBy: "@").first
                        ?? "Friend"
            return fullName.components(separatedBy: " ").first ?? fullName
        }

        var body: some View {
            NavigationStack {
                ZStack {
                    Color(hex: "0D1021").ignoresSafeArea()

                    VStack(spacing: 32) {
                        Spacer()

                        // Greeting header (serif font per design)
                        VStack(spacing: 8) {
                            Text("\(greeting), \(firstName) \(greetingEmoji)")
                                .font(.system(.title, design: .serif, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Text("Your habits await")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 32)

                        // Empty state illustration area
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Color(hex: "E8834B").opacity(0.8))

                            Text("Habits coming in Phase 2")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        Spacer()
                    }
                }
            }
        }
    }
    ```

    ---- CommunityView.swift ----

    Create Circles/Community/CommunityView.swift (will become Circles list in Phase 3):

    ```swift
    import SwiftUI

    struct CommunityView: View {
        var body: some View {
            NavigationStack {
                ZStack {
                    Color(hex: "0D1021").ignoresSafeArea()

                    VStack(spacing: 24) {
                        Spacer()

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color(hex: "E8834B").opacity(0.7))

                        VStack(spacing: 8) {
                            Text("Your Circles")
                                .font(.system(.title2, design: .serif, weight: .semibold))
                                .foregroundStyle(.white)

                            Text("Create or join a circle to get started")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 32)
                }
                .navigationTitle("")
            }
        }
    }
    ```

    ---- ProfileView.swift ----

    Create Circles/Profile/ProfileView.swift. This screen needs Sign Out functional (uses
    AuthManager from environment) even as an empty state.

    ```swift
    import SwiftUI

    struct ProfileView: View {
        @Environment(AuthManager.self) private var auth

        var body: some View {
            NavigationStack {
                ZStack {
                    Color(hex: "0D1021").ignoresSafeArea()

                    VStack(spacing: 32) {
                        Spacer()

                        // Avatar placeholder
                        Circle()
                            .fill(Color(hex: "E8834B").opacity(0.2))
                            .frame(width: 96, height: 96)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color(hex: "E8834B"))
                            )

                        VStack(spacing: 6) {
                            Text(auth.session?.user.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Spacer()

                        // Sign out (functional even in empty state)
                        Button {
                            Task { await auth.signOut() }
                        } label: {
                            Text("Sign Out")
                                .font(.system(.body, weight: .medium))
                                .foregroundStyle(.red.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }
    ```

    COLOR EXTENSION: All four files reference `Color(hex:)`. Add this extension once,
    in a new file Circles/Extensions/Color+Hex.swift:

    ```swift
    import SwiftUI

    extension Color {
        init(hex: String) {
            let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&int)
            let a, r, g, b: UInt64
            switch hex.count {
            case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            default: (a, r, g, b) = (255, 0, 0, 0)
            }
            self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
        }
    }
    ```

    Files to create:
    - Circles/Navigation/MainTabView.swift
    - Circles/Home/HomeView.swift
    - Circles/Community/CommunityView.swift
    - Circles/Profile/ProfileView.swift
    - Circles/Extensions/Color+Hex.swift

    All five must be added to the Circles Xcode target (Build Phases → Compile Sources).
  </action>
  <verify>
    Project builds with no errors. In a #Preview block, MainTabView() renders all three tabs.
    Add previews to at least HomeView.swift and ProfileView.swift.
  </verify>
  <done>
    All four views + Color extension exist. MainTabView shows three tabs. Each tab has a
    styled empty state (dark navy bg, amber accent, serif header where applicable, not "Hello World").
    ProfileView sign-out button is wired to auth.signOut().
    Builds clean.
  </done>
</task>

<!-- ============================================================
     WAVE 4 — CONTENT VIEW ROUTING + APP ENTRY POINT
     Depends on Wave 1, 2, and 3 being complete.
     ============================================================ -->

<task type="auto" tdd="false">
  <name>Wave 4 — Task 8: Wire ContentView routing and CirclesApp entry point</name>
  <files>
    Circles/ContentView.swift,
    Circles/CirclesApp.swift
  </files>
  <action>
    These two files are the final wiring layer. They replace the "Hello, world!" placeholder.

    ---- CirclesApp.swift ----

    Replace the entire file:

    ```swift
    import SwiftUI

    @main
    struct CirclesApp: App {
        @State private var authManager = AuthManager()

        var body: some Scene {
            WindowGroup {
                ContentView()
                    .environment(authManager)
                    // .environment injects @Observable types — NOT .environmentObject
                    // @Observable was introduced in iOS 17 / Swift 5.9
            }
        }
    }
    ```

    Note: `@State private var authManager = AuthManager()` is the correct Swift 6 / iOS 17
    pattern for an @Observable root model in App. Do NOT use @StateObject (ObservableObject
    pattern — pre-iOS 17).

    ---- ContentView.swift ----

    Replace the entire file:

    ```swift
    import SwiftUI

    struct ContentView: View {
        @Environment(AuthManager.self) private var auth

        var body: some View {
            Group {
                if auth.isLoading {
                    // Session restoration in progress — show spinner to prevent
                    // auth screen flash for users who are already signed in
                    ZStack {
                        Color(hex: "0D1021").ignoresSafeArea()
                        ProgressView()
                            .tint(Color(hex: "E8834B"))
                            .scaleEffect(1.5)
                    }
                } else if auth.isAuthenticated {
                    MainTabView()
                } else {
                    AuthView()
                }
            }
            .animation(.easeInOut(duration: 0.25), value: auth.isLoading)
            .animation(.easeInOut(duration: 0.25), value: auth.isAuthenticated)
        }
    }

    #Preview {
        ContentView()
            .environment(AuthManager())
    }
    ```

    Key requirements:
    - The `isLoading` guard is CRITICAL — it prevents the sign-in screen flash on cold launch
      for users who are already authenticated (Keychain session restoration is async)
    - `.animation` on both `isLoading` and `isAuthenticated` gives a smooth transition
    - The preview injects a fresh AuthManager so it can render in Xcode canvas
    - Do NOT use any UIKit here — pure SwiftUI routing

    After writing these two files, do a final build verification:
    - Build must succeed: zero errors, zero warnings
    - Run in iPhone 16 Simulator — app should launch showing the loading spinner briefly,
      then (because no session exists yet) transition to AuthView
    - The Apple sign-in button and Google sign-in button should be visible and tappable
  </action>
  <verify>
    Full build succeeds: `xcodebuild -scheme Circles -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E 'error:|warning:|BUILD'`
    Zero errors. Zero Swift concurrency warnings.
    In Simulator: app shows loading spinner then AuthView with Apple + Google buttons.
  </verify>
  <done>
    ContentView routes correctly: loading → AuthView (unauthenticated) or MainTabView (authenticated).
    CirclesApp injects AuthManager as @Observable environment.
    App runs in Simulator. Zero build errors or Swift 6 warnings.
  </done>
</task>

<!-- ============================================================
     WAVE 5 — END-TO-END VERIFICATION
     Both auth flows tested by the human.
     ============================================================ -->

<task type="checkpoint:human-verify" gate="blocking">
  <name>Wave 5 — Task 9: Verify end-to-end auth + navigation</name>
  <what-built>
    Complete Phase 1: Supabase singleton, @Observable AuthManager, AuthView with Apple + Google
    sign-in, MainTabView shell with three styled empty state tabs, ContentView session routing.
  </what-built>
  <how-to-verify>
    Run these checks in order. Each must pass before marking Phase 1 done.

    CHECK 1 — Auth screen on fresh launch:
    1. Launch app in Simulator (iPhone 16)
    2. Expected: Brief loading spinner (< 1 second), then AuthView with:
       - Dark navy background
       - "Circles" title with moon/stars icon
       - "Sign in with Apple" button
       - "Continue with Google" button

    CHECK 2 — Sign in with Apple:
    1. Tap "Sign in with Apple"
    2. Complete Apple auth sheet (Simulator will show a mock Apple ID)
    3. Expected: App transitions to MainTabView with Home / Community / Profile tabs

    CHECK 3 — Session persistence (Apple):
    1. While signed in, kill the app (Cmd+Shift+H, then swipe up in Simulator)
    2. Relaunch the app
    3. Expected: Loading spinner → directly to MainTabView (NO sign-in screen)

    CHECK 4 — Sign out:
    1. Tap Profile tab
    2. Tap "Sign Out"
    3. Expected: App transitions back to AuthView

    CHECK 5 — Sign in with Google:
    1. On AuthView, tap "Continue with Google"
    2. Complete Google auth sheet
    3. Expected: App transitions to MainTabView

    CHECK 6 — Session persistence (Google):
    1. Kill and relaunch app while signed in via Google
    2. Expected: Goes directly to MainTabView

    CHECK 7 — Tab bar:
    1. While logged in, verify all three tabs are reachable
    2. Each tab: styled empty state (dark navy bg, amber icon, readable text)
    3. Home tab greeting: check that it reflects time of day
       (e.g. if afternoon: "Peaceful Afternoon, [Name] 🕌")

    CHECK 8 — Build quality:
    In Xcode: Product → Clean Build Folder, then Cmd+B
    Expected: BUILD SUCCEEDED — zero errors, zero warnings in the Issue Navigator
  </how-to-verify>
  <resume-signal>
    Type "phase 1 approved" if all 8 checks pass.
    Or describe which checks failed and what you observed — Claude will diagnose and fix.
  </resume-signal>
</task>

</tasks>

<verification>
## Phase 1 Verification Checklist

### Build Quality
- [ ] Zero build errors
- [ ] Zero Swift 6 concurrency warnings (especially around @MainActor and authStateChanges)
- [ ] No force-unwraps on auth-critical paths (credential.identityToken, idToken)
- [ ] No `UIKit` imports except in AuthView.swift (one UIViewController lookup for Google)

### Auth Correctness
- [ ] Sign in with Apple: uses `signInWithIdToken`, not OAuth redirect
- [ ] Apple full name captured on first sign-in via `auth.update(user:)` immediately after token sign-in
- [ ] Google Sign-In: uses `GIDSignIn.sharedInstance.signIn(withPresenting:)` + `signInWithIdToken`
- [ ] `REVERSED_CLIENT_ID` present in Info.plist `CFBundleURLTypes` for Google callback
- [ ] AuthManager handles only `.initialSession`, `.signedIn`, `.signedOut` events

### Session Persistence
- [ ] `isLoading = true` initially in AuthManager (prevents auth screen flash)
- [ ] `isLoading = false` set after `.initialSession` fires
- [ ] Kill-and-relaunch goes directly to MainTabView for authenticated user

### Architecture
- [ ] `@Observable @MainActor final class AuthManager` — not `@StateObject` / `ObservableObject`
- [ ] `CirclesApp` uses `@State private var authManager = AuthManager()` + `.environment(authManager)`
- [ ] `ContentView` uses `@Environment(AuthManager.self) private var auth`
- [ ] `SupabaseService.shared` is the single Supabase client instance
- [ ] `Secrets.plist` is gitignored

### UI / Design
- [ ] Dark navy background (`#0D1021`) on all screens
- [ ] Warm orange/amber accent (`#E8834B`) on icons, tab bar tint, spinner
- [ ] Serif font on greeting headers (HomeView) and section titles
- [ ] HomeView greeting adapts to time of day: "Good Morning / Peaceful Afternoon / Blessed Asr" etc.
- [ ] ProfileView Sign Out button is functional (not placeholder)
- [ ] No screen shows literal "Hello, world!" or "Hello, World!"
</verification>

<success_criteria>
Phase 1 is complete when ALL of the following are true:

1. `xcodebuild` reports BUILD SUCCEEDED with zero errors and zero warnings
2. App launches in Simulator → shows loading spinner → then AuthView (no session) or MainTabView (session)
3. Sign in with Apple completes end-to-end and user lands on MainTabView
4. Google OAuth completes end-to-end and user lands on MainTabView
5. Kill-and-relaunch while authenticated skips AuthView entirely (session restored from Keychain)
6. Sign out from ProfileView returns to AuthView
7. All three tabs (Home, Community, Profile) visible with styled empty states — not placeholder text
8. HomeView greeting reflects time of day (not hardcoded)
9. No Swift 6 concurrency warnings in Xcode Issue Navigator
10. Secrets.plist is NOT committed to git (`git status` shows it untracked/ignored)
</success_criteria>

<open_questions>
These items were flagged during research and need runtime validation during execution:

OQ-1: emitLocalSessionAsInitialSession flag
  Research found a Supabase SDK config flag `emitLocalSessionAsInitialSession: true` that
  "ensures the locally stored session is always emitted." It is UNCLEAR whether this is on
  by default in SDK v2.42.0 or requires explicit opt-in.
  Action: After implementing AuthManager, test kill-and-relaunch. If .initialSession fires
  with a non-nil session (session restores), the flag is on by default — no change needed.
  If .initialSession fires with nil (or doesn't fire), add to SupabaseClientOptions:
  `SupabaseClientOptions(auth: .init(autoRefreshToken: true, persistSession: true))`
  and investigate the flag in the SDK source at:
  https://github.com/supabase/supabase-swift/blob/main/Sources/Auth/AuthClient.swift

OQ-2: Google iOS Client ID — new vs. reuse
  The Legacy web app has an existing Google OAuth client. For native iOS auth, a NEW
  iOS-type OAuth client must be created (web clients do not work with GIDSignIn).
  This is confirmed — the Wave 0 Task 3 checkpoint includes creating the iOS client.
  No code change needed; just developer action.

OQ-3: Supabase Apple provider — nonce requirement
  Research confirms nonce is NOT required for native iOS `signInWithIdToken` with Apple.
  The AuthView implementation does not include a nonce. If Supabase rejects the sign-in
  with an error about nonce, add SHA256 nonce generation:
  ```swift
  let rawNonce = randomNonceString()
  let hashedNonce = sha256(rawNonce)
  request.nonce = hashedNonce
  // Then pass rawNonce to signInWithIdToken credentials
  ```
  Only add this if the simpler implementation fails.
</open_questions>

<output>
After execution is complete and Wave 5 checkpoint is approved, create:
  .planning/phases/01-auth-navigation-shell/01-SUMMARY.md

The summary must include:
- Files created and their purposes
- Auth patterns actually used (confirm @Observable + @MainActor worked)
- Whether emitLocalSessionAsInitialSession was needed (OQ-1 resolution)
- Any deviations from this plan and why
- Confirmation that Secrets.plist is gitignored
- Build output (BUILD SUCCEEDED screenshot or paste)

Then update .planning/STATE.md:
- Move Phase 1 to "What's Done"
- Set Phase 2 as "Current Phase"
- Record any new decisions made during execution
</output>
