# Phase 1: Auth + Core Navigation Shell — Research

**Researched:** 2026-03-23
**Domain:** SwiftUI iOS auth (Sign in with Apple, Google OAuth via Supabase), session persistence, tab navigation shell
**Confidence:** HIGH (core auth APIs), MEDIUM (Swift 6 concurrency gotchas)

---

## Summary

Phase 1 establishes the authentication backbone and navigation shell for Circles. The Supabase Swift SDK (v2.42.0, already installed) provides all necessary auth primitives. Sign in with Apple uses the native `AuthenticationServices` framework with `signInWithIdToken` — no web redirect involved. Google OAuth uses the `GoogleSignIn-iOS` SDK (v9.1.0) with the same `signInWithIdToken` pattern. Both flows avoid browser-based redirects entirely, giving a native sheet experience.

Session persistence is handled automatically by the Supabase SDK — it stores tokens in the iOS Keychain and restores them on next launch by emitting an `initialSession` event via the `authStateChanges` async stream. The recommended SwiftUI pattern is a `@Observable @MainActor` auth manager class that listens to this stream, paired with a root `ContentView` that routes to either `AuthView` or `MainTabView` based on `session != nil`.

`SupabaseClient` is declared `public final class SupabaseClient: Sendable` and uses `LockIsolated` internally — it is safe as a global `let` constant in Swift 6 without needing `nonisolated` or `@MainActor` on the client itself.

**Primary recommendation:** Use a `@Observable @MainActor final class AuthManager` that owns the `authStateChanges` stream listener, exposes a `session: Session?` property, and is injected as an `@Environment` value in SwiftUI. The `SupabaseClient` lives as a module-level `let supabase = SupabaseClient(...)` — safe in Swift 6 because the type is `Sendable`.

---

## Project Constraints (from CLAUDE.md)

- Language: Swift 6 (strict concurrency enabled)
- UI: SwiftUI only — no UIKit unless absolutely necessary
- Backend: Supabase Swift SDK v2.42.0 (already installed via SPM)
- Auth: Sign in with Apple + Google OAuth via Supabase
- Secrets in `Circles/Secrets.plist` (gitignored) — keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- No `UIKit` unless absolutely necessary (camera, APNs) — use SwiftUI wrappers first
- Supabase client is a singleton: `SupabaseService.shared` (CLAUDE.md naming convention)
- Models: `Codable`, snake_case → camelCase via `CodingKeys`
- `@StateObject` / `@EnvironmentObject` for Supabase session (CLAUDE.md says this, but `@Observable` + `@Environment` is the modern Swift 5.9+/6 equivalent — see Architecture Patterns)
- Build must succeed with no errors before marking done
- Feature must be demonstrable in Simulator before marking done

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase-swift | 2.42.0 (pinned) | Auth, DB, Storage | Already installed; official Supabase SDK |
| AuthenticationServices | System (iOS 17+) | Sign in with Apple | Apple-required for App Store; zero dependencies |
| GoogleSignIn-iOS | 9.1.0 | Google OAuth native sign-in | Official Google SDK; avoids web redirect; `Sendable`-compatible in Swift 6 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| GoogleSignInSwift | (bundled with GoogleSignIn-iOS) | `GoogleSignInButton` SwiftUI component | Use for the sign-in button UI |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| GoogleSignIn-iOS native | `signInWithOAuth` + `ASWebAuthenticationSession` | Web-based redirect; worse UX; requires URL scheme deep link; more moving parts |
| `@Observable` auth manager | `@StateObject` / `ObservableObject` | `ObservableObject` still works but `@Observable` is Swift 5.9+ standard and avoids unnecessary re-renders |

### Installation

`supabase-swift` is already installed. Add GoogleSignIn-iOS:

```
File > Add Package Dependencies > https://github.com/google/GoogleSignIn-iOS
Select: GoogleSignIn, GoogleSignInSwift
Version: 9.1.0 (or "Up to Next Major" from 9.0.0)
```

---

## Architecture Patterns

### Recommended Project Structure
```
Circles/
├── CirclesApp.swift              # App entry, SupabaseService init, environment injection
├── ContentView.swift             # Root auth router
├── Supabase.swift                # Global let supabase = SupabaseClient(...)
├── Auth/
│   ├── AuthManager.swift         # @Observable @MainActor session state + auth methods
│   ├── AuthView.swift            # Sign in with Apple + Google buttons
│   └── SignInWithAppleHandler.swift  # ASAuthorizationControllerDelegate
├── Home/
│   └── HomeView.swift            # Empty state placeholder
├── Community/
│   └── CommunityView.swift       # Empty state placeholder
├── Profile/
│   └── ProfileView.swift         # Empty state placeholder
└── Navigation/
    └── MainTabView.swift         # TabView with 3 tabs
```

