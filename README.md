# AlEyada Mobile — العيادة

The Flutter client for the AlEyada medical directory. It is a **client of the
existing Django API and nothing else**: no second backend, no business rules of
its own, no duplicated validation. The server decides; this app presents the
result and explains it well.

- **Flutter** 3.44.8 (stable) · **Dart** 3.12.2
- **Backend** `https://aleyada.scenariomnchnl.tech/api/v1` (Django + DRF)
- **Web client** (independent, unchanged by this repo): Next.js at the same host

---

## Why it talks to Django directly

The website has its own BFF routes at `/api/auth/*`, `/api/staff/*`. **This app
does not use them**, and that is a deliberate audit outcome rather than an
oversight:

`EnvironmentAwareJWTAuthentication` is the backend's *only* authentication class.
There is no `SessionAuthentication`, so:

- `POST /auth/login/` already returns `{access, refresh, user}` — the token pair
  is the native contract, not a mobile special case;
- **CSRF does not apply.** CSRF exists because browsers attach cookies
  automatically. Nothing attaches an `Authorization` header on a user's behalf,
  so there is no cross-site request to forge. No CSRF bootstrap is needed and
  none was added to the backend;
- the BFF exists to keep tokens out of browser JavaScript, where an XSS could read
  them. A phone has Keystore/Keychain for that job, so routing through the BFF
  would add a hop, a cookie jar and a CSRF dance to buy nothing.

**No backend change was required or made.**

## Architecture

```
lib/
├── main.dart                  session restore starts before the first frame
├── app/                       MaterialApp, router + guards, shell, locale
├── core/
│   ├── api/                   ApiClient (dio), envelope, typed errors, endpoints
│   ├── auth/                  TokenStore, AuthController, Me/role models
│   ├── config/                --dart-define configuration
│   ├── errors/                backend code → localized message
│   ├── theme/                 design tokens shared with the website
│   └── widgets/               async states, form fields, brand mark
├── features/
│   ├── auth/                  sign in, sign up, OTP, consent
│   ├── doctors/               discovery, filters, profile
│   ├── bookings/              availability, booking sheet, my bookings
│   ├── onboarding/            doctor join + claim candidates
│   ├── management/            approved-doctor management (stats, clinics, assistants, schedule)
│   ├── practice/              activation + stats models shared with management
│   ├── profile/               account, edit details
│   ├── notifications/         in-app notifications
│   └── home/                  home + application status card
└── l10n/                      app_ar.arb (template), app_en.arb
```

| Concern | Choice |
|---|---|
| State | **Riverpod** — one approach throughout |
| Navigation | **go_router** with declarative guards |
| HTTP | **dio**, one client, interceptors for auth and error mapping |
| Session storage | **flutter_secure_storage** (Keystore / Keychain) |
| Localization | **gen-l10n** ARB, Arabic as the template |

## Configuration

Nothing here is secret — anything compiled into a mobile binary can be read out
of it. The only build-time values are the API base URL and an environment name.

```bash
# production (the defaults; no flags needed)
flutter run --release

# against a local backend — 10.0.2.2 is the emulator's route to the host
flutter run \
  --dart-define=ALEYADA_ENV=development \
  --dart-define=ALEYADA_API_BASE_URL=http://10.0.2.2:8000/api/v1 \
  --dart-define=ALEYADA_VERBOSE_LOG=true
```

`ALEYADA_ENV` defaults to `production` so a release build cannot ship pointing at
a laptop. Verbose logging is ignored in production builds, and even when on it
records only the method and path — never headers, bodies or query strings, which
is where passwords, OTP codes and tokens travel.

## Authentication and sessions

| Behaviour | How |
|---|---|
| Sign in | `POST /auth/login/` → token pair stored in secure storage |
| Signup | `POST /auth/register/patient/` then OTP; verifying the phone also signs you in |
| Restore | One `GET /auth/me/` at launch; the router holds a splash until it settles |
| Token refresh | Single-flight on 401, then the original request is replayed |
| Rotation | The backend rotates and blacklists refresh tokens, so the rotated value is stored |
| Sign out | `POST /auth/logout/` blacklists server-side; local state clears regardless |

**A network outage is not a logout.** This is the case the design is built
around: three outcomes are kept distinct — no token (*signed out*), token
rejected (*signed out, storage cleared*), token unverifiable (*offline, session
kept, retry offered*). Discarding a good seven-day session because a train
entered a tunnel would be the worst bug in the app.

