import '../../l10n/app_localizations.dart';
import 'models.dart';

/// Home's welcome line.
///
///  * patient — "أهلاً يوسف، سلامتك" / "Welcome, Yousef. Stay well."
///  * doctor  — "أهلاً د. يوسف" / "Welcome, Dr. Yousef."
///
/// The title hangs on [Me.isDoctor] — the backend's `role` — and nothing else;
/// the name is [Me.greetingName], the first name with any title already
/// removed. With no usable name the line still greets, just without one. The
/// wording lives in the ARB files so translators own it and its RTL order.
String welcomeGreeting(L l, Me user) {
  final name = user.greetingName;
  if (user.isDoctor) {
    return name == null ? l.homeGreetingDoctorNoName : l.homeGreetingDoctor(name);
  }
  return name == null ? l.homeGreetingPatientNoName : l.homeGreetingPatient(name);
}