### Pattern 1: Global SupabaseClient (Safe in Swift 6)

`SupabaseClient` is `public final class SupabaseClient: Sendable` with `LockIsolated` internal state. Declare as a global `let` constant — Swift 6 allows this for `Sendable` types.

```swift
// Supabase.swift
// Source: https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui
import Supabase

let supabase: SupabaseClient = {
    guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
          let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
          let urlString = dict["SUPABASE_URL"] as? String,
          let url = URL(string: urlString),
          let key = dict["SUPABASE_ANON_KEY"] as? String
    else {
        fatalError("Secrets.plist missing or malformed — check SUPABASE_URL and SUPABASE_ANON_KEY")
    }
    return SupabaseClient(supabaseURL: url, supabaseKey: key)
}()
```

Note: CLAUDE.md uses the naming `SupabaseService.shared`. A thin wrapper that vends the global `supabase` client is fine — but the underlying `SupabaseClient` can be the global let constant. Match CLAUDE.md naming by calling the wrapper `SupabaseService`:

```swift
// Services/SupabaseService.swift
import Supabase

final class SupabaseService: Sendable {
    static let shared = SupabaseService()
    let client: SupabaseClient
    private init() {
        // load from Secrets.plist
        ...
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
}
```

### Pattern 2: @Observable AuthManager (Swift 6 Compatible)

```swift
// Auth/AuthManager.swift
// Source: https://supabase.com/docs/guides/getting-started/tutorials/with-swift
import Supabase
import Observation

@Observable
@MainActor
final class AuthManager {
    var session: Session? = nil
    var isLoading: Bool = true

    init() {
        Task {
            await listenToAuthChanges()
        }
    }

    private func listenToAuthChanges() async {
        for await (event, session) in await SupabaseService.shared.client.auth.authStateChanges {
            // initialSession fires on every cold start with the restored session
            if [.initialSession, .signedIn, .signedOut].contains(event) {
                self.session = session
                self.isLoading = false
            }
        }
    }

    var isAuthenticated: Bool { session != nil }
}
```

Key points:
- `@Observable @MainActor` satisfies Swift 6 strict concurrency for any UI-touching state.
- `authStateChanges` is an `AsyncStream` — iterate with `for await`.
- `.initialSession` fires after the SDK restores the Keychain-stored session on cold launch. No manual `getSession()` call needed.
- `isLoading = true` initially prevents a flash of the auth screen during session restoration.

### Pattern 3: ContentView Auth Router

```swift
// ContentView.swift
// Source: https://supabase.com/docs/guides/getting-started/tutorials/with-swift
import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView()           // Splash/loading while session restores
                    .progressViewStyle(.circular)
            } else if auth.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.default, value: auth.isAuthenticated)
    }
}
```

### Pattern 4: App Entry Point — Inject AuthManager

```swift
// CirclesApp.swift
import SwiftUI

@main
struct CirclesApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)  // @Observable uses .environment, not .environmentObject
        }
    }
}
```

Note: `@Observable` uses `.environment(_:)` + `@Environment(AuthManager.self)`, NOT `@StateObject`/`@EnvironmentObject`. CLAUDE.md mentions `@StateObject`/`@EnvironmentObject` — these are the pre-iOS 17 equivalents and still compile, but `.environment` with `@Observable` is the Swift 5.9+/iOS 17+ standard that avoids the `ObservableObject` protocol overhead.

### Pattern 5: Sign in with Apple

```swift
// Auth/AuthView.swift (relevant section)
// Source: https://supabase.com/docs/guides/auth/social-login/auth-apple
import SwiftUI
import AuthenticationServices
import Supabase

// In AuthView body:
SignInWithAppleButton { request in
    request.requestedScopes = [.email, .fullName]
} onCompletion: { result in
    Task {
        do {
            guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = credential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8)
            else { return }

            try await SupabaseService.shared.client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )

            // Apple only sends fullName on FIRST sign-in — capture it immediately
            if let fullName = credential.fullName {
                var parts: [String] = []
                if let given = fullName.givenName { parts.append(given) }
                if let family = fullName.familyName { parts.append(family) }
                if !parts.isEmpty {
                    try await SupabaseService.shared.client.auth.update(
                        user: UserAttributes(data: [
                            "full_name": .string(parts.joined(separator: " "))
                        ])
                    )
                }
            }
        } catch {
            // Show error to user
        }
    }
}
.signInWithAppleButtonStyle(.black)
.frame(height: 50)
```