Refresh is single-flight: ten requests racing an expired access token produce one
refresh, not ten. Without that, rotation would invalidate the session — the first
refresh succeeds and the other nine present a token that was just blacklisted.

## Business rules stay on the server

The app never holds a second copy of a rule:

- **Doctor onboarding locations** come from `/locations/cities/?onboarding=1`.
  Opening a new governorate is a server config change, not an app release. A
  direct API call with an unsupported city is refused by the backend regardless
  of what the form offers.
- **Search locations** use the *unrestricted* `/locations/cities/`. These two
  lists are deliberately different: registration is narrow, but the directory
  must keep serving every city it has entries for.
- **Cancellation** is offered when the booking's own `can_cancel` is true. The
  backend returns both the decision and `cancellation_cutoff_at` — the app never
  recomputes the window.
- **Booking constraints** (lead time, doctor-wide clashes, per-patient limits,
  whether a time is genuinely on the published schedule) are all server-side. The
  app sends a slot and renders the answer.
- **Times** are shown using the backend's `display_time` / `display_date`, which
  are formatted in the *clinic's* timezone. Deriving them from the UTC timestamp
  would use the phone's zone and show a patient abroad the wrong hour.
- **Money** is a decimal string end to end. Never a `double`.
- **Errors** branch on the backend's `code`, never on its prose.
- **Roles**: an applicant is `role=patient` until an admin approves them, so the
  practice area is guarded on `doctor_profile` presence *and* every endpoint
  behind it is `IsDoctor`-gated server-side. A guard failure produces a 403, not
  exposed data.

## Arabic first / RTL

Direction comes from the locale via `Localizations`. No widget reverses a `Row`
by hand — which is why switching to English just works, and is covered by tests
asserting both directions from the same tree.

- Cairo is **bundled** (`assets/fonts/`, OFL) rather than fetched at runtime: an
  Arabic-first product must not render its first frame in a Latin fallback.
- `letterSpacing` is pinned to 0 on every style. Arabic glyphs join and tracking
  breaks the joins; Material adds tracking by default, so this is a correction.
- Phone numbers, codes and times are forced LTR inside RTL forms.
- Text scaling is honoured and clamped to 0.85–1.6, which is honest about where
  the layouts stop working rather than ignoring the setting.

## Running and testing

```bash
flutter pub get
flutter gen-l10n          # after editing lib/l10n/*.arb
flutter analyze           # must be clean
flutter test
dart format --line-length 100 lib test
flutter build apk --release
```

Tests are contract-first: every DTO is parsed from a body **captured off the real
API** (`test/fixtures/api_fixtures.dart`), so a parser that disagrees with the
server about a field name, nullability or the envelope fails here rather than in
production. Widget tests go through the real `ApiClient` with only the HTTP
adapter swapped.

## Android

- Application id `com.aleyada.app`, `minSdk` = Flutter's floor (24)
- `INTERNET` is the only permission. No location, no contacts, no storage —
  `image_picker` uses the system picker
- Cleartext HTTP is **refused** in release (`network_security_config.xml`). The
  debug variant permits it to `localhost` / `10.0.2.2` only
- `tel:` and `https:` are declared under `<queries>`; without them `url_launcher`
  fails silently on API 30+ and the Call button appears dead
- R8 enabled with rules in `android/app/proguard-rules.pro`
- `kotlin.incremental=false` — on Windows the incremental caches fail to close
  and break the build; the comment in `gradle.properties` explains it

### Release signing

Google Play App Signing signs what users install; the key here is only the
**upload key** that proves an AAB came from us. Neither the keystore nor its
passwords are ever committed.

Keep the upload keystore at `android/upload-keystore.jks` (git-ignored) and
create `android/key.properties` (git-ignored):

```properties
storeFile=upload-keystore.jks
storePassword=…
keyAlias=aleyada-upload
keyPassword=…
```

`storeFile` is resolved relative to `android/`; an absolute path also works.

The build reads it if present and falls back to the debug key if not, so a fresh
clone still builds — Gradle prints a warning when that happens. A debug-signed
build runs but Play Console rejects it.

Back up the keystore and both passwords somewhere other than this machine. If
the upload key is lost, the only way back is an upload-key reset in Play Console
(Setup → App signing).

## iOS

Configured but **not compiled** — this was built on Windows, where no iOS
toolchain exists. Requires macOS with Xcode:

