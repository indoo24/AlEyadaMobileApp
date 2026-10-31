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
  String get consentSubmitRejected =>
      'Your acceptance could not be recorded because the request was invalid. Try again, and contact support if it keeps happening.';

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
  String homeGreetingPatient(String name) {
    return 'Welcome, $name. Stay well.';
  }

  @override
  String homeGreetingDoctor(String name) {
    return 'Welcome, Dr. $name.';
  }

  @override
  String get homeGreetingPatientNoName => 'Welcome. Stay well.';

  @override
  String get homeGreetingDoctorNoName => 'Welcome.';

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

  @override
  String get homeGreetingGuest => 'Hello from AlEyada';

  @override
  String get homeLocationAll => 'All cities';

  @override
  String get homeLocationPickerTitle => 'Choose your city';

  @override
  String get homeSpecialtiesTitle => 'Medical specialties';

  @override
  String get homeTopDoctorsTitle => 'Top recommended doctors';

  @override
  String homeSeeAllCount(int count) {
    return 'See all (+$count)';
  }

  @override
  String get homeCentersTitle => 'Medical centers & clinics';

  @override
  String get homeArticlesTitle => 'Medical articles';

  @override
  String get homeFeeLabel => 'Consultation fee';

  @override
  String homeFeeAmount(String fee) {
    return '$fee EGP';
  }

  @override
  String get homeBookNow => 'Book a visit';

  @override
  String get homeViewProfile => 'View profile';

  @override
  String get homeBookingAvailable => 'Online booking available';

  @override
  String get homeContactOnly => 'Contact the clinic directly';

  @override
  String get homeNoDoctors => 'No doctors in this city yet.';

  @override
  String get homeNoCenters => 'No clinics in this city yet.';

  @override
  String get homeNoArticles => 'No articles published yet.';

  @override
  String get homeSectionError => 'This section could not be loaded.';

  @override
  String get homeArticleCertified => 'Medically reviewed';

  @override
  String get searchRecentTitle => 'Recent searches';

  @override
  String get searchClearAll => 'Clear all';

  @override
  String get searchRemoveRecent => 'Remove from recent searches';

  @override
  String get searchBrowseTitle => 'Browse by specialty';

  @override
  String get searchSuggestionsTitle => 'Suggestions';

  @override
  String get searchSuggestSpecialty => 'Specialty';

  @override
  String get searchSuggestCity => 'City';

  @override
  String get searchSuggestArea => 'Area';

  @override
  String get searchSuggestClinic => 'Clinic or center';

  @override
  String searchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doctors found',
      one: '1 doctor found',
      zero: 'No doctors',
    );
    return '$_temp0';
  }

  @override
  String get searchSortLabel => 'Sort';

  @override
  String get searchSortFeatured => 'Best match';

  @override
  String get searchSortRating => 'Top rated';

  @override
  String get searchSortNewest => 'Newest';

  @override
  String get searchSortFeeAsc => 'Lowest fee';

  @override
  String get searchFilterButton => 'Filters';

  @override
  String get searchFilterTitle => 'Filter results';

  @override
  String get searchFilterRating => 'Rating';

  @override
  String get searchFilterMaxFee => 'Maximum fee';

  @override
  String get searchFilterBooking => 'Online booking';

  @override
  String get searchFilterBookingOnly => 'Only doctors who take online bookings';

  @override
  String get searchAny => 'Any';

  @override
  String get searchAnyPrice => 'Any price';

  @override
  String get searchGenderMale => 'Male doctor';

  @override
  String get searchGenderFemale => 'Female doctor';

  @override
  String searchChipRating(String value) {
    return 'Rating $value+';
  }

  @override
  String searchChipMaxFee(String fee) {
    return 'Up to $fee EGP';
  }

  @override
  String get searchChipBooking => 'Online booking';

  @override
  String get searchClearField => 'Clear search';

  @override
  String get searchEmptyTitle => 'No doctors match your search';

  @override
  String get searchEmptyHint =>
      'Try another specialty or area, or remove some filters.';

  @override
  String get searchClearFilters => 'Clear filters';

  @override
  String get searchBookAppointment => 'Book an appointment';

  @override
  String get searchCall => 'Call';

  @override
  String searchYearsShort(int years) {
    return '$years yrs experience';
  }

  @override
  String get navFavorites => 'Favorites';

  @override
  String get favoritesTitle => 'Favorite doctors';

  @override
  String favoritesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doctors',
      one: '1 doctor',
    );
    return '$_temp0';
  }

  @override
  String get favoritesEmptyTitle => 'You haven\'t added any doctors yet';

  @override
  String get favoritesEmptyBody =>
      'Add the doctors you like so you can reach them easily later.';

  @override
  String get favoritesFindDoctor => 'Find a doctor';

  @override
  String get favoritesDoctorError => 'This doctor could not be loaded.';

  @override
  String get favoritesLoadError => 'Your favorites could not be loaded.';

  @override
  String get favoriteAdd => 'Add to favorites';

  @override
  String get favoriteRemove => 'Remove from favorites';

  @override
  String get favoriteFailed => 'Couldn\'t save that change. Please try again.';

  @override
  String get ratingNone => 'No reviews yet';

  @override
  String get navManagement => 'Management';

  @override
  String get managementTitle => 'Management';

  @override
  String get managementStatsTitle => 'Your stats';

  @override
  String managementStatsPeriod(int days) {
    return 'Last $days days';
  }

  @override
  String get statPatients => 'Patients';

  @override
  String get statCompletedVisits => 'Completed visits';

  @override
  String get statRating => 'Average rating';

  @override
  String get statContactRate => 'Contact rate';

  @override
  String get statViews => 'Profile views';

  @override
  String get statContacts => 'Contacts';

  @override
  String get statBookings => 'Bookings';

  @override
  String get statBookingsDone => 'Completed';

  @override
  String statViewsSub(int count) {
    return 'Profile views: $count';
  }

  @override
  String get managementPortalButton => 'Open the clinic management system';

  @override
  String get managementPortalFailed => 'Couldn\'t open the management system.';

  @override
  String get managementModulesTitle => 'Manage your practice';

  @override
  String get managementClinicsTitle => 'Clinics';

  @override
  String get managementClinicsDesc =>
      'Clinics, consultation fees and opening hours';

  @override
  String get managementAssistantsTitle => 'Assistants';

  @override
  String get managementAssistantsDesc =>
      'Your clinic assistants and what they may do';

  @override
  String get managementScheduleTitle => 'Schedule';

  @override
  String get managementScheduleDesc => 'Appointments and availability';

  @override
  String get managementSaved => 'Saved';

  @override
  String get managementDelete => 'Delete';

  @override
  String get managementFailed => 'That didn\'t go through. Please try again.';

  @override
  String get weekday1 => 'Monday';

  @override
  String get weekday2 => 'Tuesday';

  @override
  String get weekday3 => 'Wednesday';

  @override
  String get weekday4 => 'Thursday';

  @override
  String get weekday5 => 'Friday';

  @override
  String get weekday6 => 'Saturday';

  @override
  String get weekday7 => 'Sunday';

  @override
  String get clinicsTitle => 'Clinics';

  @override
  String get clinicsAdd => 'Add a clinic';

  @override
  String get clinicsEmptyTitle => 'You haven\'t added a clinic yet';

  @override
  String get clinicsEmptyBody => 'Add your clinic to start taking bookings.';

  @override
  String get clinicBadgePrimary => 'Main clinic';

  @override
  String get clinicBadgeOwner => 'Created by you';

  @override
  String get clinicBadgeInactive => 'Disabled';

  @override
  String get clinicReady => 'Ready to take bookings';

  @override
  String get clinicNotReady => 'Not ready to take bookings yet';

  @override
  String get clinicTermsTitle => 'My terms at this clinic';

  @override
  String get clinicFeeConsult => 'Consultation fee';

  @override
  String get clinicFeeFollowup => 'Follow-up fee';

  @override
  String get clinicAcceptBookings => 'Accept bookings';

  @override
  String get clinicSaveTerms => 'Save terms';

  @override
  String get clinicHoursTitle => 'Opening hours';

  @override
  String get clinicHoursHint =>
      'Set when the clinic is open each day. Bookings are generated inside these hours only.';

  @override
  String get clinicHoursNone => 'No opening hours set yet.';

  @override
  String get clinicHoursFrom => 'From';

  @override
  String get clinicHoursTo => 'To';

  @override
  String get clinicAddShift => 'Add a shift';

  @override
  String get clinicSaveHours => 'Save hours';

  @override
  String get clinicInviteTitle => 'Invite a doctor';

  @override
  String get clinicInvitePhone => 'Doctor\'s phone number';

  @override
  String get clinicInviteMessage => 'Message (optional)';

  @override
  String get clinicInviteSend => 'Send invitation';

  @override
  String get clinicInviteSent => 'Invitation sent';

  @override
  String get clinicInvitesSent => 'Sent invitations';

  @override
  String get clinicInvitesNone => 'No invitations sent.';

  @override
  String get invitationPending => 'Pending';

  @override
  String get invitationAccepted => 'Accepted';

  @override
  String get invitationDeclined => 'Declined';

  @override
  String get invitationCancelled => 'Cancelled';

  @override
  String get clinicFormName => 'Clinic name';

  @override
  String get clinicFormAddress => 'Address';

  @override
  String get clinicFormPhone => 'Clinic phone';

  @override
  String get clinicFormCreate => 'Create clinic';

  @override
  String get assistantsTitle => 'Assistants';

  @override
  String get assistantsAdd => 'Add an assistant';

  @override
  String get assistantsEmptyTitle => 'No assistants added yet';

  @override
  String get assistantsEmptyBody =>
      'Add an assistant to handle bookings for you, and choose what they may do.';

  @override
  String get assistantAllClinics => 'All clinics';

  @override
  String get assistantInactive => 'Inactive';

  @override
  String get assistantPermissions => 'Permissions';

  @override
  String assistantPermissionsCount(int count) {
    return '$count permissions';
  }

  @override
  String get assistantRevoke => 'Revoke access';

  @override
  String assistantRevokeConfirm(String clinic) {
    return 'Revoke this assistant\'s access to \"$clinic\"?';
  }

  @override
  String get assistantFormName => 'Assistant\'s name';

  @override
  String get assistantFormPhone => 'Phone number';

  @override
  String get assistantFormNotes => 'Notes (optional)';

  @override
  String get assistantFormClinic => 'Clinic';

  @override
  String get assistantCreate => 'Add assistant';

  @override
  String get flag_can_view_bookings => 'View bookings';

  @override
  String get flag_can_create_bookings => 'Create bookings';

  @override
  String get flag_can_update_bookings => 'Edit bookings';

  @override
  String get flag_can_cancel_bookings => 'Cancel bookings';

  @override
  String get flag_can_manage_schedule => 'Manage the schedule';

  @override
  String get flag_can_view_patient_phone => 'See patients\' phone numbers';

  @override
  String get flag_can_create_patient_next_visit =>
      'Book a patient\'s next visit';

  @override
  String get flag_can_request_duration_verification =>
      'Request visit-length verification';

  @override
  String get flag_can_review_payment_proofs => 'Review payment proofs';

  @override
  String get scheduleTitle => 'Schedule';

  @override
  String get scheduleTabBookings => 'Appointments';

  @override
  String get scheduleTabAvailability => 'Availability';

  @override
  String get scheduleView => 'View';

  @override
  String get scheduleViewUpcoming => 'Upcoming';

  @override
  String get scheduleViewAll => 'All';

  @override
  String get scheduleDate => 'Specific day';

  @override
  String get scheduleDateAny => 'Any day';

  @override
  String get scheduleStatus => 'Status';

  @override
  String get scheduleStatusAll => 'All statuses';

  @override
  String scheduleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appointments',
      one: '1 appointment',
      zero: 'No appointments',
    );
    return '$_temp0';
  }

  @override
  String get scheduleEmpty => 'No appointments.';

  @override
  String get scheduleEmptyHint => 'Try another view, status or day.';

  @override
  String get scheduleConfirm => 'Confirm';

  @override
  String get scheduleComplete => 'Completed';

  @override
  String get scheduleNoShow => 'No-show';

  @override
  String get scheduleCancel => 'Cancel appointment';

  @override
  String get scheduleCancelReason => 'Reason for cancelling (optional)';

  @override
  String get scheduleNoShowHint =>
      '\"No-show\" appears ten minutes after the appointment time.';

  @override
  String get scheduleUpdated => 'Appointment updated';

  @override
  String get windowsAdd => 'Add availability';

  @override
  String get windowsEmpty => 'No availability set yet.';

  @override
  String get windowsEmptyHint => 'Add the days and hours you see patients.';

  @override
  String windowMinutes(int minutes) {
    return '$minutes min per visit';
  }

  @override
  String get windowDeleteConfirm => 'Delete this availability window?';

  @override
  String get windowFormWeekday => 'Day';

  @override
  String get windowFormClinic => 'Clinic';

  @override
  String get windowFormDuration => 'Visit length (minutes)';

  @override
  String get windowCreate => 'Add';

  @override
  String get statusCancelledByPatient => 'Cancelled by patient';

  @override
  String get statusCancelledByClinic => 'Cancelled by clinic';

  @override
  String scheduleDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get scheduleDatePick => 'Choose a day';

  @override
  String get blockClinicHoursNotSet =>
      'The clinic\'s opening hours are not set yet';

  @override
  String get blockBookingDisabled =>
      'Online booking is switched off in your terms';

  @override
  String get blockNoAvailabilityWindows =>
      'You haven\'t set your availability yet (Schedule → Availability)';

  @override
  String get dpTitle => 'Professional profile';

  @override
  String get dpEdit => 'Edit';

  @override
  String get dpSaved => 'Professional profile saved';

  @override
  String get dpSentForReview =>
      'Some changes were sent to the administration for review before they show.';

  @override
  String get dpReviewNote =>
      'A change to this field is reviewed by the administration before it applies.';

  @override
  String get dpInvalidNumber => 'Enter a valid number';

  @override
  String get dpNothingChanged => 'Nothing was changed.';

  @override
  String get dpSectionBasic => 'Basic information';

  @override
  String get dpSectionProfessional => 'Professional information';

  @override
  String get dpSectionBio => 'Biography and vision';

  @override
  String get dpSectionExperience => 'Experience';

  @override
  String get dpSectionQualifications => 'Qualifications and certificates';

  @override
  String get dpSectionServices => 'Services and prices';

  @override
  String get dpSectionContact => 'Contact';

  @override
  String get dpSectionLinks => 'Links and social accounts';

  @override
  String get dpSectionSearch => 'Search appearance';

  @override
  String get dpEducationTitle => 'Education';

  @override
  String get dpCertificatesTitle => 'Certificates';

  @override
  String get dpCertPublic => 'Visible to patients';

  @override
  String get dpServiceInactive => 'Not active';

  @override
  String get dpSpecializations => 'Specialties';

  @override
  String get dpPrimarySpec => 'Primary';

  @override
  String get dpStatusDraft => 'Draft';

  @override
  String get dpStatusPending => 'Under review';

  @override
  String get dpStatusApproved => 'Approved';

  @override
  String get dpStatusRejected => 'Rejected';

  @override
  String get dpRejectionReason => 'Reason for rejection';

  @override
  String get dpAccountTile => 'Account details';

  @override
  String get dpAccountTileHint => 'First name, last name and email';

  @override
  String get dpOpenLink => 'Open link';

  @override
  String get dpLinkFailed => 'Couldn\'t open the link.';

  @override
  String get dpField_full_name_ar => 'Name in Arabic';

  @override
  String get dpField_full_name_en => 'Name in English';

  @override
  String get dpField_display_title => 'Title (Dr. / Prof.)';

  @override
  String get dpField_gender => 'Gender';

  @override
  String get dpField_city => 'Governorate';

  @override
  String get dpField_area => 'Area';

  @override
  String get dpField_professional_title_ar => 'Professional title in Arabic';

  @override
  String get dpField_professional_title_en => 'Professional title in English';

  @override
  String get dpField_academic_degree_ar => 'Academic degree';

  @override
  String get dpField_years_of_experience => 'Years of experience';

  @override
  String get dpField_default_consultation_fee => 'Default consultation fee';

  @override
  String get dpField_bio_ar => 'Biography in Arabic';

  @override
  String get dpField_bio_en => 'Biography in English';

  @override
  String get dpField_vision_ar => 'Medical vision or professional mission';

  @override
  String get dpField_current_positions_ar => 'Current positions';

  @override
  String get dpField_past_positions_ar => 'Past positions';

  @override
  String get dpField_certifications_ar => 'Certificates / medical licence';

  @override
  String get dpField_fellowships_ar => 'Fellowships and diplomas';

  @override
  String get dpField_phone => 'Phone number';

  @override
  String get dpField_whatsapp => 'WhatsApp';

  @override
  String get dpField_website => 'Website';

  @override
  String get dpField_external_booking_url => 'External booking link';

  @override
  String get dpField_google_maps_url => 'Google Maps link';

  @override
  String get dpField_facebook => 'Facebook';

  @override
  String get dpField_instagram => 'Instagram';

  @override
  String get dpField_linkedin => 'LinkedIn';

  @override
  String get dpField_youtube => 'YouTube';

  @override
  String get dpField_tiktok => 'TikTok';

  @override
  String get dpField_seo_title => 'Search result title';

  @override
  String get dpField_seo_description => 'Search result description';

  @override
  String get ddStatExperience => 'Experience';

  @override
  String ddStatYears(int years) {
    return '$years yrs';
  }

  @override
  String get ddStatRating => 'Rating';

  @override
  String get ddStatFee => 'Fees from';

  @override
  String get ddStatClinics => 'Clinics';

  @override
  String ddMoney(String amount) {
    return '$amount EGP';
  }

  @override
  String get ddShowMore => 'Show more';

  @override
  String get ddShowLess => 'Show less';

  @override
  String get ddServices => 'Services';

  @override
  String get ddBookAtClinic => 'Book';

  @override
  String get ddOpenLocation => 'Open location';

  @override
  String get ddPhoneOnly => 'Phone bookings only';

  @override
  String get ddLinksTitle => 'Location & links';

  @override
  String get ddMapLink => 'Location on map';

  @override
  String get ddNextAvailable => 'Next available';

  @override
  String get ddNoSlotsShort => 'No times available right now';

  @override
  String get ddReviewsMore => 'More reviews';

  @override
  String get ddReviewVerified => 'Verified visit';

  @override
  String get ddReviewPatient => 'Patient';

  @override
  String get ddReviewsFailed => 'Couldn\'t load reviews.';

  @override
  String get ddReviewsMoreFailed => 'Couldn\'t load more reviews.';

  @override
  String get ddBackTooltip => 'Back';

  @override
  String get bkChooseClinic => 'Choose a clinic';

  @override
  String get bkChooseClinicHint =>
      'This doctor works at more than one clinic. Choose the one that suits you.';

  @override
  String get bkChangeClinic => 'Change';

  @override
  String bkSlotsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: '1 time',
    );
    return '$_temp0';
  }

  @override
  String get bkPickTimeHint => 'Pick a time to continue';

  @override
  String get bkTimezoneNote => 'Times are shown in the clinic\'s time zone.';

  @override
  String get bkSlotUnavailable => 'Unavailable';

  @override
  String get bkPaymentRequired => 'This clinic requires payment in advance.';

  @override
  String get bkSignInToBook => 'Sign in to book';

  @override
  String get bkViewBooking => 'View booking';

  @override
  String get bkDone => 'Done';

  @override
  String get bkDoctor => 'Doctor';

  @override
  String bkDuration(int minutes) {
    return '$minutes min';
  }

  @override
  String get bkDurationLabel => 'Duration';

  @override
  String get bkClose => 'Close';

  @override
  String get bkTime => 'Time';

  @override
  String get bkUnconfirmedTitle => 'We couldn\'t confirm your booking';

  @override
  String get bkUnconfirmedBody =>
      'The connection dropped before the server\'s answer reached us, so the booking may already have gone through. Check your bookings before trying to book again.';

  @override
  String get bkUnconfirmedNotFound =>
      'This appointment isn\'t in your bookings yet — but that doesn\'t necessarily mean it wasn\'t booked. Check again in a moment, or in My Bookings, before booking another time.';

  @override
  String get bkUnconfirmedCheck => 'Check my bookings';

  @override
  String get bkUnconfirmedCheckAgain => 'Check again';

  @override
  String get bkUnconfirmedOpenBookings => 'Open My Bookings';

  @override
  String get bkUnconfirmedBookAnyway => 'Choose another time';

  @override
  String get bkUnconfirmedFoundTitle => 'We found your booking';

  @override
  String bkBookedAfterClose(String doctor) {
    return 'Your booking with $doctor is confirmed.';
  }

  @override
  String bkUnconfirmedAfterClose(String doctor) {
    return 'We couldn\'t confirm your booking with $doctor. Check your bookings before booking again.';
  }

  @override
  String bkNotBookedAfterClose(String doctor, String reason) {
    return 'Your booking with $doctor was not made: $reason';
  }

  @override
  String get bkVerifyPhoneTitle => 'Verify your phone to book';

  @override
  String bkVerifyPhoneBody(String phone) {
    return 'Booking needs a verified phone number. We will send a code to $phone.';
  }

  @override
  String get bkVerifyPhoneAction => 'Verify phone number';

  @override
  String get errorDoctorBusy =>
      'The doctor is booked at that time. Please pick another.';

  @override
  String get mbSubtitle => 'Keep track of your appointments';

  @override
  String get mbTabCancelled => 'Cancelled';

  @override
  String get mbNextAppointment => 'Your next appointment';

  @override
  String get mbMoreUpcoming => 'More upcoming';

  @override
  String get mbViewDetails => 'View booking';

  @override
  String get mbFindDoctor => 'Find a doctor';

  @override
  String get mbEmptyUpcomingTitle => 'No upcoming bookings';

  @override
  String get mbEmptyUpcomingBody =>
      'Book your next visit with the right doctor in a few taps.';

  @override
  String get mbEmptyPastTitle => 'No past bookings';

  @override
  String get mbEmptyPastBody =>
      'Your visits will appear here once they have taken place.';

  @override
  String get mbEmptyCancelledTitle => 'No cancelled bookings';

  @override
  String get mbEmptyCancelledBody =>
      'Any booking that is cancelled will appear here.';

  @override
  String get mbErrorTitle => 'Couldn\'t load your bookings';

  @override
  String get mbErrorBody =>
      'Something went wrong while loading your bookings. Please try again.';

  @override
  String get mbOfflineBody => 'Check your internet connection and try again.';

  @override
  String get mbNow => 'Now';

  @override
  String mbInMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count minutes',
      one: 'In 1 minute',
    );
    return '$_temp0';
  }

  @override
  String mbInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count hours',
      one: 'In 1 hour',
    );
    return '$_temp0';
  }

  @override
  String mbInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String get bdTitle => 'Booking details';

  @override
  String get bdYourAppointment => 'Your appointment';

  @override
  String get bdInfoTitle => 'Booking information';

  @override
  String get bdSpecialty => 'Specialty';

  @override
  String get bdDate => 'Date';

  @override
  String get bdFee => 'Visit fee';

  @override
  String get bdReason => 'Reason for visit';

  @override
  String get bdNotes => 'Your notes for the doctor';

  @override
  String get bdPayment => 'Payment';

  @override
  String get bdPayNotRequired => 'No advance payment';

  @override
  String get bdPayProofPending => 'Awaiting proof of payment';

  @override
  String get bdPayProofUploaded => 'Proof of payment uploaded';

  @override
  String get bdPayAccepted => 'Payment accepted';

  @override
  String get bdPayRejected => 'Proof of payment not accepted';

  @override
  String get bdVisitConsultation => 'Consultation';

  @override
  String get bdVisitProcedure => 'Procedure';

  @override
  String get bdVisitCustom => 'Visit';

  @override
  String get bdClinicTitle => 'Clinic & location';

  @override
  String get bdTimelineTitle => 'Booking status';

  @override
  String get bdStepBooked => 'Booked';

  @override
  String get bdStepAwaiting => 'Awaiting clinic confirmation';

  @override
  String get bdStepConfirmed => 'Booking confirmed';

  @override
  String get bdStepAppointment => 'Appointment';

  @override
  String get bdStepCompleted => 'Visit completed';

  @override
  String get bdStepNoShow => 'Did not attend';

  @override
  String get bdStepCancelledByPatient => 'You cancelled this booking';

  @override
  String get bdStepCancelledByClinic => 'The clinic cancelled this booking';

  @override
  String get bdStepExpired => 'Booking expired';

  @override
  String get bdStepRescheduled => 'This appointment was moved';

  @override
  String bdCancelBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You can cancel up to $count hours before your appointment.',
      one: 'You can cancel up to 1 hour before your appointment.',
    );
    return '$_temp0';
  }

  @override
  String get bdCancelClosed =>
      'Online cancellation has closed. Contact the clinic to cancel.';

  @override
  String get bdCancellationReason => 'Cancellation reason';

  @override
  String get bdCancelKeep => 'Keep booking';

  @override
  String get bdCancelConfirm => 'Cancel booking';

  @override
  String get bdBookAgain => 'Book again';

  @override
  String get bdBookNew => 'Book a new appointment';

  @override
  String get bdCallClinic => 'Call the clinic';

  @override
  String get bdViewDoctor => 'View doctor\'s page';

  @override
  String get hmSearchHint => 'Search for a doctor or specialty';

  @override
  String get hmQuickDoctors => 'All doctors';

  @override
  String get hmQuickSpecialties => 'Specialties';

  @override
  String get hmQuickOnline => 'Book online';

  @override
  String get hmQuickLowestFee => 'Lowest fee';

  @override
  String get hmRecommendedTitle => 'Recommended doctors';

  @override
  String get hmAllSpecialties => 'All specialties';

  @override
  String hmSpecialtyDoctors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doctors',
      one: '1 doctor',
      zero: 'No doctors yet',
    );
    return '$_temp0';
  }

  @override
  String get hmBookNow => 'Book now';

  @override
  String get hmViewProfile => 'View profile';

  @override
  String get hmOnlineBooking => 'Online booking';

  @override
  String get hmPhoneBooking => 'Book by phone';

  @override
  String get hmSeeAllDoctors => 'See all doctors';

  @override
  String get hmClinicDoctors => 'View doctors';

  @override
  String get hmLoadErrorTitle => 'Couldn\'t load the home screen';

  @override
  String get hmLoadErrorBody => 'Check your internet connection and try again.';

  @override
  String get hmGuestTitle => 'Sign in for the full experience';

  @override
  String get hmJoinCta => 'Are you a doctor? Join AlEyada';

  @override
  String get acSectionAccount => 'Account';

  @override
  String get acSectionSettings => 'Settings';

  @override
  String get acPhoneVerified => 'Phone verified';

  @override
  String get acPhoneUnverified => 'Phone not verified';

  @override
  String get acVerifyNow => 'Verify';

  @override
  String get acJoinNow => 'Join now';

  @override
  String get acLanguageSheetTitle => 'Choose language';

  @override
  String get accountAppearance => 'Appearance';

  @override
  String get accountThemeSystem => 'System';

  @override
  String get accountThemeLight => 'Light';

  @override
  String get accountThemeDark => 'Dark';

  @override
  String get acAppearanceSheetTitle => 'Choose appearance';

  @override
  String get acGuestTitle => 'Welcome';

  @override
  String acUnreadBadge(int count) {
    return '$count new';
  }

  @override
  String get pfPersonalDetails => 'Personal details';

  @override
  String get pfContactDetails => 'Contact details';

  @override
  String get pfPhoneReadOnly =>
      'Your phone number is how you sign in, so it can\'t be changed here.';

  @override
  String get pfSaveChanges => 'Save changes';

  @override
  String get pfReadOnly => 'Read-only';

  @override
  String get ntToday => 'Today';

  @override
  String get ntYesterday => 'Yesterday';

  @override
  String get ntEarlier => 'Earlier';

  @override
  String ntUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread notifications',
      one: '1 unread notification',
    );
    return '$_temp0';
  }

  @override
  String get ntAllRead => 'You\'re all caught up';

  @override
  String get ntEmptyTitle => 'No notifications yet';

  @override
  String get ntEmptyBody =>
      'We\'ll let you know here about anything new with your bookings.';

  @override
  String get ntErrorTitle => 'Couldn\'t load notifications';

  @override
  String get ntErrorBody => 'Something went wrong. Please try again.';

  @override
  String get ntOffline => 'Check your internet connection and try again.';

  @override
  String get ntLoadOlder => 'Show older notifications';

  @override
  String get ntUnread => 'Unread';

  @override
  String get ntUpdateFailed =>
      'Couldn\'t update notifications. Please try again.';

  @override
  String get ntRefreshFailed => 'Couldn\'t refresh the list.';

  @override
  String get auShowPassword => 'Show password';

  @override
  String get auHidePassword => 'Hide password';

  @override
  String get auReadPolicy => 'Read';

  @override
  String get auForgotBody =>
      'Enter your registered phone number to get a password-reset code.';

  @override
  String get auLogoLabel => 'AlEyada logo';

  @override
  String get auPoliciesRetry => 'Couldn\'t load the terms. Please try again.';
}
