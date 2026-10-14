import 'router.dart';

/// The longest `next` worth honouring. Real locations are a few dozen characters.
const _maxLength = 512;

/// Screens that are steps of signing in, not destinations. Resuming one would
/// loop the user back into the flow they just finished.
const _notResumable = <String>{
  Routes.splash,
  Routes.signIn,
  Routes.signUp,
  Routes.otp,
  Routes.consent,
};

/// [raw] if it is a location inside this app, otherwise null.
///
/// `next` arrives as a query parameter, so anything that can open the sign-in
/// screen chooses it. Only a plain absolute path of this app is accepted:
///
///  * exactly one leading `/` — `//host/x` and `/\host` are network paths to a
///    URL parser;
///  * no scheme, no host, no fragment, no backslash, no whitespace or control
///    characters;
///  * no `.` or `..` segments, encoded or not;
///  * not one of the sign-in steps themselves.
///
/// A query string is kept: `/doctors?focus=1` is a real destination.
String? safeNextLocation(String? raw) {
  if (raw == null || raw.isEmpty || raw.length > _maxLength) return null;
  if (!raw.startsWith('/') || raw.startsWith('//')) return null;
  if (raw.contains(r'\')) return null;
  if (raw.codeUnits.any((c) => c <= 0x20 || c == 0x7f)) return null;

  final uri = Uri.tryParse(raw);
  if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasFragment) return null;

  // Checked on the text as written: Uri.parse quietly resolves `..` away, which
  // would hide one. Each segment is percent-decoded first, so `%2e%2e` and an
  // encoded `/` are caught too, and a broken escape (`%zz`) is refused.
  for (final segment in raw.split('?').first.split('/')) {
    final String s;
    try {
      s = Uri.decodeComponent(segment);
    } catch (_) {
      return null;
    }
    if (s == '.' || s == '..' || s.contains('/') || s.contains(r'\')) return null;
  }

  final path = uri.path.length > 1 && uri.path.endsWith('/')
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  if (_notResumable.contains(path)) return null;
  return raw;
}

/// Where to go once someone has signed in, or null to let the router's guards
/// choose (a doctor's management hub, everyone else's home).
///
/// [next] must pass [safeNextLocation]. It is also dropped when it was left
/// behind by a *different* account: if A's session ended on `/bookings/42` and
/// B signs in on the same phone, B lands on their own home rather than on the
/// address of A's booking. [endedAccountId] is whose session ended before this
/// sign-in (null when nobody's did — a guest who hit a protected screen), and
/// [signedInAccountId] is who has just signed in.
String? resumeLocation(
  String? next, {
  required String? endedAccountId,
  required String? signedInAccountId,
}) {
  final safe = safeNextLocation(next);
  if (safe == null) return null;
  if (endedAccountId != null && endedAccountId != signedInAccountId) return null;
  return safe;
}
