import 'package:url_launcher/url_launcher.dart';

/// The two ways a patient reaches a clinic from the app.
enum ContactChannel {
  phone('phone'),
  whatsapp('whatsapp');

  const ContactChannel(this.trackingType);

  /// The `contact_type` the click-tracking endpoint expects.
  final String trackingType;
}

/// The hosts WhatsApp's click-to-chat links live on.
const _whatsappHosts = {'wa.me', 'api.whatsapp.com'};

/// A dialable number: an optional leading `+`, then digits, with `-` or `.` as
/// separators. Deliberately nothing else — `*`, `#`, `;` and `,` turn a dial
/// into an MMI/USSD code, an extension or a pause, none of which a clinic's
/// number needs.
final _telNumber = RegExp(r'^\+?[0-9](?:[0-9.\-]*[0-9])?$');

/// [raw] as a `tel:` link that only dials a phone number, or null.
///
/// The link comes from the API (`tel_url`) and is used as given, but it is
/// checked before it reaches the dialer: scheme `tel`, no host, query or
/// fragment, and a number of 3 to 15 digits (the E.164 maximum).
Uri? safePhoneUri(String? raw) {
  if (raw == null) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'tel') return null;
  if (uri.hasAuthority || uri.hasQuery || uri.hasFragment) return null;
  if (!_telNumber.hasMatch(uri.path)) return null;
  final digits = uri.path.replaceAll(RegExp(r'[^0-9]'), '').length;
  if (digits < 3 || digits > 15) return null;
  return uri;
}

/// [raw] as a WhatsApp click-to-chat link, or null.
///
/// Only `https` on `wa.me` or `api.whatsapp.com` — no other scheme or host, no
/// user info, no explicit port, no fragment. The query is kept: it carries the
/// message text the backend composed.
Uri? safeWhatsappUri(String? raw) {
  if (raw == null) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'https') return null;
  if (!_whatsappHosts.contains(uri.host)) return null;
  if (uri.userInfo.isNotEmpty || uri.hasPort || uri.hasFragment) return null;
  return uri;
}

/// [raw] checked for [channel]: a `tel:` number for a call, a WhatsApp link
/// for WhatsApp. Null when it is not one.
Uri? safeContactUri(ContactChannel channel, String? raw) => switch (channel) {
  ContactChannel.phone => safePhoneUri(raw),
  ContactChannel.whatsapp => safeWhatsappUri(raw),
};

/// Open [raw] in the dialer or in WhatsApp, if it passes [safeContactUri] for
/// [channel]. Returns whether anything was opened; a link that fails the check
/// is never handed to the system.
Future<bool> launchContact(ContactChannel channel, String? raw) async {
  final uri = safeContactUri(channel, raw);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // No app to handle it (a tablet without a dialer, WhatsApp not installed).
    return false;
  }
}
