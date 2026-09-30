import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../api/api_error.dart';

/// Turns a failed call into something worth reading.
///
/// Every branch here is on the backend's **code**, never on its prose. The
/// `detail` string is Arabic in some places and English in others, and it is
/// free to be reworded at any time — matching on it would make a copy edit a
/// behaviour change. Codes are the contract.
///
/// When a code is not one we recognise, the backend's own `detail` is preferred
/// over a generic message: it was written for a person to read, and is almost
/// always more useful than "something went wrong".
String messageForError(BuildContext context, Object error) {
  final l = L.of(context);
  if (error is! ApiException) return l.errorGeneric;

  // Transport first: these have no code of their own and must never be
  // mistaken for an authorisation problem.
  if (error.isNetworkFailure) return l.errorNetwork;
  if (error.failure == ApiFailure.server) return l.errorServer;

  final known = _knownCode(l, error.code);
  if (known != null) return known;

  // Unrecognised code: use what the server said, if it said anything.
  final detail = error.firstDetail;
  if (detail != null && detail.isNotEmpty) return detail;

  return switch (error.failure) {
    ApiFailure.unauthenticated => l.errorNotAuthenticated,
    ApiFailure.forbidden => l.errorPermissionDenied,
    ApiFailure.notFound => l.errorNotFound,
    ApiFailure.rateLimited => l.errorThrottled,
    _ => l.errorGeneric,
  };
}

String? _knownCode(L l, String code) => switch (code) {
  // auth
  'invalid_credentials' => l.errorInvalidCredentials,
  'not_authenticated' => l.errorNotAuthenticated,
  'authentication_failed' => l.errorNotAuthenticated,
  'permission_denied' => l.errorPermissionDenied,
  'not_found' => l.errorNotFound,
  'account_inactive' => l.errorAccountInactive,
  'throttled' => l.errorThrottled,
  'network_error' => l.errorNetwork,
  'server_error' => l.errorServer,

  // registration
  'phone_taken' => l.errorPhoneTaken,
  'email_taken' => l.errorEmailTaken,
  'unique' => l.errorGeneric,

  // OTP
  'invalid_otp' => l.errorInvalidOtp,
  'otp_invalid' => l.errorInvalidOtp,
  'otp_expired' => l.errorInvalidOtp,
  'otp_max_attempts' => l.errorThrottled,

  // booking. These are the domain errors the backend raises by name, and
  // each deserves its own sentence: "slot taken" and "too soon to book"
  // need different actions from the patient.
  'slot_not_bookable' => l.errorSlotUnavailable,
  'slot_unavailable' => l.errorSlotUnavailable,
  'doctor_busy' => l.errorBookingConflict,
  'booking_conflict' => l.errorBookingConflict,
  'outside_availability' => l.errorOutsideAvailability,
  'lead_time_too_short' => l.errorLeadTime,
  'too_many_active_bookings' => l.errorTooManyBookings,
  'booking_not_allowed' => l.doctorBookingUnavailable,

  // uploads
  'file_too_large' => l.errorUploadTooLarge,
  'unsupported_file_type' => l.errorUnsupportedFile,

  _ => null,
};

/// A booking failure the user can fix by picking another time, as opposed to one
/// that needs them to leave the screen. Drives whether the booking sheet stays
/// open with the calendar visible.
bool isRecoverableBookingError(Object error) {
  if (error is! ApiException) return false;
  return const {
    'slot_not_bookable',
    'slot_unavailable',
    'doctor_busy',
    'booking_conflict',
    'outside_availability',
    'lead_time_too_short',
  }.contains(error.code);
}