```bash
cd ios && pod install && cd ..
flutter build ios --release
```

`Info.plist` already carries the camera and photo-library purpose strings (iOS
rejects builds that use them without one), `LSApplicationQueriesSchemes` for
`tel`/`https`/`whatsapp`, and `ar`/`en` in `CFBundleLocalizations`. App Transport
Security is left at its secure default — there is no `NSAllowsArbitraryLoads`
anywhere.

## Branding

`assets/brand/` holds no final artwork, and the launcher icon is still Flutter's
default. `BrandMark` draws a placeholder from the design tokens so the app is
coherent without inventing a logo — the project ships no logo asset
(`Frontend/public` contains only Next.js starter SVGs) and scraping one from
production screenshots would be worse than a placeholder. **Final launcher,
splash and store artwork is an outstanding design deliverable.**

## Known backend limitations

These are platform facts, not app defects.

1. **No SMS provider exists.** Only `ConsoleOTPDelivery` and `LocMemOTPDelivery`
   are implemented, so production OTP codes are written to the service log rather
   than sent. The OTP flow here is the real one and needs no change once a
   provider is configured — but **self-service signup is not production-ready**
   until one is. There is no bypass in this app and no log reading.
2. **Push notifications**: `POST /notifications/devices/` accepts device tokens,
   but no sender is configured server-side. `NotificationRepository.registerDevice`
   exists as the integration point and is deliberately not called yet — collecting
   dead tokens would be worse than collecting none.
3. **Media** is on the server's local disk (`MEDIA_BACKEND=local`), not object
   storage. Uploads work; they are not replicated.
4. **DNS/SSL**: at the time of writing `aleyada.scenariomnchnl.tech` still needs
   its A record before HTTPS is live. Until then, use a development base URL.
5. **Resubmission**: a rejected or changes-requested application cannot be edited
   and resubmitted — the backend has no endpoint for it yet. The app reports the
   status and the reviewer's note accurately and offers no button that would fail.
6. **Analytics / crash reporting**: none configured, and none invented. There are
   no telemetry secrets in this repo.

## Not built yet

Named rather than left to be discovered:

- **Post-approval doctor profile editing**, including photo upload. The upload
  transport is in place (`ApiClient.upload`, multipart with progress) but no screen
  uses it, so `image_picker` is deliberately not a dependency — an unused native
  plugin would add camera and photo-library permission surface for nothing. Add
  both together.
- **Reschedule UI.** `BookingRepository.reschedule` is wired to
  `POST /bookings/{id}/reschedule/`; nothing calls it yet.
- **Review submission.** Reviews are read on a doctor's profile; writing one
  (`/reviews/create/`, `/reviews/reviewable/`) is not built.
- **Claim submission.** Candidate profiles are surfaced right after a doctor
  applies, which is the point at which duplicates are avoided, but filing the
  claim needs an authenticated session that does not exist until the phone is
  verified. `POST /doctor/claim-requests/` is unwired.
- **Parts of the web dashboard.** The doctor's *Management* tab covers statistics,
  clinics (terms, opening hours, invitations), assistants and the schedule
  (appointments, weekly availability). Still web-only: articles, days off and
  clinic holidays, clinic contact methods, adding an existing assistant to
  another clinic, and payment-proof review. The "open management system" button
  opens `https://scenariomnchnl.tech/` — the API does not report the web system's
  address, so it is the `ALEYADA_MANAGEMENT_URL` default in `lib/core/config/env.dart`,
  overridable with `--dart-define=ALEYADA_MANAGEMENT_URL=https://…` (an empty or
  non-http(s) value hides the button).
- **Standalone clinic directory.** Clinic details appear inside a doctor's
  profile; `/clinics/` as a browsable list is not built.
- **Integration tests.** None: this machine has no emulator or device, so
  claiming device-level coverage would be false.

## Contributing

1. `flutter analyze` and `flutter test` must both be clean.
2. `dart format --line-length 100 lib test`.
3. User-visible strings go in `lib/l10n/app_ar.arb` (the template) **and**
   `app_en.arb`. Never hardcode a string in a widget.
4. New endpoints are registered in `lib/core/api/endpoints.dart` with a comment
   saying what they are for. The set of endpoints this app depends on should stay
   readable in one screen.
5. If a change appears to need a backend modification, say so in the PR rather
   than making one. Adapt the client first.
