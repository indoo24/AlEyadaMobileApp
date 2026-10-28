# AlEyada Mobile — Production Readiness & Scalability Audit

| | |
|---|---|
| Audit date | 2026-10-26 |
| Branch audited | `branch-one` @ `0f95248` (working tree) |
| Uncommitted changes | `pubspec.yaml` only: `version: 1.0.0+1` → `1.0.1+2`. Left untouched. |
| Remote state | Local branch is **1 commit behind** `origin/branch-one` (`68bfebf`, a README rewrite). Source code is identical; the newer README was read with `git show` for reference. |
| Toolchain used | Flutter 3.44.9 stable, Dart 3.12.2, Java 17.0.12, Windows 11 |
| CI toolchain pin | Flutter 3.44.8 (`ci/github-actions-ci.yml`) — one patch behind the local toolchain |
| Method | Static reading of `lib/`, `test/`, `android/`, `ios/`, `ci/`, `pubspec.*`, `Aleyada API.yaml`; running `pub get`, `analyze`, `test` and a release app-bundle build. No source, test, config or dependency file was modified. |

**Labels used below.** *Confirmed* = shown by the code or a command run during this audit. *Suspected* = the code makes it likely, but it was not reproduced at runtime. *Unverified* = it depends on the backend, a store, a device or credentials this audit could not access.

---

## 1. Executive summary

### Overall assessment

The Flutter client is **well engineered for its size**. The transport, session and routing layers are carefully done, the test suite is large (910 passing tests) and runs offline, static analysis is clean, and many security and privacy details are already handled correctly. In client code quality it is above average.

It is **not ready for a public production release**. The blockers are mostly not code-quality problems. They are in three areas:

1. **The core booking flow depends on things outside this repository that, as far as the repository records, are not in place.** The backend refuses bookings from accounts without a verified phone. The app's own source (`otp_screen.dart`) and README both state that the backend has **no SMS provider**, so OTP codes are only written to a server log. If that is still true, no new patient can verify a phone, so no new patient can book.
2. **Store-policy requirements are missing.** There is no in-app account deletion, and the OpenAPI spec has no endpoint for it. Google Play and the App Store both require this for apps that let users create accounts. After sign-up there is also no in-app link to the privacy policy.
3. **Operational readiness is close to zero.** CI exists only as a file that is not enabled (`ci/`, not `.github/workflows/`). There is no crash or error reporting. A release build silently falls back to the debug signing key when `key.properties` is missing. iOS has never been built or verified.

### What is already solid (confirmed)

- **Token handling.** Tokens are kept in Keystore/Keychain (`flutter_secure_storage`, `first_unlock_this_device`) and never in SharedPreferences. Refresh is single-flight, so concurrent 401s cause one refresh, and the rotated refresh token is stored. A network failure during refresh does not log the user out.
- **Error mapping.** Every failure becomes one `ApiException` type keyed on backend error codes, never on prose. Network errors are never reported as sign-outs. There are distinct messages for 401, 403, 404, 409, 429 and 5xx.
- **Booking-sheet submit guard.** One request per confirmation, however many taps (tested). The server's response is rendered, not assumed. 409 and the slot-conflict codes clear the slot and refetch availability. A 403 re-reads `/auth/me/` to show phone verification instead of a bare "no permission". The `clinic` id is always sent.
- **Session isolation.** User-scoped providers rebuild on account change. Favourites and recent searches are stored per account. `next` redirects are validated (`safe_redirect.dart`) and dropped when a different account signs in.
- **Android hardening.** No cleartext in release (`network_security_config.xml`). Backup and device transfer are fully excluded. `INTERNET` is the only permission. Deep links are explicitly disabled. R8 and resource shrinking are on.
- **Link safety.** Contact links from the API are validated before launch (`contact_links.dart`: only `tel:` numbers; only `https` WhatsApp hosts).
- **Logging.** Logging can never run in production (`Env.verboseLogging` requires a non-production environment), and it records only method, path, status and error codes.
- **Localization and layout tests.** Arabic is the template locale and English the translation. CI checks that the generated localizations are current. Widget tests cover layout at several phone widths and at 1.6× text scale in both languages.

### Most serious risks

| # | Risk | Priority |
|---|---|---|
| 1 | OTP/SMS delivery not configured, which blocks phone verification and so blocks every new patient's first booking | P0 (unverified, needs backend confirmation) |
| 2 | No account deletion (store rejection) | P0 |
| 3 | A booking whose response is lost (timeout or disconnect) is shown as a plain network error. The list is not refreshed, and a retry can create a second booking or show a misleading "doctor busy" | P1 |
| 4 | No crash or error reporting, so production failures are invisible | P1 |
| 5 | CI not enabled, and release signing silently falls back to the debug key | P1 |
| 6 | A 5xx or 429 from `/auth/token/refresh/` ends the user's session | P1 |
| 7 | Production API and management URLs point at `*.scenariomnchnl.tech` and must be confirmed as the intended production hosts | P1 (unverified) |