### Pattern 6: Google Sign-In (Native — No Web Redirect)

```swift
// Auth/AuthView.swift (relevant section)
// Source: https://supabase.com/docs/guides/auth/social-login/auth-google
import GoogleSignIn
import GoogleSignInSwift
import Supabase

// In AuthView:
GoogleSignInButton(action: signInWithGoogle)
    .frame(height: 50)

// In AuthView or AuthManager:
func signInWithGoogle() {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootVC = windowScene.windows.first?.rootViewController
    else { return }

    Task {
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
            // Show error to user
        }
    }
}
```

Note: `GIDSignIn.sharedInstance.signIn(withPresenting:)` requires a `UIViewController` presenting context. In SwiftUI, access it via `UIApplication.shared.connectedScenes`. This is the one UIKit touch required for Google Sign-In — unavoidable without the web redirect flow.

### Pattern 7: MainTabView Shell

```swift
// Navigation/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            CommunityView()
                .tabItem {
                    Label("Community", systemImage: "person.2.fill")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
    }
}
```

### Anti-Patterns to Avoid

- **Calling `supabase.auth.session` on launch to check auth state:** Instead, wait for `.initialSession` from `authStateChanges`. Calling `session` directly is synchronous and may show stale state.
- **Showing the auth screen before session restoration completes:** The `isLoading` guard in ContentView prevents this flash. Don't remove it.
- **Using `@StateObject` / `ObservableObject` with `@Observable` types:** Mix-and-match causes double-observation or silent failures. Choose one. Use `@Observable` + `@Environment`.
- **Creating multiple `SupabaseClient` instances:** Each instance maintains its own token refresh cycle. One singleton only.
- **Not capturing Apple full name on first sign-in:** Apple sends `fullName` only during the initial auth. Not capturing it = permanent null. Always call `auth.update(user:)` immediately after `signInWithIdToken`.
- **Forgetting `@MainActor` on the auth manager:** UI state mutations from async streams must be on the main actor. Without `@MainActor`, Swift 6 will emit a concurrency error.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Token storage/Keychain | Custom Keychain wrapper | Supabase SDK (automatic) | SDK stores tokens in Keychain via `LocalStorage`, handles refresh automatically |
| OAuth PKCE flow | Manual code verifier/challenge | `signInWithIdToken` (native) | Supabase handles PKCE internally for web flows; native flows skip PKCE entirely |
| Session refresh | Manual token refresh timer | SDK `authStateChanges` `.tokenRefreshed` event | SDK auto-refreshes before expiry |
| Apple nonce validation | Custom SHA-256 nonce | Not required for native apps | Supabase docs confirm nonce not required for native `signInWithIdToken` with Apple |
| Google client ID config | Manual `GIDConfiguration` init | `REVERSED_CLIENT_ID` in Info.plist `CFBundleURLTypes` | GoogleSignIn SDK reads client ID from plist automatically |

**Key insight:** Both Apple and Google auth reduce to a single `signInWithIdToken` call on the Supabase SDK. All token validation, PKCE, and Keychain management is handled by the SDK layer.

---

## Common Pitfalls

### Pitfall 1: Auth Screen Flash on Cold Launch
**What goes wrong:** On cold launch, `session` is `nil` before the SDK restores from Keychain, causing a brief flash of `AuthView` even for signed-in users.
**Why it happens:** The `initialSession` event from `authStateChanges` fires asynchronously after the view is first rendered.
**How to avoid:** Use `isLoading: Bool = true` in `AuthManager`. Keep it `true` until `initialSession` is received. Show `ProgressView()` instead of routing to either screen while loading.
**Warning signs:** Users see a sign-in screen for ~0.2s before being sent to the main app.

### Pitfall 2: Apple Full Name Lost on Repeat Sign-In
**What goes wrong:** After the first sign-in, `credential.fullName` is always `nil` from Apple. If you don't save it on first sign-in, the user's name is never stored.
**Why it happens:** Apple's privacy policy — name is only transmitted once.
**How to avoid:** Immediately after `signInWithIdToken` succeeds, call `auth.update(user:)` with `full_name` from `credential.fullName`. Guard with `if !parts.isEmpty` to avoid overwriting with empty string on repeat logins.
**Warning signs:** User display names are empty or never populated in the DB.

