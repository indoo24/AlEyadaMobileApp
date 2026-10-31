import '../config/env.dart';

/// [raw] as an absolute `http(s)` URL an image widget can load, or null.
///
/// The public doctor endpoints send photos as absolute URLs
/// (`https://host/media/doctors/photos/x.webp`), but a serializer that returns
/// the stored path instead sends `/media/doctors/photos/x.webp`, which
/// `Image.network` cannot load. Relative values are resolved against the API's
/// own host ([Env.apiBaseUrl]'s origin, or [base]); anything that is not an
/// http(s) address afterwards — `javascript:`, `data:`, `file:` — is dropped,
/// and so is blank text.
String? resolveMediaUrl(String? raw, {String? base}) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;

  final origin = Uri.tryParse(base ?? Env.apiBaseUrl);
  if (origin == null || !origin.hasAuthority) return null;

  final parsed = Uri.tryParse(text);
  if (parsed == null) return null;

  Uri resolved;
  if (parsed.hasScheme) {
    resolved = parsed;
  } else if (text.startsWith('//')) {
    resolved = Uri.parse('${origin.scheme}:$text');
  } else {
    // `/media/x.webp` or `media/x.webp`: the host's root, not the API prefix.
    final path = text.startsWith('/') ? text : '/$text';
    resolved = Uri.tryParse('${origin.scheme}://${origin.authority}$path') ?? parsed;
  }

  final ok = (resolved.scheme == 'https' || resolved.scheme == 'http') && resolved.host.isNotEmpty;
  return ok ? resolved.toString() : null;
}