### Why a confident readiness claim cannot be made

- No live backend was exercised. Every API flow was checked against code, test fakes and an OpenAPI file that is **known to differ from the live API** in at least one place (finding F-17).
- The app was not run on any device. Performance, accessibility with screen readers, and real-device RTL behaviour are unmeasured.
- No crash or analytics data exists, so the app's real-world failure rate is unknown.

---

## 2. Readiness scorecard

Scores are assessments based on the evidence in this report. They are not proof of readiness. **The P0 items in §3 override any average.**

| Category | Score | Evidence |
|---|---:|---|
| Architecture | 78 | Clear `core/` and `features/<x>/{models,repository,providers,screens}` layering; one transport; one state approach (Riverpod); endpoints listed in one file. Against: several 1,000+ line UI files; legacy `StateNotifier` APIs. |
| Scalability (client) | 60 | Search is debounced and cancellable, with generation guards and dedup. Against: My Bookings walks up to 10 pages sequentially on every refresh; non-auto-dispose family caches grow without bound. |
| Security | 70 | Secure token storage, no secrets in source or git history, no cleartext, validated deep-link and contact inputs. Against: no screenshot/recents protection for health data; a silent debug-signing fallback. |
| Authentication | 70 | Single-flight refresh, rotation, network-vs-auth distinction, consent gating. Against: 5xx/429 on refresh logs the user out; `refreshUser` and account-switch race; sign-out blocks on the network. |
| API reliability | 65 | Unified error normalization, timeouts, cancellation in search and availability. Against: no handling of uncertain non-idempotent outcomes; repo OpenAPI drifts from the live contract. |
| Booking correctness | 50 | Good guards and conflict handling (tested). Against: lost-response path, no idempotency, 409 alternative slots ignored, and the whole flow gated on an SMS provider that may not exist. |
| Data consistency | 72 | Account-keyed providers and explicit invalidation after mutations. Against: detail caches never expire; no refresh on app resume; a small race in `refreshUser`. |
| Performance | 60 (unmeasured) | Thumbnails use `cacheWidth`; lists are lazy; there is a debounce. Against: no disk image cache; sequential pagination; no profiling evidence at all. |
| Testing | 75 | 910 tests pass offline; contract, unit and widget tests; tests for double-tap, 401, 403 and 409 on booking. Against: no integration or device tests, no coverage measurement, no test for a lost booking response. |
| Android release readiness | 45 | The release AAB builds (§6). Against: debug-key fallback, no account deletion, no crash reporting, Data Safety disclosures unverified. |
| iOS readiness | 20 | The project exists, but the README says it has never been built. No signing team, bundle id differs from Android, no `PrivacyInfo.xcprivacy`. Could not be built on Windows. |
| CI/CD | 15 | The workflow file exists but is not enabled, only triggers on `main` (work happens on `branch-one` and `develop`), and produces a debug-signed APK. |
| Observability | 10 | No crash reporting, no non-fatal reporting, no API failure monitoring. The app version is not shown in the UI. |
| Privacy | 50 | Strong local-storage and backup hygiene; notes marked private. Against: no account or data deletion, no in-app privacy policy after sign-up, no recents-screenshot protection, Data Safety form unverified. |
| Accessibility | 65 | Clamped text scaling (0.85–1.6×) with layout tests, 44–48 dp targets in the areas sampled, semantics on loading states, contrast tests on the palette. TalkBack/VoiceOver not run. |
| Localization | 82 | Complete ar/en ARB with a CI staleness check; RTL from the locale. Minor: one unlocalized string (`router.dart` 404 page); backend `detail` prose may arrive in either language. |
| Documentation | 70 | Detailed README with honest limitations; CI README. Against: local README is behind remote; the in-repo OpenAPI is not authoritative; no release runbook. |

---

## 3. Findings

Format: **ID — Priority — Category — Status**.

### P0 — Release blockers

#### F-01 — P0 — Booking / Auth — Unverified (strong code evidence)
**Phone verification depends on an SMS provider the repository says does not exist, so new patients cannot book.**

- **Where:** `lib/features/auth/otp_screen.dart` lines 20–24 (comment); `lib/features/bookings/booking_sheet.dart` `_confirm()` lines 224–228 and `_startPhoneVerification()`; README "Known limitations" ("the backend lacks an SMS provider").
- **Evidence:** The OTP screen states: *"the backend has no SMS provider wired up yet (only a console delivery that writes the code to the service log) … until then nobody receives a code by SMS."* The booking sheet refuses to submit while `isPhoneVerified == false` and starts OTP instead, matching the backend's `is_phone_verified` requirement. Sign-up also routes straight to OTP (`sign_up_screen.dart:97`). Password reset uses the same OTP channel.
- **Risk:** Every newly registered patient is stuck at the verification step, so **the core booking flow is unusable for new users**. Password reset is also impossible.
- **Impact:** The product's primary conversion path fails at launch.
- **Fix:** A backend or infrastructure task: configure a production SMS provider for Egyptian numbers and test delivery end to end. Client-side, nothing needs to change; the flow is already real and has no bypass, which is correct.
- **Effort:** Backend 1–3 days, plus provider onboarding and sender-ID approval, which can take weeks for some providers.
- **Tests required:** A manual end-to-end check on a real SIM for sign-up, booking verification and password reset; a rate-limit (429) message check.
- **Depends on:** The backend owner, an SMS provider account and budget.

