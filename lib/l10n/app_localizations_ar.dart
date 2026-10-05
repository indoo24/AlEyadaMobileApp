// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class LAr extends L {
  LAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'العيادة';

  @override
  String get appTagline => 'منصة طبية تساعدك تصل للطبيب المناسب بسهولة';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navDoctors => 'الأطباء';

  @override
  String get navBookings => 'حجوزاتي';

  @override
  String get navAccount => 'حسابي';

  @override
  String get navDashboard => 'لوحة التحكم';

  @override
  String get navSchedule => 'الجدول';

  @override
  String get navNotifications => 'الإشعارات';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionConfirm => 'تأكيد';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionSaving => 'جارٍ الحفظ…';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionBack => 'رجوع';

  @override
  String get actionNext => 'التالي';

  @override
  String get actionDone => 'تم';

  @override
  String get actionSearch => 'بحث';

  @override
  String get actionFilter => 'تصفية';

  @override
  String get actionClearFilters => 'إزالة التصفية';

  @override
  String get actionApply => 'تطبيق';

  @override
  String get actionSeeAll => 'عرض الكل';

  @override
  String get actionLoadMore => 'تحميل المزيد';

  @override
  String get stateLoading => 'جارٍ التحميل…';

  @override
  String get stateEmpty => 'لا توجد نتائج';

  @override
  String get stateErrorTitle => 'حدث خطأ';

  @override
  String get stateOfflineTitle => 'لا يوجد اتصال';

  @override
  String get stateOfflineBody => 'تحقق من اتصالك بالإنترنت ثم أعد المحاولة.';

  @override
  String get authSignIn => 'تسجيل الدخول';

  @override
  String get authSignOut => 'تسجيل الخروج';

  @override
  String get authSignUp => 'إنشاء حساب';

  @override
  String get authPhone => 'رقم الهاتف';

  @override
  String get authPhoneHint => 'مثال: 01012345678';

  @override
  String get authEmail => 'البريد الإلكتروني';

  @override
  String get authPassword => 'كلمة المرور';

  @override
  String get authFullName => 'الاسم الكامل';

  @override
  String get authForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get authNoAccount => 'ليس لديك حساب؟';

  @override
  String get authHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get authSignInSubtitle => 'سجّل الدخول لمتابعة حجوزاتك ومواعيدك.';

  @override
  String get authSignUpSubtitle => 'أنشئ حسابك لحجز المواعيد ومتابعتها.';

  @override
  String get authPhoneRequired => 'من فضلك أدخل رقم الهاتف.';

  @override
  String get authPasswordRequired => 'من فضلك أدخل كلمة المرور.';

  @override
  String get authNameRequired => 'من فضلك أدخل الاسم.';

  @override
  String get authPasswordTooShort => 'كلمة المرور قصيرة جدًا.';

  @override
  String get authGuestPrompt => 'سجّل الدخول لمتابعة حجوزاتك.';

  @override
  String get otpTitle => 'تأكيد رقم الهاتف';

  @override
  String otpSentTo(String phone) {
    return 'أرسلنا رمز تأكيد إلى $phone';
  }

  @override
  String get otpCode => 'رمز التأكيد';

  @override
  String get otpVerify => 'تأكيد';

  @override
  String get otpResend => 'إعادة إرسال الرمز';

  @override
  String get otpCodeRequired => 'من فضلك أدخل الرمز.';

  @override
  String get consentTitle => 'الموافقة على الشروط';

  @override
  String get consentBody => 'من فضلك راجع الشروط وسياسة الخصوصية للمتابعة.';

  @override
  String get consentAccept => 'أوافق على الشروط وسياسة الخصوصية';

  @override
  String get consentRequired => 'يجب الموافقة على الشروط للمتابعة.';

  @override
  String get consentReacceptTitle => 'تحديث الشروط';

  @override
  String get consentReacceptBody =>
      'حدّثنا الشروط وسياسة الخصوصية. راجعها للمتابعة.';

  @override
  String get consentSubmitRejected =>
      'تعذّر تسجيل موافقتك بسبب خطأ في الطلب. حاول مرة أخرى، وإن تكرر ذلك فتواصل مع الدعم.';

  @override
  String get doctorsTitle => 'الأطباء';

  @override
  String get doctorsSearchHint => 'ابحث باسم الطبيب أو التخصص';

  @override
  String get doctorsEmpty => 'لا يوجد أطباء مطابقون لهذا البحث.';

  @override
  String get doctorsFilterSpecialty => 'التخصص';

  @override
  String get doctorsFilterCity => 'المدينة';

  @override
  String get doctorsFilterArea => 'المنطقة';

  @override
  String get doctorsFilterGender => 'نوع الطبيب';

  @override
  String get doctorsFilterAny => 'الكل';

  @override
  String get doctorsFilterMale => 'ذكر';

  @override
  String get doctorsFilterFemale => 'أنثى';

  @override
  String doctorsResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتيجة',
      one: 'نتيجة واحدة',
      zero: 'لا نتائج',
    );
    return '$_temp0';
  }

  @override
  String doctorYearsExperience(int years) {
    return '$years سنة خبرة';
  }

  @override
  String doctorReviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييم',
      one: 'تقييم واحد',
      zero: 'لا تقييمات',
    );
    return '$_temp0';
  }

  @override
  String doctorFeeFrom(String fee) {
    return 'تبدأ من $fee ج.م';
  }

  @override
  String get doctorAbout => 'نبذة عن الطبيب';

  @override
  String get doctorClinics => 'العيادات';

  @override
  String get doctorWorkingHours => 'مواعيد العمل';

  @override
  String get doctorReviews => 'التقييمات';

  @override
  String get doctorNoReviews => 'لا توجد تقييمات بعد.';

  @override
  String get doctorBookNow => 'احجز موعدًا';

  @override
  String get doctorCall => 'اتصال';

  @override
  String get doctorWhatsapp => 'واتساب';

  @override
  String get doctorBookingUnavailable =>
      'الحجز الإلكتروني غير متاح لهذا الطبيب — تواصل مع العيادة مباشرة.';

  @override
  String get doctorVerified => 'طبيب موثّق';

  @override
  String get bookingTitle => 'حجز موعد';

  @override
  String get bookingChooseDay => 'اختر اليوم';

  @override
  String get bookingChooseTime => 'اختر الوقت';

  @override
  String get bookingNoSlots => 'لا توجد مواعيد متاحة في هذا اليوم.';

  @override
  String get bookingNoSlotsAtAll =>
      'لا توجد مواعيد متاحة حاليًا. تواصل مع العيادة للاستفسار.';

  @override
  String get bookingSummary => 'ملخص الحجز';

  @override
  String get bookingConfirm => 'تأكيد الحجز';

  @override
  String get bookingFee => 'سعر الكشف';

  @override
  String get bookingClinic => 'العيادة';

  @override
  String get bookingDateTime => 'الموعد';

  @override
  String get bookingSuccessTitle => 'تم تأكيد حجزك';

  @override
  String get bookingSuccessBody => 'سنرسل لك تنبيهًا قبل الموعد.';

  @override
  String get bookingVisitType => 'نوع الزيارة';

  @override
  String get bookingVisitFirst => 'زيارة أولى';

  @override
  String get bookingVisitFollowUp => 'متابعة';

  @override
  String get bookingNotes => 'ملاحظات (اختياري)';

  @override
  String get bookingsTitle => 'حجوزاتي';

  @override
  String get bookingsEmpty => 'لا توجد حجوزات بعد.';

  @override
  String get bookingsEmptyHint => 'ابحث عن طبيب واحجز موعدك الأول.';

  @override
  String get bookingsUpcoming => 'القادمة';

  @override
  String get bookingsPast => 'السابقة';

  @override
  String get bookingCancelTitle => 'إلغاء الحجز';

  @override
  String get bookingCancelBody => 'هل تريد إلغاء هذا الحجز؟';

  @override
  String get bookingCancelReason => 'سبب الإلغاء (اختياري)';

  @override
  String get bookingCancelled => 'تم إلغاء الحجز.';

  @override
  String get bookingReschedule => 'تغيير الموعد';

  @override
  String get bookingRescheduled => 'تم تغيير الموعد.';

  @override
  String get statusPending => 'بانتظار التأكيد';

  @override
  String get statusConfirmed => 'مؤكد';

  @override
  String get statusCompleted => 'تمت الزيارة';

  @override
  String get statusCancelled => 'ملغي';

  @override
  String get statusNoShow => 'لم يتم الحضور';

  @override
  String get statusRescheduled => 'تم تغييره';

  @override
  String get statusExpired => 'منتهي';

  @override
  String get accountTitle => 'حسابي';

  @override
  String get accountProfile => 'بياناتي';

  @override
  String get accountMyReviews => 'تقييماتي';

  @override
  String get accountLanguage => 'اللغة';

  @override
  String get accountLanguageArabic => 'العربية';

  @override
  String get accountLanguageEnglish => 'English';

  @override
  String get accountSignOutConfirm => 'هل تريد تسجيل الخروج؟';

  @override
  String get accountFirstName => 'الاسم الأول';

  @override
  String get accountLastName => 'الاسم الأخير';

  @override
  String get accountSaved => 'تم حفظ بياناتك.';

  @override
  String get joinTitle => 'انضم كطبيب';

  @override
  String get joinIntro => 'أضف صفحتك على العيادة ليصل إليك المرضى.';

  @override
  String get joinNameAr => 'اسم الطبيب بالعربية';

  @override
  String get joinNameEn => 'اسم الطبيب بالإنجليزية';

  @override
  String get joinNameEnHint => 'يُستخدم في رابط صفحتك';

  @override
  String get joinSpecialty => 'التخصص الرئيسي';

  @override
  String get joinCity => 'المحافظة';

  @override
  String get joinArea => 'المنطقة';

  @override
  String get joinLicence => 'الشهادات / الترخيص الطبي';

  @override
  String get joinLicenceHint =>
      'هذه البيانات تساعدنا على التحقق من حسابك بسرعة.';

  @override
  String get joinOnboardingScope =>
      'نستقبل حاليًا طلبات انضمام الأطباء في المناطق المتاحة بالقائمة فقط، ونتوسع قريبًا.';

  @override
  String get joinRestLater =>
      'بقية بيانات صفحتك — الصورة والنبذة وسنوات الخبرة والروابط — تُستكمل من التطبيق بعد اعتماد حسابك.';

  @override
  String get joinSubmit => 'إرسال الطلب';

  @override
  String get joinSuccessTitle => 'تم تسجيل طلبك بنجاح';

  @override
  String get joinSuccessBody =>
      'يراجع فريق العيادة بياناتك الآن، وسنتواصل معك على رقم هاتفك فور صدور القرار.';

  @override
  String get joinPatientUntilApproved =>
      'يمكنك استخدام حسابك كمريض بشكل طبيعي في أثناء المراجعة.';

  @override
  String get claimTitle => 'وجدنا صفحات قد تخصّك';

  @override
  String get claimBody =>
      'إذا كانت إحدى هذه الصفحات لك، طالب بها بدلًا من إنشاء صفحة جديدة.';

  @override
  String get claimThisIsMe => 'هذه صفحتي';

  @override
  String get claimSubmitted => 'تم إرسال طلب إثبات الملكية.';

  @override
  String get claimSkip => 'تخطٍّ';

  @override
  String get applicationPendingTitle => 'تم تسجيل طلبك بنجاح';

  @override
  String get applicationPendingBody =>
      'يراجع فريق العيادة بياناتك الآن، وسنتواصل معك فور صدور القرار.';

  @override
  String get applicationClaimPendingTitle =>
      'طلب إثبات ملكية الصفحة قيد المراجعة';

  @override
  String applicationClaimPendingBody(String name) {
    return 'نراجع طلبك لإثبات ملكية صفحة $name.';
  }

  @override
  String get applicationChangesTitle => 'طلبك يحتاج إلى تعديل';

  @override
  String get applicationChangesBody =>
      'راجع ملاحظة المراجع أدناه — سنتواصل معك على رقم هاتفك لاستكمال طلبك.';

  @override
  String get applicationRejectedTitle => 'لم يتم اعتماد طلبك';

  @override
  String get applicationRejectedBody =>
      'سنتواصل معك على رقم هاتفك لتوضيح الأسباب.';

  @override
  String get applicationReviewerNote => 'ملاحظة المراجع:';

  @override
  String get dashboardTitle => 'لوحة التحكم';

  @override
  String dashboardWelcome(String name) {
    return 'أهلاً $name';
  }

  @override
  String dashboardWelcomeDoctor(String name) {
    return 'أهلاً د. $name';
  }

  @override
  String get dashboardStatPatients => 'المرضى';

  @override
  String get dashboardStatVisits => 'الزيارات';

  @override
  String get dashboardStatRating => 'التقييم';

  @override
  String get dashboardStatViews => 'مشاهدات الصفحة';

  @override
  String get dashboardNotPublished => 'صفحتك غير منشورة بعد';

  @override
  String get dashboardPublished => 'صفحتك منشورة';

  @override
  String get dashboardActivationMissing =>
      'لإتمام نشر صفحتك، أكمل البيانات الناقصة.';

  @override
  String get dashboardTodayBookings => 'حجوزات اليوم';

  @override
  String get dashboardNoBookings => 'لا توجد حجوزات.';

  @override
  String get dashboardMyClinics => 'عياداتي';

  @override
  String get dashboardProfile => 'ملفي الطبي';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notificationsEmpty => 'لا توجد إشعارات.';

  @override
  String get notificationsMarkAllRead => 'تعليم الكل كمقروء';

  @override
  String get reviewTitle => 'تقييم الزيارة';

  @override
  String get reviewRating => 'تقييمك';

  @override
  String get reviewComment => 'تعليقك (اختياري)';

  @override
  String get reviewSubmit => 'إرسال التقييم';

  @override
  String get reviewSubmitted => 'شكرًا لك، تم إرسال تقييمك.';

  @override
  String get reviewableEmpty => 'لا توجد زيارات بحاجة إلى تقييم.';

  @override
  String get errorGeneric => 'حدث خطأ غير متوقع. حاول مرة أخرى.';

  @override
  String get errorNetwork => 'تعذّر الاتصال بالخادم. تحقق من الإنترنت.';

  @override
  String get errorServer => 'الخادم لا يستجيب حاليًا. حاول بعد قليل.';

  @override
  String get errorNotAuthenticated => 'من فضلك سجّل الدخول للمتابعة.';

  @override
  String get errorPermissionDenied => 'لا تملك صلاحية لهذا الإجراء.';

  @override
  String get errorNotFound => 'العنصر المطلوب غير موجود.';

  @override
  String get errorInvalidCredentials => 'رقم الهاتف أو كلمة المرور غير صحيحة.';

  @override
  String get errorThrottled =>
      'حاولت كثيرًا. من فضلك انتظر قليلًا ثم أعد المحاولة.';

  @override
  String get errorAccountInactive => 'هذا الحساب غير مُفعّل.';

  @override
  String get errorPhoneTaken => 'هذا الرقم مسجل بالفعل.';

  @override
  String get errorEmailTaken => 'هذا البريد الإلكتروني مسجل بالفعل.';

  @override
  String get errorSlotUnavailable =>
      'هذا الموعد لم يعد متاحًا. اختر موعدًا آخر.';

  @override
  String get errorBookingConflict => 'لديك حجز آخر يتعارض مع هذا الموعد.';

  @override
  String get errorOutsideAvailability => 'هذا الوقت خارج مواعيد عمل الطبيب.';

  @override
  String get errorLeadTime =>
      'لا يمكن الحجز في هذا الوقت القريب. اختر موعدًا لاحقًا.';

  @override
  String get errorTooManyBookings => 'لديك حجوزات كثيرة مع هذا الطبيب.';

  @override
  String get errorInvalidOtp => 'الرمز غير صحيح أو انتهت صلاحيته.';

  @override
  String get errorUploadTooLarge => 'حجم الملف كبير جدًا.';

  @override
  String get errorUnsupportedFile => 'نوع الملف غير مدعوم.';

  @override
  String get uploadChoosePhoto => 'اختر صورة';

  @override
  String get uploadFromCamera => 'الكاميرا';

  @override
  String get uploadFromGallery => 'معرض الصور';

  @override
  String uploadProgress(int percent) {
    return 'جارٍ الرفع… $percent%';
  }

  @override
  String get semanticDoctorPhoto => 'صورة الطبيب';

  @override
  String semanticRating(String value) {
    return 'التقييم $value من ٥';
  }

  @override
  String get semanticBack => 'رجوع';

  @override
  String get semanticClose => 'إغلاق';
}
