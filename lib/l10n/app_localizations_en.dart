// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'AlEyada';

  @override
  String get appTagline => 'Find the right doctor, easily';

  @override
  String get navHome => 'Home';

  @override
  String get navDoctors => 'Doctors';

  @override
  String get navBookings => 'Bookings';

  @override
  String get navAccount => 'Account';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navSchedule => 'Schedule';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSaving => 'Saving…';

  @override
  String get actionClose => 'Close';

  @override
  String get actionBack => 'Back';

  @override
  String get actionNext => 'Next';

  @override
  String get actionDone => 'Done';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionFilter => 'Filter';

  @override
  String get actionClearFilters => 'Clear filters';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get actionLoadMore => 'Load more';

  @override
  String get stateLoading => 'Loading…';

  @override
  String get stateEmpty => 'No results';

  @override
  String get stateErrorTitle => 'Something went wrong';

  @override
  String get stateOfflineTitle => 'No connection';

  @override
  String get stateOfflineBody =>
      'Check your internet connection and try again.';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authSignUp => 'Create account';

  @override
  String get authPhone => 'Phone number';

  @override
  String get authPhoneHint => 'e.g. 01012345678';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authFullName => 'Full name';

  @override
  String get authForgotPassword => 'Forgot your password?';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authSignInSubtitle => 'Sign in to manage your appointments.';

  @override
  String get authSignUpSubtitle =>
      'Create an account to book and track appointments.';

  @override
  String get authPhoneRequired => 'Please enter your phone number.';

  @override
  String get authPasswordRequired => 'Please enter your password.';

  @override
  String get authNameRequired => 'Please enter your name.';

  @override
  String get authPasswordTooShort => 'That password is too short.';

  @override
  String get authGuestPrompt => 'Sign in to see your bookings.';

  @override
  String get otpTitle => 'Verify your phone';

  @override
  String otpSentTo(String phone) {
    return 'We sent a verification code to $phone';
  }

  @override
  String get otpCode => 'Verification code';

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpResend => 'Resend code';

  @override
  String get otpCodeRequired => 'Please enter the code.';

  @override
  String get consentTitle => 'Accept the terms';

  @override
  String get consentBody =>
      'Please review the terms and privacy policy to continue.';

  @override
  String get consentAccept => 'I accept the terms and privacy policy';

  @override
  String get consentRequired => 'You must accept the terms to continue.';

  @override
  String get consentReacceptTitle => 'Terms updated';

  @override
  String get consentReacceptBody =>
      'We have updated our terms and privacy policy. Review them to continue.';

  @override
  String get doctorsTitle => 'Doctors';

  @override
  String get doctorsSearchHint => 'Search by doctor name or specialty';

  @override
  String get doctorsEmpty => 'No doctors match this search.';

  @override
  String get doctorsFilterSpecialty => 'Specialty';

  @override
  String get doctorsFilterCity => 'City';

  @override
  String get doctorsFilterArea => 'Area';

  @override
  String get doctorsFilterGender => 'Doctor\'s gender';

  @override
  String get doctorsFilterAny => 'Any';

  @override
  String get doctorsFilterMale => 'Male';

  @override
  String get doctorsFilterFemale => 'Female';

  @override
  String doctorsResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String doctorYearsExperience(int years) {
    return '$years years\' experience';
  }

  @override
  String doctorReviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
      zero: 'No reviews',
    );
    return '$_temp0';
  }

  @override
  String doctorFeeFrom(String fee) {
    return 'From $fee EGP';
  }

  @override
  String get doctorAbout => 'About the doctor';

  @override
  String get doctorClinics => 'Clinics';

  @override
  String get doctorWorkingHours => 'Working hours';

  @override
  String get doctorReviews => 'Reviews';

  @override
  String get doctorNoReviews => 'No reviews yet.';

  @override
  String get doctorBookNow => 'Book an appointment';

  @override
  String get doctorCall => 'Call';

  @override
  String get doctorWhatsapp => 'WhatsApp';

  @override
  String get doctorBookingUnavailable =>
      'Online booking is not available for this doctor — please contact the clinic directly.';

  @override
  String get doctorVerified => 'Verified doctor';

  @override
  String get bookingTitle => 'Book an appointment';

  @override
  String get bookingChooseDay => 'Choose a day';

  @override
  String get bookingChooseTime => 'Choose a time';

  @override
  String get bookingNoSlots => 'No times available on this day.';

  @override
  String get bookingNoSlotsAtAll =>
      'No appointments are available right now. Contact the clinic to ask.';

  @override
  String get bookingSummary => 'Booking summary';

  @override
  String get bookingConfirm => 'Confirm booking';

  @override
  String get bookingFee => 'Consultation fee';

  @override
  String get bookingClinic => 'Clinic';

  @override
  String get bookingDateTime => 'Appointment';

  @override
  String get bookingSuccessTitle => 'Your booking is confirmed';

  @override
  String get bookingSuccessBody => 'We will remind you before the appointment.';

  @override
  String get bookingVisitType => 'Visit type';

  @override
  String get bookingVisitFirst => 'First visit';

  @override
  String get bookingVisitFollowUp => 'Follow-up';

  @override
  String get bookingNotes => 'Notes (optional)';

  @override
  String get bookingsTitle => 'My bookings';

  @override
  String get bookingsEmpty => 'No bookings yet.';

  @override
  String get bookingsEmptyHint =>
      'Find a doctor and book your first appointment.';

  @override
  String get bookingsUpcoming => 'Upcoming';

  @override
  String get bookingsPast => 'Past';

  @override
  String get bookingCancelTitle => 'Cancel booking';

  @override
  String get bookingCancelBody => 'Do you want to cancel this booking?';

  @override
  String get bookingCancelReason => 'Reason (optional)';

  @override
  String get bookingCancelled => 'Booking cancelled.';

  @override
  String get bookingReschedule => 'Change time';

  @override
  String get bookingRescheduled => 'Appointment moved.';

  @override
  String get statusPending => 'Awaiting confirmation';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusNoShow => 'Did not attend';

  @override
  String get statusRescheduled => 'Moved';

  @override
  String get statusExpired => 'Expired';

  @override
  String get accountTitle => 'My account';

  @override
  String get accountProfile => 'My details';

  @override
  String get accountMyReviews => 'My reviews';

  @override
  String get accountLanguage => 'Language';

  @override
  String get accountLanguageArabic => 'العربية';

  @override
  String get accountLanguageEnglish => 'English';

  @override
  String get accountSignOutConfirm => 'Sign out of AlEyada?';

  @override
  String get accountFirstName => 'First name';

  @override
  String get accountLastName => 'Last name';

  @override
  String get accountSaved => 'Your details were saved.';

  @override
  String get joinTitle => 'Join as a doctor';

  @override
  String get joinIntro => 'Add your page to AlEyada so patients can find you.';

  @override
  String get joinNameAr => 'Doctor\'s name in Arabic';

  @override
  String get joinNameEn => 'Doctor\'s name in English';

  @override
  String get joinNameEnHint => 'Used for your page\'s address';

  @override
  String get joinSpecialty => 'Primary specialty';

  @override
  String get joinCity => 'Governorate';

  @override
  String get joinArea => 'Area';

  @override
  String get joinLicence => 'Certificates / medical licence';

  @override
  String get joinLicenceHint => 'This helps us verify your account quickly.';

  @override
  String get joinOnboardingScope =>
      'We are currently accepting doctor applications only in the areas listed, and are expanding soon.';

  @override
  String get joinRestLater =>
      'The rest of your page — photo, bio, years of experience and links — is completed in the app once your account is approved.';

  @override
  String get joinSubmit => 'Submit application';

  @override
  String get joinSuccessTitle => 'Your application was received';

  @override
  String get joinSuccessBody =>
      'Our team is reviewing your details and will contact you on your phone once a decision is made.';

  @override
  String get joinPatientUntilApproved =>
      'You can keep using your account as a patient while the review is under way.';

  @override
  String get claimTitle => 'We found pages that may be yours';

  @override
  String get claimBody =>
      'If one of these is your page, claim it instead of creating a new one.';

  @override
  String get claimThisIsMe => 'This is my page';

  @override
  String get claimSubmitted => 'Your ownership claim was submitted.';

  @override
  String get claimSkip => 'Skip';

  @override
  String get applicationPendingTitle => 'Your application was received';

  @override
  String get applicationPendingBody =>
      'Our team is reviewing your details and will contact you once a decision is made.';

  @override
  String get applicationClaimPendingTitle =>
      'Your ownership claim is under review';

  @override
  String applicationClaimPendingBody(String name) {
    return 'We are reviewing your claim to the page for $name.';
  }

  @override
  String get applicationChangesTitle => 'Your application needs a change';

  @override
  String get applicationChangesBody =>
      'Review the note below — we will contact you on your phone to complete it.';

  @override
  String get applicationRejectedTitle => 'Your application was not approved';

  @override
  String get applicationRejectedBody =>
      'We will contact you on your phone to explain why.';

  @override
  String get applicationReviewerNote => 'Reviewer\'s note:';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String dashboardWelcome(String name) {
    return 'Welcome, Dr $name';
  }

  @override
  String get dashboardStatPatients => 'Patients';

  @override
  String get dashboardStatVisits => 'Visits';

  @override
  String get dashboardStatRating => 'Rating';

  @override
  String get dashboardStatViews => 'Page views';

  @override
  String get dashboardNotPublished => 'Your page is not published yet';

  @override
  String get dashboardPublished => 'Your page is live';

  @override
  String get dashboardActivationMissing =>
      'Complete the missing details to publish your page.';

  @override
  String get dashboardTodayBookings => 'Today\'s bookings';

  @override
  String get dashboardNoBookings => 'No bookings.';

  @override
  String get dashboardMyClinics => 'My clinics';

  @override
  String get dashboardProfile => 'My medical profile';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'No notifications.';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get reviewTitle => 'Rate your visit';

  @override
  String get reviewRating => 'Your rating';

  @override
  String get reviewComment => 'Your comment (optional)';

  @override
  String get reviewSubmit => 'Submit review';

  @override
  String get reviewSubmitted => 'Thank you — your review was submitted.';

  @override
  String get reviewableEmpty => 'No visits are waiting for a review.';

  @override
  String get errorGeneric => 'Something unexpected happened. Please try again.';

  @override
  String get errorNetwork =>
      'Could not reach the server. Check your connection.';

  @override
  String get errorServer =>
      'The server is not responding. Please try again shortly.';

  @override
  String get errorNotAuthenticated => 'Please sign in to continue.';

  @override
  String get errorPermissionDenied => 'You do not have permission to do that.';

  @override
  String get errorNotFound => 'That item could not be found.';

  @override
  String get errorInvalidCredentials => 'Phone/email or password is incorrect.';

  @override
  String get errorThrottled =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String get errorAccountInactive => 'This account is not active.';

  @override
  String get errorPhoneTaken => 'That phone number is already registered.';

  @override
  String get errorEmailTaken => 'That email address is already registered.';

  @override
  String get errorSlotUnavailable =>
      'That time is no longer available. Please pick another.';

  @override
  String get errorBookingConflict =>
      'You have another booking that clashes with this time.';

  @override
  String get errorOutsideAvailability =>
      'That time is outside the doctor\'s working hours.';

  @override
  String get errorLeadTime =>
      'That time is too soon to book. Please pick a later one.';

  @override
  String get errorTooManyBookings =>
      'You already have several bookings with this doctor.';

  @override
  String get errorInvalidOtp => 'That code is incorrect or has expired.';

  @override
  String get errorUploadTooLarge => 'That file is too large.';

  @override
  String get errorUnsupportedFile => 'That file type is not supported.';

  @override
  String get uploadChoosePhoto => 'Choose a photo';

  @override
  String get uploadFromCamera => 'Camera';

  @override
  String get uploadFromGallery => 'Photo library';

  @override
  String uploadProgress(int percent) {
    return 'Uploading… $percent%';
  }

  @override
  String get semanticDoctorPhoto => 'Doctor\'s photo';

  @override
  String semanticRating(String value) {
    return 'Rated $value out of 5';
  }

  @override
  String get semanticBack => 'Back';

  @override
  String get semanticClose => 'Close';
}
