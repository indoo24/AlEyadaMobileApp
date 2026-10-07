import 'package:intl/intl.dart';

import '../bookings/models.dart';
import 'models.dart';

/// Decisions the doctor profile and the booking sheet share, kept free of
/// widgets so they can be tested on their own.

/// The clinics a patient can book online.
///
/// Both switches must be on: the doctor-level `booking_enabled` (any active
/// clinic accepts bookings) and the clinic's own.
List<DoctorClinicLink> bookableClinics(DoctorDetail d) =>
    d.card.bookingEnabled ? d.clinics.where((c) => c.bookingEnabled).toList() : const [];

/// The clinic the booking sheet should open on, or null when the patient has to
/// choose one first.
///
/// A clinic the patient tapped "book" on wins. With a single bookable clinic
/// there is nothing to choose. With several and no request, nothing is assumed:
/// silently booking the "primary" clinic is how a patient ends up across town.
String? initialBookingClinic(DoctorDetail d, {String? requested}) {
  final clinics = bookableClinics(d);
  if (requested != null && clinics.any((c) => c.clinic.id == requested)) return requested;
  if (clinics.length == 1) return clinics.single.clinic.id;
  return null;
}

/// The clinic to look availability up for on the profile itself (the "next
/// free time" hint): the primary one if it is bookable, else the first that is.
DoctorClinicLink? availabilityHintClinic(DoctorDetail d) {
  final clinics = bookableClinics(d);
  if (clinics.isEmpty) return null;
  return clinics.firstWhere((c) => c.isPrimary, orElse: () => clinics.first);
}

/// `"09:00:00"` → `"09:00"`. Anything not in that shape is returned unchanged.
String shortTime(String t) {
  final m = RegExp(r'^(\d{1,2}:\d{2})(:\d{2})?$').firstMatch(t.trim());
  return m == null ? t.trim() : m.group(1)!;
}

/// One day of a clinic's opening hours, with every shift that day.
class WorkingDay {
  const WorkingDay({required this.weekday, required this.label, required this.ranges});

  /// ISO weekday (Monday = 1).
  final int weekday;

  /// The backend's own day name, when it sent one.
  final String label;

  /// `"09:00 – 17:00"`, in start order.
  final List<String> ranges;
}

/// ISO weekdays in the order an Egyptian week is read: Saturday first.
const _weekOrder = [6, 7, 1, 2, 3, 4, 5];

/// Opening hours grouped by day — a clinic with a morning and an evening shift
/// shows one line for that day, not two.
List<WorkingDay> groupWorkingHours(List<ClinicWorkingHour> hours) {
  final byDay = <int, List<ClinicWorkingHour>>{};
  for (final h in hours) {
    if (h.weekday < 1 || h.weekday > 7) continue;
    byDay.putIfAbsent(h.weekday, () => []).add(h);
  }
  return [
    for (final day in _weekOrder)
      if (byDay[day] case final shifts?)
        WorkingDay(
          weekday: day,
          label: shifts
              .map((s) => s.weekdayLabel)
              .firstWhere((l) => l.isNotEmpty, orElse: () => ''),
          ranges: [
            for (final s in shifts..sort((a, b) => a.openTime.compareTo(b.openTime)))
              '${shortTime(s.openTime)} – ${shortTime(s.closeTime)}',
          ],
        ),
  ];
}

/// The earliest bookable slot in an availability answer, with its day.
({String date, Slot slot})? firstFreeSlot(DoctorAvailability a) {
  for (final d in a.days) {
    if (d.slots.isNotEmpty) return (date: d.date, slot: d.slots.first);
  }
  return null;
}

/// A plain `YYYY-MM-DD` clinic-local day, as the parts a date chip shows.
///
/// The string is parsed as a calendar date only — never converted between
/// timezones — so the day the patient sees is the clinic's day.
({String weekday, String day, String month})? calendarParts(String date, String locale) {
  final d = DateTime.tryParse(date);
  if (d == null) return null;
  return (
    weekday: DateFormat.EEEE(locale).format(d),
    day: '${d.day}',
    month: DateFormat.MMMM(locale).format(d),
  );
}

/// `"السبت 10 أكتوبر"` for a clinic-local `YYYY-MM-DD`; the raw string if it
/// does not parse.
String longDayLabel(String date, String locale) {
  final p = calendarParts(date, locale);
  return p == null ? date : '${p.weekday} ${p.day} ${p.month}';
}

/// A review's date, day-month-year, in Western digits like the rest of the app.
String reviewDateLabel(DateTime utc, String locale) {
  final d = utc.toLocal();
  return '${d.day} ${DateFormat.MMMM(locale).format(d)} ${d.year}';
}

/// The fee the summary should show for a visit type at a clinic.
///
/// A follow-up uses the clinic's `followup_fee` when it has one; everything else
/// uses the fee the availability endpoint quoted, falling back to the clinic's
/// consultation fee. Null when the API gave no figure — nothing is made up.
String? feeFor({
  required VisitType visitType,
  DoctorClinicLink? clinic,
  DoctorAvailability? availability,
}) {
  if (visitType == VisitType.followUp && clinic?.followupFee != null) return clinic!.followupFee;
  return availability?.fee ?? clinic?.consultationFee;
}