#### F-02 — P0 — Privacy / Store policy — Confirmed
**No account deletion in the app or in the API.**

- **Where:** `lib/features/profile/account_screen.dart` (actions: edit profile, notifications, management, language, appearance, sign out — nothing else); `Aleyada API.yaml` (no delete/erase route under `/auth/`, `/patients/` or elsewhere).
- **Evidence:** Grep for deletion flows in `lib/` returns nothing. The spec's `/api/v1/auth/*` routes are login, logout, me, otp, password and register only.
- **Risk:** Google Play's account-deletion policy requires apps that allow account creation to offer deletion **in the app and via a web link**. App Store Review Guideline 5.1.1(v) requires in-app deletion. Both stores reject submissions without it. This is a health app that holds booking history and notes, which raises the stakes.
- **Fix:** Backend: add a deletion or deletion-request endpoint and define the retention rules for bookings and medical records (for example, anonymise rather than hard-delete where law requires retention). App: add "Delete account" under Account with confirmation and re-authentication, then a full local wipe (tokens, favourites, recent searches). Publish the web deletion URL in the Play Console.
- **Effort:** Backend 2–4 days plus legal input; app about 1 day.
- **Tests required:** A widget test for the confirmation flow; a test that local per-account keys are removed; a backend test for anonymisation.
- **Depends on:** Backend owner and a legal/privacy decision on retention.

### P1 — High

#### F-03 — P1 — Booking correctness / API reliability — Confirmed (client behaviour); backend idempotency unverified
**A booking whose response is lost is reported as a plain failure, and the retry path can mislead or duplicate.**

- **Where:** `lib/features/bookings/booking_sheet.dart` `_confirm()` lines 238–281; `lib/features/bookings/repository.dart` `create()`; `lib/core/config/env.dart` (`receiveTimeout` 20 s).
- **Evidence:**
  - `POST /doctors/{slug}/book/` carries no idempotency key or client request id.
  - On `ApiFailure.network` (timeout, or a disconnect after the request left the device), the `catch` sets `_error = errorNetwork`.
  - `myBookingsProvider` is **not** invalidated on that path (it is invalidated only on success), and the slot stays selected.
  - The patient can tap *Confirm* again. If the first request was in fact committed, the backend now sees the doctor as booked at that time and, per the spec, answers **409**. The app shows "the doctor is busy", marks the slot refused, and invites the patient to pick another time.
  - If they do, **a second real booking is created.** Whether the backend's `too_many_active_bookings` limit prevents this depends on its configuration (unverified).
  - The sheet never says "your booking may have gone through — check My Bookings".
- **Risk:** Duplicate bookings, misleading errors, and patients who think they have no appointment when they do (no-shows).
- **Fix:**
  1. Treat a network failure on create as **uncertain**: show a dedicated message ("We couldn't confirm whether the booking went through"), invalidate and reload `myBookingsProvider`, and look for a booking at `slot.id` / `start_at` before allowing a retry.
  2. Backend: accept an `Idempotency-Key` header (client generates a UUID per confirm attempt and reuses it on retry), or return the existing booking when the same patient re-books the same slot.
  3. Never auto-retry this POST.
  The existing 401 → refresh → replay is safe, because a 401 means the request was rejected before the view ran.
- **Effort:** App 0.5–1 day; backend 1 day.
- **Tests required:** A widget test where the fake server records the booking and then throws `connectionError` or `receiveTimeout`: assert the uncertain-state message, the My Bookings refetch, and no blind second POST.
- **Depends on:** Backend support for idempotency (recommended).

#### F-04 — P1 — Authentication — Confirmed
**A server error or throttle on token refresh ends the session.**

- **Where:** `lib/core/api/api_client.dart` `_onError()` lines 83–99.
- **Evidence:** Only `refreshFailure.isNetworkFailure` keeps the session. Any other `ApiException` from `/auth/token/refresh/`, including **502/503 during a deploy, 500, or 429**, clears the tokens and fires `onSessionExpired`.
- **Risk:** Every user whose access token expires during a short backend outage, or who hits a refresh throttle, is signed out and must re-enter a password. Without SMS (F-01) they also cannot reset a forgotten password.
- **Fix:** End the session only on a genuine rejection: 401, or 400 with a token-invalid code. For 5xx, 429 and unexpected shapes, keep the tokens and surface a server or network error, as `restore()` already does.
- **Effort:** 1–2 hours plus tests.
- **Tests required:** Extend `test/unit/api_refresh_test.dart` with refresh returning 503 and 429, and assert the tokens are kept and `onSessionExpired` is not called.

#### F-05 — P1 — Observability — Confirmed
**No crash, error or performance reporting.**