### Pitfall 3: Google Sign-In Requires UIViewController
**What goes wrong:** `GIDSignIn.sharedInstance.signIn(withPresenting:)` requires a `UIViewController`. In a pure SwiftUI app this isn't directly available.
**Why it happens:** Google's SDK predates SwiftUI's `.sheet`/`.fullScreenCover` presentation APIs.
**How to avoid:** Access the root view controller via `UIApplication.shared.connectedScenes`. This is the one unavoidable UIKit dependency for Google Sign-In.
**Warning signs:** Compile error or crash if `nil` is passed as the presenting controller.

### Pitfall 4: Swift 6 Concurrency Errors on Auth State Updates
**What goes wrong:** Updating `@Published` or `@Observable` properties from an `async` background context causes "main actor-isolated property can not be mutated from a non-isolated context" errors.
**Why it happens:** `authStateChanges` delivers on an unspecified executor in the Supabase SDK. The auth manager's `session` property is `@MainActor`.
**How to avoid:** Mark the entire `AuthManager` as `@MainActor`. The `for await` loop inside an `@MainActor` context will hop to the main actor for each iteration automatically.
**Warning signs:** Swift 6 compiler error at the `self.session = session` assignment line.

### Pitfall 5: Google Info.plist REVERSED_CLIENT_ID Mismatch
**What goes wrong:** Google sign-in silently fails or the app can't handle the OAuth callback URL.
**Why it happens:** The `CFBundleURLSchemes` entry must exactly match the reversed iOS client ID from Google Cloud Console (format: `com.googleusercontent.apps.XXXXXXX-XXXXXXX`).
**How to avoid:** Copy the `REVERSED_CLIENT_ID` directly from `GoogleService-Info.plist`. Add it to `Info.plist` under `CFBundleURLTypes`. Verify in Xcode build settings that the URL scheme is registered.
**Warning signs:** Sign-in sheet opens, user authenticates with Google, but app receives no callback.

### Pitfall 6: Missing "Sign in with Apple" Capability
**What goes wrong:** App crashes or silently fails when tapping the Apple sign-in button.
**Why it happens:** The Xcode target must have the "Sign in with Apple" capability enabled, AND the App ID in Apple Developer Portal must have it enabled.
**How to avoid:** In Xcode: Target > Signing & Capabilities > "+ Capability" > "Sign in with Apple". Then verify in developer.apple.com that the App ID (`app.joinlegacy`) has Sign in with Apple enabled.
**Warning signs:** `ASAuthorizationError` domain errors, or the `SignInWithAppleButton` does nothing.

---

## Configuration Checklist

### Apple Developer Console (one-time)
- [ ] App ID `app.joinlegacy` has "Sign in with Apple" capability enabled
- [ ] Register bundle ID in Supabase Dashboard: Authentication > Providers > Apple > Client IDs

### Xcode Target (per-project)
- [ ] Target > Signing & Capabilities > "Sign in with Apple" added
- [ ] `Circles/Secrets.plist` created with `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`
- [ ] `Secrets.plist` confirmed in `.gitignore`

