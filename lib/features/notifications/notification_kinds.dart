import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/auth/models.dart';
import 'notifications_data.dart';
import '../../core/theme/app_palette.dart';

/// What each `NotificationEventEnum` value looks like and where it leads.
///
/// Only the backend's own event types are listed; anything else (a type added
/// later) gets the plain bell and no destination.

/// The booking events a *patient* receives about their own appointment. Their
/// `booking` id opens Booking Details.
const patientBookingEvents = {
  'booking_confirmed',
  'booking_pending',
  'booking_cancelled',
  'booking_rescheduled',
  'booking_reminder',
  'booking_completed',
  'booking_no_show',
  'payment_proof_reviewed',
};

/// The events a clinic's staff receive about a patient's booking. The booking
/// is not the reader's own, so Booking Details (which shows one's own) cannot
/// open it; an approved doctor goes to their schedule instead.
const staffBookingEvents = {
  'booking_confirmed_staff',
  'booking_cancelled_staff',
  'payment_proof_uploaded',
  'duration_verification_requested',
};

({IconData icon, Color fg, Color bg}) notificationStyle(
  String type, {
  AppPalette palette = AppPalette.light,
}) {
  final blue = (fg: palette.toneInfo.fg, bg: palette.toneInfo.bg);
  final green = (fg: palette.toneSuccess.fg, bg: palette.toneSuccess.bg);
  final red = (fg: palette.toneDanger.fg, bg: palette.toneDanger.bg);
  final amber = (fg: palette.toneWarning.fg, bg: palette.toneWarning.bg);
  final orange = (fg: palette.toneCaution.fg, bg: palette.toneCaution.bg);

  (IconData, ({Color fg, Color bg})) pick() => switch (type) {
    'booking_confirmed' || 'booking_confirmed_staff' => (Icons.event_available_rounded, green),
    'booking_pending' => (Icons.hourglass_top_rounded, amber),
    'booking_cancelled' || 'booking_cancelled_staff' => (Icons.event_busy_rounded, red),
    'booking_rescheduled' => (Icons.update_rounded, blue),
    'booking_reminder' => (Icons.alarm_rounded, blue),
    'booking_completed' => (Icons.task_alt_rounded, blue),
    'booking_no_show' => (Icons.person_off_outlined, orange),
    'duration_verification_requested' || 'duration_decided' => (Icons.timer_outlined, blue),
    'payment_proof_uploaded' || 'payment_proof_reviewed' => (Icons.receipt_long_outlined, blue),
    'doctor_verified' || 'claim_result' => (Icons.verified_user_outlined, blue),
    'clinic_invitation_received' ||
    'clinic_invitation_accepted' ||
    'clinic_invitation_declined' => (Icons.local_hospital_outlined, blue),
    'review_approved' ||
    'review_rejected' ||
    'review_clarification_requested' ||
    'review_clarification_answered' => (Icons.rate_review_outlined, blue),
    'feedback_request' => (Icons.star_outline_rounded, amber),
    _ => (Icons.notifications_none_rounded, blue),
  };

  final (icon, colors) = pick();
  return (icon: icon, fg: colors.fg, bg: colors.bg);
}

/// Where tapping a notification goes, or null when the payload names no screen
/// the app has. Never guessed: the `booking` id, the account's role, and the
/// screens that exist decide.
String? notificationDestination(AppNotification n, Me? user) {
  final doctor = user?.isActiveDoctor ?? false;
  if (patientBookingEvents.contains(n.type)) {
    // The id comes from the payload; encoded, it can only ever be one path
    // segment of /bookings/, never a different route.
    return n.bookingId == null ? null : Routes.bookingPath(Uri.encodeComponent(n.bookingId!));
  }
  if (staffBookingEvents.contains(n.type)) return doctor ? Routes.managementSchedule : null;
  // Sent invitations are listed under the clinic; a received one has no screen
  // in the app to answer it from, so it opens nothing.
  if (n.type == 'clinic_invitation_accepted' || n.type == 'clinic_invitation_declined') {
    return doctor ? Routes.managementClinics : null;
  }
  if (n.type == 'doctor_verified') return doctor ? Routes.management : Routes.account;
  return null;
}