- **Where:** `lib/main.dart` (no `FlutterError.onError`, `PlatformDispatcher.instance.onError` or zone handler); `pubspec.yaml` (no reporting SDK); README "Analytics and crash reporting are not configured".
- **Risk:** Crashes, uncaught async errors, booking failures and API error spikes in production are invisible. There is no way to know whether F-03 or F-04 happen in practice.
- **Fix:** Choose a provider (Firebase Crashlytics, or Sentry, which can be self-hosted for health data). Wire the global error hooks. Scrub PII: no request bodies, no notes, no phone numbers or names. Tag with app version, build and environment. Upload R8 mappings and `--split-debug-info` symbols per release. Update the privacy policy and the Play Data Safety form.
- **Effort:** 1–2 days including the privacy review.
- **Depends on:** A provider decision and a privacy-policy update.

#### F-06 — P1 — CI/CD — Confirmed
**CI is not running.**

- **Where:** `ci/github-actions-ci.yml`, `ci/README.md`; there is no `.github/` directory.
- **Evidence:** The workflow was deliberately kept out of `.github/workflows/` because the token lacked the `workflow` scope. Even when enabled, it triggers only on `main`, while active work is on `branch-one` and `develop`. It builds a **debug-signed** APK, not an AAB.
- **Risk:** Formatting, analysis, test and l10n regressions can land unnoticed. No reproducible release artifact exists.
- **Fix:** Enable the workflow and add `develop` and feature branches to the triggers. Add a separate, manually triggered release job that builds a signed AAB using secrets (keystore as base64, passwords as encrypted secrets) and uploads R8 mappings and debug symbols. Align the Flutter pin with the local toolchain (3.44.8 vs 3.44.9).
- **Effort:** 0.5–1 day.

#### F-07 — P1 — Android release — Confirmed
**A release build silently falls back to the debug signing key.**

- **Where:** `android/app/build.gradle.kts` lines 13–23 and 62–69.
- **Evidence:** When `android/key.properties` is absent, the build only logs a warning and signs `release` with the debug key. Locally, `key.properties` **does exist and is git-ignored** (verified with `git check-ignore`; contents not read).
- **Risk:** An APK built on another machine or in CI and handed out directly (testers, sideloading, a clinic demo) is debug-signed. Users who install it can never upgrade to the Play-signed build without uninstalling, which loses their local favourites and session. Play rejects a debug-signed upload, but sideloaded copies get no such check.
- **Fix:** Fail the `release` build when signing properties are missing, unless an explicit `-PallowDebugSignedRelease=true` (or an environment variable) is set, which CI's smoke build passes. Do **not** replace or regenerate the existing upload key. Back it up offline.
- **Effort:** 1 hour.

#### F-08 — P1 — Configuration / Environment — Unverified
**Production endpoints must be confirmed.**

- **Where:** `lib/core/config/env.dart` lines 33–51.
- **Evidence:** The default (production) API is `https://aleyada.scenariomnchnl.tech/api/v1`. The doctor's "open the management system" URL defaults to `https://scenariomnchnl.tech/`, the bare root of what looks like a vendor domain rather than an AlEyada management path. There are only two environments (`development`, `production`) and no staging.
- **Risk:** Shipping against a non-production or vendor-hosted backend, or sending doctors to the wrong website. Changing the API host later requires an app update, because the value is compiled in.
- **Fix:** Confirm the final production hosts with the backend and infrastructure owner. Set them explicitly per build (`--dart-define`) in the release job. Add a `staging` environment. Consider showing the environment and version on the Account screen in non-production builds.
- **Effort:** Hours, once the hosts are known.

#### F-09 — P1 — Privacy / Store policy — Confirmed (absence); compliance unverified
**The privacy policy and terms cannot be reached after sign-up, and third-party data flows are undocumented.**

- **Where:** `lib/features/profile/account_screen.dart` (no policy, terms, support or about entries); policies are shown only during registration and re-acceptance (`sign_up_screen.dart`, `consent_screen.dart`).
- **Risk:** Play's User Data policy expects the privacy policy to be reachable from inside the app for apps that handle personal or sensitive data. Users cannot review what they agreed to. There is no support contact for a health app.
- **Fix:** Add Account → "Privacy policy", "Terms", "Contact support" and "App version". Reuse `/legal/policies/current/` (already called) or a hosted URL. Fill the Play Data Safety form: phone, name, email, health-related booking notes, and URLs opened in WhatsApp.
- **Effort:** About 0.5 day in the app, plus legal review of the text.

#### F-10 — P1 — iOS readiness — Confirmed (configuration); build unverified
**iOS has never been built or verified.**

- **Where:** `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`; README §iOS ("has not been [built]").
- **Evidence:**
  - `PRODUCT_BUNDLE_IDENTIFIER = com.aleyada.aleyadaMobile`, while Android uses `com.aleyada.app`.
  - No `DEVELOPMENT_TEAM`.
  - No app-level `PrivacyInfo.xcprivacy`; `shared_preferences` uses `UserDefaults`, a required-reason API, so the app's own manifest should declare it.
  - The iPad orientation list includes upside-down, while the phone list does not.
  - The build could not be attempted on this Windows host.