### Google Cloud Console + Supabase (one-time)
- [ ] iOS OAuth Client ID created in Google Cloud Console (bundle ID: `app.joinlegacy`)
- [ ] `GoogleService-Info.plist` downloaded (or just the iOS Client ID + REVERSED_CLIENT_ID)
- [ ] `REVERSED_CLIENT_ID` added to `Info.plist` under `CFBundleURLTypes`
- [ ] iOS Client ID registered in Supabase Dashboard: Authentication > Providers > Google
- [ ] "Skip nonce check" enabled in Supabase Google provider settings (required for native iOS)
- [ ] GoogleSignIn-iOS 9.1.0 added via SPM

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ObservableObject` + `@EnvironmentObject` | `@Observable` + `@Environment` | iOS 17 / Swift 5.9 | Less boilerplate, finer-grained re-renders |
| Google OAuth via `SFSafariViewController` | Native `GIDSignIn` + `signInWithIdToken` | Supabase native mobile auth support (2023) | No web redirect; no deep link URL scheme needed for auth callback |
| Manual `getSession()` on app launch | `authStateChanges` `.initialSession` event | Supabase Swift SDK 2.x | SDK handles restoration automatically via Keychain |
| `@StateObject` in root App | `@State private var model = MyModel()` with `@Observable` | Swift 5.9 / iOS 17 | `@State` works for `@Observable` root models in `App` |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build | Yes | 26.3 (Build 17C529) | — |
| supabase-swift | Auth, DB | Yes (pinned) | 2.42.0 | — |
| GoogleSignIn-iOS | Google OAuth | No (not yet added) | — | Add via SPM before coding |
| AuthenticationServices | Sign in with Apple | Yes (system) | iOS 17+ | — |
| Secrets.plist | SupabaseClient init | Unknown (gitignored) | — | Must be created manually with real keys |

**Missing dependencies with no fallback:**
- `Secrets.plist` — must be created before any Supabase call will succeed. Fatal error thrown if missing.

**Missing dependencies with fallback:**
- `GoogleSignIn-iOS` — not yet added to the project. Must be added via SPM (File > Add Package Dependencies). No alternative; required for Google Sign-In.

---

## Open Questions

1. **Supabase project URL and keys**
   - What we know: Keys must go in `Secrets.plist`; the existing Legacy web app Supabase project is being reused
   - What's unclear: Developer must manually create `Secrets.plist` with real keys before Phase 1 can run in Simulator
   - Recommendation: Plan must include a "create Secrets.plist" task as the first wave

2. **`emitLocalSessionAsInitialSession` flag**
   - What we know: A Supabase SDK config flag `emitLocalSessionAsInitialSession: true` exists that "ensures the locally stored session is always emitted"
   - What's unclear: Whether this is on by default in SDK 2.42.0 or requires explicit opt-in
   - Recommendation: Test behavior on first cold launch after sign-in. If `.initialSession` does not fire with a non-nil session, add this flag to `SupabaseClientOptions`. Confidence: LOW (single source, not verified in SDK source).

3. **Google Cloud Console setup**
   - What we know: An iOS OAuth Client ID must be created; the REVERSED_CLIENT_ID goes in Info.plist
   - What's unclear: Whether the Legacy web app's Google OAuth client can be reused or if a new iOS-type client is required
   - Recommendation: Create a new iOS-type OAuth client ID in Google Cloud Console. Web client IDs do not work for native iOS sign-in.

---

## Sources

### Primary (HIGH confidence)
- https://supabase.com/docs/guides/auth/social-login/auth-apple?platform=swift — Sign in with Apple flow, entitlements, signInWithIdToken
- https://supabase.com/docs/guides/auth/social-login/auth-google — Google OAuth native iOS, Info.plist, signInWithIdToken
- https://supabase.com/docs/reference/swift/auth-onauthstatechange — authStateChanges async stream, event types
- https://supabase.com/docs/guides/getting-started/tutorials/with-swift — Official SwiftUI session management pattern (isAuthenticated routing)
- https://github.com/supabase/supabase-swift/blob/main/Sources/Supabase/SupabaseClient.swift — Confirmed `Sendable` conformance, `LockIsolated` internal state
- https://github.com/google/GoogleSignIn-iOS/releases — Confirmed v9.1.0 latest (released 2025-01-08), Swift 6 support added

### Secondary (MEDIUM confidence)
- https://supabase.com/blog/native-mobile-auth — Native mobile auth approach, ID token pattern
- https://developers.google.com/identity/sign-in/ios/sign-in — GIDSignIn.sharedInstance.signIn, URL handling
- https://deepwiki.com/supabase/supabase-swift — Auth token propagation, session management internals

### Tertiary (LOW confidence)
- GitHub discussion #35158 (supabase/supabase) — `emitLocalSessionAsInitialSession` flag; needs validation in SDK 2.42.0

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified against official sources; versions confirmed
- Architecture patterns: HIGH — patterns taken directly from official Supabase Swift tutorial and SDK source
- Pitfalls: HIGH (Apple/Google config), MEDIUM (Swift 6 edge cases) — Apple name pitfall documented in official Apple docs; Swift 6 @MainActor requirement verified by Swift compiler behavior
- Session persistence: MEDIUM — confirmed via authStateChanges docs; `emitLocalSessionAsInitialSession` flag needs runtime validation

**Research date:** 2026-03-23
**Valid until:** 2026-06-23 (stable APIs — 90 days; GoogleSignIn-iOS and Supabase SDK versioned)
