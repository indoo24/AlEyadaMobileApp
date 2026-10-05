import '../../l10n/app_localizations.dart';
import 'models.dart';

/// "Welcome Ahmed" for everyone, "Welcome Dr. Ahmed" only for a doctor account.
///
/// The title hangs on [Me.isDoctor] — the backend's `role` — and nothing else.
/// Both strings live in the ARB files so the wording and its RTL ordering stay
/// with the translators rather than being assembled here.
String welcomeGreeting(L l, Me user) =>
    user.isDoctor ? l.dashboardWelcomeDoctor(user.shortName) : l.dashboardWelcome(user.shortName);