- **Risk:** Applies only if iOS is in the launch scope: App Store Connect rejection, plus untested Keychain, RTL and `url_launcher` behaviour.
- **Fix:** Decide whether iOS is in scope for v1. If it is: settle the bundle id, add a signing team, add a privacy manifest, build and test on a device, and add the same account deletion (F-02).
- **Effort:** 2–4 days on a Mac with an Apple Developer account.

### P2 — Medium

| ID | Category | Status | Where | Finding | Fix | Effort |
|---|---|---|---|---|---|---|
| F-11 | Auth / data consistency | Suspected | `core/auth/auth_controller.dart` `refreshUser()` 260–277, `restore()` | An in-flight `/auth/me/` started under account A that completes after sign-out, or after B signs in, writes `state = authenticated(A)` regardless. `showBookingSheet` and Home pull-to-refresh fire `refreshUser()` unawaited, so the overlap is possible on slow networks (timeouts of 15/20 s). Result: wrong identity shown, or "signed in" with no tokens. | Capture a session generation or the current refresh token before the call, and discard the result if it changed. | 2 h + test |
| F-12 | Auth / UX | Confirmed | `profile/account_screen.dart` `_confirmSignOut`; `auth_controller.dart` `signOut()` | Sign-out awaits the server `logout` call before clearing locally, with no busy indicator. On a poor network the user waits up to the connect/receive timeout and can tap again, sending a second logout. | Clear locally first (or in parallel), fire logout best-effort with a short timeout, and show a busy state. | 1 h |
| F-13 | Booking / UX | Confirmed | `booking_sheet.dart` 39–43, 169–171 | `PopScope(canPop: !submitting)` does not stop a drag-dismiss of the modal sheet (the code acknowledges this at line 39). A booking that completes after the sheet is swiped away gives no visible confirmation; only the list is invalidated. | Show a global SnackBar or route to Booking Details when a create completes with the sheet unmounted, or set `enableDrag`/`isDismissible` false while submitting. | 1–2 h |
| F-14 | Booking | Confirmed | `booking_sheet.dart` `_confirm()` 272–276; spec `doctors_book_create` | The 409 response "carries nearby free slots", and the app ignores them. It refetches availability, which may already lack those alternatives. | Parse the alternative slots from the 409 body and offer them in the sheet. | 0.5 day |
| F-15 | Phone verification | Suspected | `auth/otp_screen.dart` 89–114 | When verification is started from booking and the verify response carries no tokens, the screen does `context.go('/sign-in')`. The guest-only guard bounces a signed-in user to Home, and `isPhoneVerified` is not refreshed, so the doctor context (`next`) is lost. | When a session exists, call `refreshUser()` and honour `next` instead of going to sign-in. | 1 h + test |
| F-16 | Client scalability | Confirmed | `bookings/providers.dart` `myBookingsProvider` 113–137 | Each load or invalidation walks **up to 10 sequential pages of 50** (500 bookings), and silently truncates beyond that, regardless of which tab is shown. The cost grows with history, and every create or cancel triggers a full re-walk. | Fetch the upcoming section with a server filter (ask the backend for `status`/`upcoming` filters) and paginate *Past* lazily. | 1 day + backend filter |
| F-17 | API contract | Confirmed | `Aleyada API.yaml` 4595–4637 vs `bookings/models.dart` `DoctorAvailability.fromJson`; `test/fixtures/doctor_detail_fixtures.dart:173` | The spec says availability returns an **array** of `AvailabilityDay`. The client parses an **object** (`booking_enabled`, `days`, …), and the fixtures note "the live object shape". If the server ever matched the spec, `unwrapObjectOrNull` would return null and every doctor would silently show as contact-only. The in-repo spec is therefore not a reliable contract, so `contracts_test.dart` checks fixtures rather than the real API. | Regenerate the OpenAPI from the live backend, commit it, and add a CI check (or a staging smoke test) that validates fixtures against it. | 0.5 day + backend |
| F-18 | Memory / staleness | Confirmed | `doctors/providers.dart` `doctorDetailProvider`, `doctorPageProvider`; `bookings/providers.dart` `bookingDraftProvider` | Non-`autoDispose` families keep every visited doctor profile and every distinct query for the whole process lifetime. Fees, clinics and contact numbers are never refetched unless the user pulls to refresh. | `autoDispose` with `keepAlive` plus a TTL (for example 5–10 minutes), or invalidate on app resume. | 0.5 day |
| F-19 | Recovery | Confirmed | No `WidgetsBindingObserver`/`AppLifecycleListener` anywhere in `lib/` | Nothing refreshes on resume. My Bookings, booking status (cancelled by clinic) and the unread badge stay stale until manual refresh. There is no push (README). | On resume after more than N minutes, invalidate the bookings list, the unread count, and `refreshUser()`. | 2–4 h |
| F-20 | Privacy (health) | Confirmed | `android/.../MainActivity.kt` (plain `FlutterActivity`) | Booking details, notes and names appear in the Android recents thumbnail and can be screenshotted. | Consider `FLAG_SECURE` on sensitive screens (booking details and the sheet), or at least in recents. This is a product decision, because it also blocks user screenshots. | 2 h |
| F-21 | Roles | Confirmed (behaviour); intent unverified | `app/router.dart` `_homeFor`; `app/shell.dart`; `core/auth/models.dart` `isStaff` (unused) | Users with `role == assistant` (and admin) get the patient UI. There are no assistant screens, even though the app manages assistants and their permission flags. | Confirm scope with the product owner. If assistants should use the app, design that experience; otherwise show an explicit "use the web dashboard" message. | Product decision |
| F-22 | Maintainability | Confirmed | `booking_sheet.dart` (1,220 lines), `doctor_profile_sections.dart` (1,240), `booking_detail_screen.dart` (1,078), `schedule_screen.dart` (883) | Several private widgets and the submit logic live in one file. Business logic (`_confirm`) sits inside widget state, which makes it hard to unit-test without a widget harness. | Move booking submission into a controller (`BookingSubmitController`), and split the sheet's sub-widgets into `bookings/widgets/`. | 1–2 days |
| F-23 | Dependencies | Confirmed | `pubspec.yaml` / `pubspec.lock`; `pub get` output | `flutter_riverpod` 2.6.1 (the `StateNotifier` API is legacy in Riverpod 3); `go_router` 14.8.1; `flutter_secure_storage` 9.2.4 (later majors change Android storage); "35 packages have newer versions incompatible with dependency constraints". | No blind upgrades. Plan a Riverpod 3 migration only with test coverage; upgrade `flutter_secure_storage` with a token-migration test on a real device. | Per package |
| F-24 | Navigation / perf | Confirmed | `app/router.dart` `ShellRoute` | Tabs are a plain `ShellRoute`, so switching tabs rebuilds the screen and loses scroll position and local state. | `StatefulShellRoute.indexedStack`. | 0.5 day |
| F-25 | Data | Confirmed | `favorites/providers.dart` | Favourites are device-local only (there is no backend endpoint), so they are lost on reinstall or a new phone. While the app is `offlineWithSession` (user null), favourites read and write the **guest** list. | Accept as a known v1 limit, or add a server endpoint. Key by the stored account id while offline. | — |
| F-26 | Network / perf | Confirmed | `doctor_profile_sections.dart:1031`; all `Image.network` | No on-disk image cache, so images re-download after each launch. One `Image.network` decodes at full resolution (no `cacheWidth`). | Add `cacheWidth` everywhere. Consider `cached_network_image` after a privacy review (it writes images to disk). | 2 h |
| F-27 | Build / CI | Confirmed | `android/gradle.properties` | `org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G` can exceed the memory of smaller CI runners. | Use 4G in CI via `GRADLE_OPTS`, or lower it globally after measuring. | 15 min |
| F-28 | Notifications | Confirmed | `notifications/notifications_data.dart` `unreadCountProvider` | Watches the whole `authControllerProvider`, so every auth state change (every booking-sheet open calls `refreshUser`) refetches the count, including a request while signed out (which fails with 401 and is swallowed). | Watch `(hasSession, user?.id)` only, and return 0 without a request when signed out. | 30 min |

