/// Every backend route this app calls, in one place.
///
/// All of these are Django routes under `/api/v1/`. None of the website's
/// Next.js BFF routes (`/api/auth/*`, `/api/staff/*`) appear here — those are
/// browser plumbing around this same API, not a separate contract.
///
/// Anything not listed is not called. That is the point of the file: the set of
/// endpoints the app depends on should be readable in one screen, so a backend
/// change can be checked against it.
library;

class Endpoints {
  const Endpoints._();

  // --- auth ---------------------------------------------------------------
  /// POST phone|email + password → {access, refresh, user}. Public.
  static const login = '/auth/login/';

  /// POST {refresh} → {access, refresh}. Rotates; the old token is blacklisted.
  static const tokenRefresh = '/auth/token/refresh/';

  /// POST {refresh}. Blacklists this device's token. Requires auth.
  static const logout = '/auth/logout/';

  /// GET → the whole routing picture: role, profiles, application status,
  /// outstanding policy re-acceptance.
  static const me = '/auth/me/';

  /// PATCH first/last name, email, preferred language.
  static const meUpdate = '/auth/me/';

  static const registerPatient = '/auth/register/patient/';
  static const registerDoctorRequest = '/auth/register/doctor-request/';

  static const otpRequest = '/auth/otp/request/';

  /// POST phone + purpose + code. For signup/login purposes this also returns a
  /// token pair, so verifying the phone signs the user in.
  static const otpVerify = '/auth/otp/verify/';

  static const passwordForgot = '/auth/password/forgot/';
  static const passwordReset = '/auth/password/reset/';

  // --- legal --------------------------------------------------------------
  /// GET the current policy versions. Their ids must be sent with registration.
  static const currentPolicies = '/legal/policies/current/';

  /// POST accepted versions — clears `requires_reacceptance`.
  static const consents = '/consents/';
  static const communicationConsents = '/consents/communication/';

  // --- reference data -----------------------------------------------------
  /// GET cities. `with_areas=1` nests areas; `onboarding=1` narrows to the
  /// cities where doctor registration is currently open. The app never decides
  /// that list for itself — see the note in the locations repository.
  static const cities = '/locations/cities/';
  static const specializations = '/specializations/';
  static String specialization(String slug) => '/specializations/$slug/';

  // --- public directory ---------------------------------------------------
  static const doctors = '/doctors/';
  static String doctor(String slug) => '/doctors/$slug/';
  static String doctorAvailability(String slug) => '/doctors/$slug/availability/';
  static String doctorBook(String slug) => '/doctors/$slug/book/';
  static String doctorReviews(String slug) => '/doctors/$slug/reviews/';

  static const clinics = '/clinics/';
  static String clinic(String slug) => '/clinics/$slug/';

  static const home = '/home/';

  /// GET published articles, newest first. `page_size` is honoured.
  static const articles = '/articles/';
  static const publicSettings = '/settings/public/';

  /// POST a contact-click. Fire-and-forget analytics; a failure here must never
  /// stop the user reaching the clinic.
  static const contactClick = '/tracking/contact-click/';

  // --- patient bookings ---------------------------------------------------
  static const bookings = '/bookings/';
  static String booking(String id) => '/bookings/$id/';
  static String bookingCancel(String id) => '/bookings/$id/cancel/';
  static String bookingReschedule(String id) => '/bookings/$id/reschedule/';
  static String bookingPaymentProof(String id) => '/bookings/$id/payment-proof/';

  // --- patient account ----------------------------------------------------
  static const patientProfile = '/patients/me/';

  // --- reviews ------------------------------------------------------------
  static const reviewable = '/reviews/reviewable/';
  static const reviewCreate = '/reviews/create/';
  static const myReviews = '/reviews/';

  // --- notifications ------------------------------------------------------
  static const notifications = '/notifications/';
  static const notificationsUnreadCount = '/notifications/unread-count/';
  static const notificationsReadAll = '/notifications/read-all/';
  static String notificationRead(String id) => '/notifications/$id/read/';

  /// POST {token, platform} to register for push; DELETE to unregister.
  /// The backend accepts device tokens today, but no sender is configured —
  /// see PUSH NOTIFICATIONS in the README.
  static const notificationDevices = '/notifications/devices/';

  // --- doctor (own account) ----------------------------------------------
  static const doctorProfile = '/doctor/profile/';
  static const doctorActivation = '/doctor/activation/';
  static const doctorVerificationStatus = '/doctor/verification-status/';
  static const doctorClinics = '/doctor/clinics/';
  static const doctorClinicCreate = '/doctor/clinics/create/';
  static String doctorClinicTerms(String id) => '/doctor/clinics/$id/terms/';
  static String doctorClinicWorkingHours(String id) => '/doctor/clinics/$id/working-hours/';
  static String doctorClinicInvitations(String id) => '/doctor/clinics/$id/invitations/';

  // --- doctor: assistants -------------------------------------------------
  static const doctorAssistants = '/doctor/assistants/';
  static const doctorAssistantCreate = '/doctor/assistants/create/';
  static String doctorAssignment(String id) => '/doctor/assignments/$id/';

  // --- doctor: availability -----------------------------------------------
  static const doctorAvailabilityWindows = '/doctor/availability-windows/';
  static String doctorAvailabilityWindow(String id) => '/doctor/availability-windows/$id/';
  static const doctorSchedule = '/doctor/schedule/';
  static const doctorBookings = '/doctor/bookings/';
  static String doctorBookingConfirm(String id) => '/doctor/bookings/$id/confirm/';
  static String doctorBookingCancel(String id) => '/doctor/bookings/$id/cancel/';
  static String doctorBookingComplete(String id) => '/doctor/bookings/$id/complete/';
  static String doctorBookingNoShow(String id) => '/doctor/bookings/$id/no-show/';
  static const doctorStats = '/doctor/stats/';

  /// Imported directory profiles that may belong to this applicant.
  static const doctorClaimMatches = '/doctor/claim-matches/';
  static const doctorClaimRequests = '/doctor/claim-requests/';
}
