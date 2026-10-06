/// Text folding for matching typed Arabic against names.
///
/// People type "احمد" for "أحمد", "مستشفي" for "مستشفى", "العياده" for
/// "العيادة". An exact `contains` would miss all of those, so both sides are
/// folded the same way before comparing. Latin text is lower-cased.
String foldForSearch(String input) {
  final buffer = StringBuffer();
  for (final unit in input.runes) {
    // Tashkeel (harakat), tatweel and the dagger alif carry no identity.
    if ((unit >= 0x064B && unit <= 0x065F) || unit == 0x0640 || unit == 0x0670) continue;
    switch (unit) {
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0622: // آ
      case 0x0671: // ٱ
        buffer.writeCharCode(0x0627); // ا
      case 0x0629: // ة
        buffer.writeCharCode(0x0647); // ه
      case 0x0649: // ى
        buffer.writeCharCode(0x064A); // ي
      default:
        buffer.writeCharCode(unit);
    }
  }
  return buffer.toString().toLowerCase().trim();
}

/// Whether [haystack] contains [needle], ignoring the spelling variants above.
bool foldedContains(String haystack, String needle) {
  final n = foldForSearch(needle);
  return n.isNotEmpty && foldForSearch(haystack).contains(n);
}