### P3 — Low

| ID | Where | Finding |
|---|---|---|
| F-29 | `app/router.dart:194` | `errorBuilder` shows a hard-coded, unlocalized `'404 — <uri>'` that echoes the route. |
| F-30 | `auth/otp_screen.dart:84–85` | Password-reset success reuses `accountSaved` and navigates with the string `'/sign-in'` instead of `Routes.signIn`. |
| F-31 | `core/api/api_error.dart` `ApiError.fromJson` | Hard `as String` casts: a non-string `code` or `detail` throws a `TypeError`, which escapes the `ApiException` handling at most call sites. |
| F-32 | `core/api/api_client.dart` `_onError` replay | Replaying a multipart `FormData` after a 401 refresh fails, because `FormData` cannot be re-sent. Latent: no upload screen exists yet. |
| F-33 | `management/repository.dart` `availabilityWindows()` | Requests `page_size=100` and ignores pagination, silently truncating at 100 windows. |
| F-34 | repo root | `assets/Navy Heartbeat A Icon.png` (876 KB) is tracked but not bundled; `assets/brand/` is empty (store artwork missing). |
| F-35 | `core/api/api_error.dart` `fromDio` | A cancelled request maps to `ApiFailure.unexpected`. Current callers drop cancelled results through generation checks; a future caller could show "something went wrong" for a cancellation. |
| F-36 | Endpoints | Defined but unused: reschedule (`BookingRepository.reschedule` wired, no UI), payment-proof, reviews create/reviewable, claim requests, `publicSettings`, `patientProfile`, `home`. These are documented in the README as unbuilt. Not a defect, but the dead code should be tracked. |

---

## 4. Production blockers checklist

- [ ] **F-01** Confirm a production SMS provider delivers OTP to real Egyptian numbers for sign-up, booking verification and password reset.
- [ ] **F-02** Account deletion: backend endpoint, in-app flow and web URL for Play.
- [ ] **F-03** Handle an uncertain booking outcome without risking duplicates (and backend idempotency, recommended).
- [ ] **F-04** Stop logging users out on a 5xx or 429 from token refresh.
- [ ] **F-05** Crash and error reporting with PII scrubbing.
- [ ] **F-06 / F-07** CI enabled; a signed release AAB built reproducibly; no silent debug-key fallback.
- [ ] **F-08** Production API and management URLs confirmed and set explicitly in the release build.
- [ ] **F-09** Privacy policy, terms and support reachable in the app; Play Data Safety form completed.
- [ ] **F-10** (Only if iOS ships in v1) iOS build, signing and privacy manifest verified on a device.
- [ ] A manual end-to-end pass on at least two physical Android devices (one older or low-RAM) against the production or staging backend.

---

## 5. Scalability risks

### A. Flutter client

| Area | Status | Notes |
|---|---|---|
| Feature modularity | Good | Feature folders with their own models, repository and providers; one shared `core/`. Several developers can work in parallel with few conflicts, except in the largest files (F-22) and the shared ARB files. |
| State management | Good, with legacy API | Riverpod throughout, with account-scoped rebuilds. `StateNotifier`/`StateProvider` are legacy in Riverpod 3 (F-23). |
| API abstraction | Good | One `ApiClient`, one envelope decoder, endpoints listed in one place. Repositories are thin and testable through Dio adapter substitution. |
| Contract safety | Weak | Hand-written DTOs against an OpenAPI that has drifted (F-17); no generated client or schema validation in CI. |
| Booking statuses | Adequate | Unknown statuses parse to `unknown` and land in *Past*, so a new backend status never crashes but may be misfiled. Confirm with the backend before adding statuses. |
| Lists | Mixed | Doctor search: paginated, debounced, cancelled, deduplicated. My Bookings: full sequential walk (F-16). Notifications and reviews: paged on demand. |
| Caches | Weak | Unbounded families with no TTL (F-18). |
| Build complexity | Low | 6 runtime dependencies. No code generation except l10n. |

### B. Backend-dependent (questions for the backend owner)

The mobile client cannot show backend capacity. **No load-test evidence was available, so no concurrent-user number can be claimed.**

1. Is `POST /doctors/{slug}/book/` protected against double submission? Is there a unique constraint on (slot) or (doctor, start_at) under concurrency, and would it accept an `Idempotency-Key`?
2. What does the backend return when the same patient re-books a slot they already hold?
3. Are availability responses cached? Every sheet open calls `/availability/` without a date range, so the server's default window determines the payload size.
4. What are the throttle rates for login, OTP, refresh, search and booking, and does `/auth/token/refresh/` throttle (see F-04)?
5. Can `GET /bookings/` filter by upcoming and past, so the client stops walking pages (F-16)?
6. Is search (`/doctors/?search=`) indexed for Arabic text (normalised alef and taa marbuta) at the expected doctor volume?
7. Which SMS provider will be used, and what are its throughput and cost limits (F-01)?
8. Is the in-repo `Aleyada API.yaml` generated from the deployed version? (F-17 suggests it is not.)
9. Is there a staging environment the app can be pointed at for pre-release testing?
10. Does the backend send any personal data to third parties (SMS provider, email, analytics)? This must be reflected in the privacy policy.

---

## 6. Test and build results

All commands ran from the repository root on 2026-10-26 with Flutter 3.44.9.

| Command | Result | Notes |
|---|---|---|
| `git status` / `git diff` | Run | Only `pubspec.yaml` modified (version bump). Local branch 1 commit behind origin. Unchanged after all commands. |
| `git check-ignore android/key.properties android/local.properties` | Run | Both ignored (`android/.gitignore`). No keystore or `key.properties` appears in any commit (`git log --all`). |
| `flutter pub get --enforce-lockfile` | **Passed** | The lockfile matches `pubspec.yaml`; no lock changes. "35 packages have newer versions incompatible with dependency constraints." |
| `flutter analyze` | **Passed** | "No issues found! (ran in 4.4s)" |
| `flutter test` | **Passed** | **910 tests, all passed** (about 53 s). |
| `flutter build appbundle --release` | **Passed** | `Built build\app\outputs\bundle\release\app-release.aab (56.8MB)` in about 143 s. No dart-defines, so it targets the default production URL (F-08). |
| `dart format --set-exit-if-changed` | Not run | CI runs it; skipped to avoid any chance of rewriting files. |
| `flutter gen-l10n` + diff | Not run | It writes into `lib/l10n/`; skipped to keep the audit read-only. CI covers it once enabled. |
| `flutter build ios` | **Not run** | Not possible on Windows. |
| Vulnerability scanner (OSV and similar) | **Not run** | No scanner available in this environment. |
| Coverage (`flutter test --coverage`) | Not run | No coverage number is claimed. |
| Integration or device tests | **Not run** | None exist in the repo (no `integration_test/`), and no device was attached. |

**Release build result:** The release AAB builds on this machine with R8 minification and resource shrinking enabled. The signing certificate (`keytool -printcert -jarfile`) is the upload key, owner `CN=AlEyada Upload, O=AlEyada`, **not** the debug key, because a local `key.properties` exists. This shows only that *this* machine can produce a signed bundle. A clean checkout or CI would silently produce a debug-signed build (F-07). The bundle was **not** installed or run, so release-only runtime behaviour under R8 (plugin channels, secure storage) is unverified on a device. 56.8 MB is the AAB, which contains every ABI and debug metadata; the per-device download size from Play will be smaller and was not measured.

---

## 7. Missing external verification

| Check | Why it could not be done | Needed |
|---|---|---|
| OTP/SMS delivery (F-01) | No backend or provider access | Backend owner; a real SIM test |
| Live API contract (F-17) | No live backend calls were made, deliberately (no credentials; production must not be touched) | Staging URL and test accounts |
| Booking idempotency and concurrency | Backend behaviour | Backend owner; a concurrency test on staging |
| Token lifetime and refresh throttling | Backend config | Backend owner |
| Production hostnames (F-08) | Infrastructure ownership | Infrastructure owner |
| Play Console: signing, Data Safety form, deletion URL, target-API compliance | No Play Console access | Release owner |
| iOS build, signing, Keychain behaviour (F-10) | Windows host; no Apple account | Mac with Xcode and an Apple Developer team |
| Real-device performance (startup, jank, memory on low-end Android) | No device | DevTools profiling (procedure below) |
| TalkBack / VoiceOver | No device | Manual accessibility pass |
| Privacy policy content vs actual data flows | Legal document not in repo | Legal or privacy owner |
| Dependency CVEs | No scanner | `osv-scanner --lockfile=pubspec.lock` in CI |

**Profiling procedure (for later):** `flutter run --profile` on a low-end Android device (2–3 GB RAM, Android 9–10). In DevTools, use the Performance tab to record (1) a cold start to the first Home frame, (2) fast scrolling of Search results through 3 or more pages, (3) opening the booking sheet and switching days and clinics, and (4) My Bookings with a seeded account of 200 or more bookings. Check frame build and raster times against the 16 ms budget, and use the Memory tab to watch heap growth while visiting 30 or more doctor profiles (this tests F-18). Repeat with network throttling (a "Slow 3G" proxy) to observe F-03 and F-12.

---

## 8. Prioritised remediation plan

| Phase | Items | Estimated effort | Dependencies |
|---|---|---|---|
| **A — Release blockers** | F-01 SMS provider; F-02 account deletion; F-03 uncertain-booking handling (app) plus idempotency (backend); F-04 refresh logout; F-08 production URLs | App about 2–3 days; backend about 4–8 days, plus SMS onboarding lead time | Backend owner, legal (retention), SMS provider |
| **B — High priority** | F-05 crash reporting; F-06 CI enabled plus signed release job; F-07 fail-closed signing; F-09 privacy, terms and support in app plus the Data Safety form; F-10 iOS decision | About 3–4 days | Provider choice, GitHub secrets, legal text |
| **C — Reliability and scalability** | F-11 auth race; F-12 sign-out; F-13 dismissed-sheet result; F-15 OTP return path; F-16 bookings pagination; F-17 regenerate spec plus contract check; F-18 cache TTL; F-19 resume refresh; F-28 unread-count churn | About 4–5 days | Backend filter for F-16; live spec for F-17 |
| **D — Quality and maintainability** | F-22 split large files and move booking submit into a controller; F-24 stateful shell; F-26 image caching; F-27 Gradle memory; F-14 409 alternatives; P3 items | About 3–4 days | — |
| **E — Long term** | F-21 assistant experience; F-25 server-side favourites; F-23 Riverpod 3 / go_router upgrades; push notifications (README: not built, no sender on the backend); staging environment; integration tests on a device farm | Multi-week | Product decisions, backend work |

Suggested order inside Phase A: **F-04** (smallest change, broad impact), then **F-03 app side**, then **F-02 app side** once the endpoint exists. F-01 and F-08 run in parallel on the backend side.

---

## 9. Final release verdict

**NOT READY — critical blockers remain.**

The client code is in good shape, and most of what follows can be fixed in days rather than weeks. But as of this audit:

- the booking flow is very likely blocked for every new patient by missing SMS delivery (F-01, still to be confirmed);
- the app would be rejected by the stores for missing account deletion (F-02);
- a lost booking response can mislead patients and risks duplicate bookings (F-03);
- production failures would be invisible (F-05), with no running CI and a signing setup that fails open (F-06, F-07).

Passing analysis and 910 tests shows the client behaves as its authors intended against fakes. It does not show that it works against the live backend, on real devices, or within store policy.
