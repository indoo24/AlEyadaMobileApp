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
  String homeGreetingPatient(String name) {
    return 'أهلاً $name، سلامتك';
  }

  @override
  String homeGreetingDoctor(String name) {
    return 'أهلاً د. $name';
  }

  @override
  String get homeGreetingPatientNoName => 'أهلاً بك، سلامتك';

  @override
  String get homeGreetingDoctorNoName => 'أهلاً بك';

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

  @override
  String get homeGreetingGuest => 'مرحباً بك في العيادة';

  @override
  String get homeLocationAll => 'كل المدن';

  @override
  String get homeLocationPickerTitle => 'اختر مدينتك';

  @override
  String get homeSpecialtiesTitle => 'التخصصات الطبية';

  @override
  String get homeTopDoctorsTitle => 'أفضل الأطباء الموصى بهم';

  @override
  String homeSeeAllCount(int count) {
    return 'عرض الكل (+$count)';
  }

  @override
  String get homeCentersTitle => 'المراكز الطبية والعيادات';

  @override
  String get homeArticlesTitle => 'مقالات العيادة الطبية';

  @override
  String get homeFeeLabel => 'قيمة الكشف';

  @override
  String homeFeeAmount(String fee) {
    return '$fee ج.م';
  }

  @override
  String get homeBookNow => 'احجز كشف';

  @override
  String get homeViewProfile => 'عرض الملف';

  @override
  String get homeBookingAvailable => 'الحجز الإلكتروني متاح';

  @override
  String get homeContactOnly => 'التواصل مباشرة مع العيادة';

  @override
  String get homeNoDoctors => 'لا يوجد أطباء في هذه المدينة بعد.';

  @override
  String get homeNoCenters => 'لا توجد مراكز أو عيادات في هذه المدينة بعد.';

  @override
  String get homeNoArticles => 'لا توجد مقالات منشورة حالياً.';

  @override
  String get homeSectionError => 'تعذّر تحميل هذا القسم.';

  @override
  String get homeArticleCertified => 'مراجَع طبياً';

  @override
  String get searchRecentTitle => 'عمليات البحث الأخيرة';

  @override
  String get searchClearAll => 'مسح الكل';

  @override
  String get searchRemoveRecent => 'إزالة من عمليات البحث الأخيرة';

  @override
  String get searchBrowseTitle => 'تصفح حسب التخصص';

  @override
  String get searchSuggestionsTitle => 'اقتراحات';

  @override
  String get searchSuggestSpecialty => 'تخصص';

  @override
  String get searchSuggestCity => 'مدينة';

  @override
  String get searchSuggestArea => 'منطقة';

  @override
  String get searchSuggestClinic => 'عيادة أو مركز';

  @override
  String searchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم العثور على $count طبيب',
      one: 'تم العثور على طبيب واحد',
      zero: 'لا يوجد أطباء',
    );
    return '$_temp0';
  }

  @override
  String get searchSortLabel => 'الترتيب';

  @override
  String get searchSortFeatured => 'الأنسب';

  @override
  String get searchSortRating => 'الأعلى تقييماً';

  @override
  String get searchSortNewest => 'الأحدث';

  @override
  String get searchSortFeeAsc => 'الأقل سعراً';

  @override
  String get searchFilterButton => 'تصفية متقدمة';

  @override
  String get searchFilterTitle => 'تصفية النتائج';

  @override
  String get searchFilterRating => 'التقييم';

  @override
  String get searchFilterMaxFee => 'أقصى سعر للكشف';

  @override
  String get searchFilterBooking => 'الحجز الإلكتروني';

  @override
  String get searchFilterBookingOnly => 'المتاحون للحجز الإلكتروني فقط';

  @override
  String get searchAny => 'الكل';

  @override
  String get searchAnyPrice => 'أي سعر';

  @override
  String get searchGenderMale => 'طبيب';

  @override
  String get searchGenderFemale => 'طبيبة';

  @override
  String searchChipRating(String value) {
    return 'تقييم $value+';
  }

  @override
  String searchChipMaxFee(String fee) {
    return 'حتى $fee ج.م';
  }

  @override
  String get searchChipBooking => 'حجز إلكتروني';

  @override
  String get searchClearField => 'مسح البحث';

  @override
  String get searchEmptyTitle => 'لم نجد أطباء مطابقين لبحثك';

  @override
  String get searchEmptyHint =>
      'جرّب تغيير التخصص أو المنطقة أو إزالة بعض عوامل التصفية.';

  @override
  String get searchClearFilters => 'مسح الفلاتر';

  @override
  String get searchBookAppointment => 'احجز موعد كشف';

  @override
  String get searchCall => 'اتصال';

  @override
  String searchYearsShort(int years) {
    return '$years سنة خبرة';
  }

  @override
  String get navFavorites => 'المفضلة';

  @override
  String get favoritesTitle => 'الأطباء المفضلون';

  @override
  String favoritesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طبيب',
      many: '$count طبيباً',
      few: '$count أطباء',
      two: 'طبيبان',
      one: 'طبيب واحد',
    );
    return '$_temp0';
  }

  @override
  String get favoritesEmptyTitle => 'لم تقم بإضافة أطباء للمفضلة بعد';

  @override
  String get favoritesEmptyBody =>
      'أضف الأطباء الذين تفضلهم للوصول إليهم بسهولة لاحقًا.';

  @override
  String get favoritesFindDoctor => 'البحث عن طبيب';

  @override
  String get favoritesDoctorError => 'تعذّر تحميل بيانات هذا الطبيب.';

  @override
  String get favoritesLoadError => 'تعذّر تحميل قائمة المفضلة.';

  @override
  String get favoriteAdd => 'إضافة إلى المفضلة';

  @override
  String get favoriteRemove => 'إزالة من المفضلة';

  @override
  String get favoriteFailed => 'تعذّر حفظ التغيير. حاول مرة أخرى.';

  @override
  String get ratingNone => 'لا توجد تقييمات';

  @override
  String get navManagement => 'الإدارة';

  @override
  String get managementTitle => 'الإدارة';

  @override
  String get managementStatsTitle => 'إحصاءاتك';

  @override
  String managementStatsPeriod(int days) {
    return 'آخر $days يوم';
  }

  @override
  String get statPatients => 'عدد المرضى';

  @override
  String get statCompletedVisits => 'زيارات مكتملة';

  @override
  String get statRating => 'متوسط التقييم';

  @override
  String get statContactRate => 'معدل التواصل';

  @override
  String get statViews => 'مشاهدات الصفحة';

  @override
  String get statContacts => 'مرات التواصل';

  @override
  String get statBookings => 'حجوزات';

  @override
  String get statBookingsDone => 'تمت';

  @override
  String statViewsSub(int count) {
    return 'مشاهدات الصفحة: $count';
  }

  @override
  String get managementPortalButton => 'فتح نظام إدارة العيادة';

  @override
  String get managementPortalFailed => 'تعذّر فتح نظام الإدارة.';

  @override
  String get managementModulesTitle => 'إدارة العيادة';

  @override
  String get managementClinicsTitle => 'العيادات';

  @override
  String get managementClinicsDesc =>
      'إدارة العيادات وأسعار الكشف ومواعيد العمل';

  @override
  String get managementAssistantsTitle => 'المساعدون';

  @override
  String get managementAssistantsDesc => 'إدارة مساعدي العيادة وصلاحياتهم';

  @override
  String get managementScheduleTitle => 'الجدول';

  @override
  String get managementScheduleDesc => 'المواعيد وأوقات التوفّر';

  @override
  String get managementSaved => 'تم الحفظ';

  @override
  String get managementDelete => 'حذف';

  @override
  String get managementFailed => 'تعذّر إتمام العملية. حاول مرة أخرى.';

  @override
  String get weekday1 => 'الاثنين';

  @override
  String get weekday2 => 'الثلاثاء';

  @override
  String get weekday3 => 'الأربعاء';

  @override
  String get weekday4 => 'الخميس';

  @override
  String get weekday5 => 'الجمعة';

  @override
  String get weekday6 => 'السبت';

  @override
  String get weekday7 => 'الأحد';

  @override
  String get clinicsTitle => 'العيادات';

  @override
  String get clinicsAdd => 'إضافة عيادة';

  @override
  String get clinicsEmptyTitle => 'لم تُضف أي عيادة بعد';

  @override
  String get clinicsEmptyBody => 'أضف عيادتك لتبدأ باستقبال الحجوزات.';

  @override
  String get clinicBadgePrimary => 'العيادة الرئيسية';

  @override
  String get clinicBadgeOwner => 'أنشأتها';

  @override
  String get clinicBadgeInactive => 'معطّلة';

  @override
  String get clinicReady => 'جاهزة لاستقبال الحجوزات';

  @override
  String get clinicNotReady => 'غير جاهزة لاستقبال الحجوزات بعد';

  @override
  String get clinicTermsTitle => 'شروطي في هذه العيادة';

  @override
  String get clinicFeeConsult => 'سعر الكشف';

  @override
  String get clinicFeeFollowup => 'سعر الاستشارة/المتابعة';

  @override
  String get clinicAcceptBookings => 'استقبال الحجوزات';

  @override
  String get clinicSaveTerms => 'حفظ الشروط';

  @override
  String get clinicHoursTitle => 'مواعيد العمل';

  @override
  String get clinicHoursHint =>
      'حدد مواعيد فتح العيادة لكل يوم. الحجوزات تُولَّد داخل هذه المواعيد فقط.';

  @override
  String get clinicHoursNone => 'لم تُحدَّد مواعيد العمل بعد.';

  @override
  String get clinicHoursFrom => 'من';

  @override
  String get clinicHoursTo => 'إلى';

  @override
  String get clinicAddShift => 'إضافة فترة';

  @override
  String get clinicSaveHours => 'حفظ المواعيد';

  @override
  String get clinicInviteTitle => 'دعوة طبيب';

  @override
  String get clinicInvitePhone => 'رقم هاتف الطبيب';

  @override
  String get clinicInviteMessage => 'رسالة (اختياري)';

  @override
  String get clinicInviteSend => 'إرسال الدعوة';

  @override
  String get clinicInviteSent => 'تم إرسال الدعوة';

  @override
  String get clinicInvitesSent => 'الدعوات المرسلة';

  @override
  String get clinicInvitesNone => 'لا توجد دعوات مرسلة.';

  @override
  String get invitationPending => 'قيد الانتظار';

  @override
  String get invitationAccepted => 'مقبولة';

  @override
  String get invitationDeclined => 'مرفوضة';

  @override
  String get invitationCancelled => 'ملغاة';

  @override
  String get clinicFormName => 'اسم العيادة';

  @override
  String get clinicFormAddress => 'العنوان';

  @override
  String get clinicFormPhone => 'هاتف العيادة';

  @override
  String get clinicFormCreate => 'إنشاء العيادة';

  @override
  String get assistantsTitle => 'المساعدون';

  @override
  String get assistantsAdd => 'إضافة مساعد';

  @override
  String get assistantsEmptyTitle => 'لم يتم إضافة أي مساعد بعد';

  @override
  String get assistantsEmptyBody =>
      'أضف مساعدًا ليتولى الحجوزات نيابةً عنك، وحدد ما يُسمح له به.';

  @override
  String get assistantAllClinics => 'كل العيادات';

  @override
  String get assistantInactive => 'غير نشط';

  @override
  String get assistantPermissions => 'الصلاحيات';

  @override
  String assistantPermissionsCount(int count) {
    return '$count صلاحية';
  }

  @override
  String get assistantRevoke => 'سحب الوصول';

  @override
  String assistantRevokeConfirm(String clinic) {
    return 'سحب وصول هذا المساعد إلى «$clinic»؟';
  }

  @override
  String get assistantFormName => 'اسم المساعد';

  @override
  String get assistantFormPhone => 'رقم الهاتف';

  @override
  String get assistantFormNotes => 'ملاحظات (اختياري)';

  @override
  String get assistantFormClinic => 'العيادة';

  @override
  String get assistantCreate => 'إضافة المساعد';

  @override
  String get flag_can_view_bookings => 'عرض الحجوزات';

  @override
  String get flag_can_create_bookings => 'إنشاء حجوزات';

  @override
  String get flag_can_update_bookings => 'تعديل الحجوزات';

  @override
  String get flag_can_cancel_bookings => 'إلغاء الحجوزات';

  @override
  String get flag_can_manage_schedule => 'إدارة الجدول';

  @override
  String get flag_can_view_patient_phone => 'رؤية هاتف المريض';

  @override
  String get flag_can_create_patient_next_visit => 'حجز زيارة تالية للمريض';

  @override
  String get flag_can_request_duration_verification => 'طلب توثيق مدة الزيارة';

  @override
  String get flag_can_review_payment_proofs => 'مراجعة إثباتات الدفع';

  @override
  String get scheduleTitle => 'الجدول';

  @override
  String get scheduleTabBookings => 'المواعيد';

  @override
  String get scheduleTabAvailability => 'أوقات التوفّر';

  @override
  String get scheduleView => 'العرض';

  @override
  String get scheduleViewUpcoming => 'القادمة';

  @override
  String get scheduleViewAll => 'الكل';

  @override
  String get scheduleDate => 'يوم محدد';

  @override
  String get scheduleDateAny => 'كل الأيام';

  @override
  String get scheduleStatus => 'الحالة';

  @override
  String get scheduleStatusAll => 'كل الحالات';

  @override
  String scheduleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count موعد',
      few: '$count مواعيد',
      two: 'موعدان',
      one: 'موعد واحد',
      zero: 'لا مواعيد',
    );
    return '$_temp0';
  }

  @override
  String get scheduleEmpty => 'لا توجد مواعيد.';

  @override
  String get scheduleEmptyHint => 'جرّب تغيير العرض أو الحالة أو اليوم.';

  @override
  String get scheduleConfirm => 'تأكيد';

  @override
  String get scheduleComplete => 'اكتملت';

  @override
  String get scheduleNoShow => 'لم يحضر';

  @override
  String get scheduleCancel => 'إلغاء الموعد';

  @override
  String get scheduleCancelReason => 'سبب الإلغاء (اختياري)';

  @override
  String get scheduleNoShowHint =>
      'خيار «لم يحضر» يظهر بعد مرور موعد الكشف بعشر دقائق.';

  @override
  String get scheduleUpdated => 'تم تحديث الموعد';

  @override
  String get windowsAdd => 'إضافة فترة توفّر';

  @override
  String get windowsEmpty => 'لم تحدد أوقات توفّر بعد.';

  @override
  String get windowsEmptyHint => 'أضف الأيام والساعات التي تستقبل فيها المرضى.';

  @override
  String windowMinutes(int minutes) {
    return '$minutes دقيقة للموعد';
  }

  @override
  String get windowDeleteConfirm => 'حذف فترة التوفّر هذه؟';

  @override
  String get windowFormWeekday => 'اليوم';

  @override
  String get windowFormClinic => 'العيادة';

  @override
  String get windowFormDuration => 'مدة الموعد (بالدقائق)';

  @override
  String get windowCreate => 'إضافة';

  @override
  String get statusCancelledByPatient => 'ألغاه المريض';

  @override
  String get statusCancelledByClinic => 'ألغته العيادة';

  @override
  String scheduleDuration(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get scheduleDatePick => 'اختر اليوم';

  @override
  String get blockClinicHoursNotSet => 'لم تُحدَّد مواعيد عمل العيادة بعد';

  @override
  String get blockBookingDisabled =>
      'استقبال الحجوزات الإلكترونية متوقف في شروطك';

  @override
  String get blockNoAvailabilityWindows =>
      'لم تحدد أوقات توفّرك بعد (من الجدول ← أوقات التوفّر)';

  @override
  String get dpTitle => 'الملف المهني';

  @override
  String get dpEdit => 'تعديل';

  @override
  String get dpSaved => 'تم حفظ الملف المهني';

  @override
  String get dpSentForReview =>
      'بعض التغييرات أُرسلت لمراجعة الإدارة قبل أن تظهر.';

  @override
  String get dpReviewNote => 'يراجع تغيير هذا الحقل من الإدارة قبل تطبيقه.';

  @override
  String get dpInvalidNumber => 'أدخل رقمًا صحيحًا';

  @override
  String get dpNothingChanged => 'لم تغيّر شيئًا.';

  @override
  String get dpSectionBasic => 'المعلومات الأساسية';

  @override
  String get dpSectionProfessional => 'المعلومات المهنية';

  @override
  String get dpSectionBio => 'النبذة والرؤية';

  @override
  String get dpSectionExperience => 'الخبرات';

  @override
  String get dpSectionQualifications => 'المؤهلات والشهادات';

  @override
  String get dpSectionServices => 'الخدمات والأسعار';

  @override
  String get dpSectionContact => 'التواصل';

  @override
  String get dpSectionLinks => 'الروابط وحسابات التواصل';

  @override
  String get dpSectionSearch => 'الظهور في نتائج البحث';

  @override
  String get dpEducationTitle => 'المؤهلات العلمية';

  @override
  String get dpCertificatesTitle => 'الشهادات';

  @override
  String get dpCertPublic => 'ظاهرة للمرضى';

  @override
  String get dpServiceInactive => 'غير مفعّلة';

  @override
  String get dpSpecializations => 'التخصصات';

  @override
  String get dpPrimarySpec => 'الرئيسي';

  @override
  String get dpStatusDraft => 'مسودة';

  @override
  String get dpStatusPending => 'قيد المراجعة';

  @override
  String get dpStatusApproved => 'معتمد';

  @override
  String get dpStatusRejected => 'مرفوض';

  @override
  String get dpRejectionReason => 'سبب الرفض';

  @override
  String get dpAccountTile => 'بيانات الحساب';

  @override
  String get dpAccountTileHint => 'الاسم الأول واسم العائلة والبريد الإلكتروني';

  @override
  String get dpOpenLink => 'فتح الرابط';

  @override
  String get dpLinkFailed => 'تعذّر فتح الرابط.';

  @override
  String get dpField_full_name_ar => 'الاسم بالعربية';

  @override
  String get dpField_full_name_en => 'الاسم بالإنجليزية';

  @override
  String get dpField_display_title => 'اللقب (د. / أ.د.)';

  @override
  String get dpField_gender => 'النوع';

  @override
  String get dpField_city => 'المحافظة';

  @override
  String get dpField_area => 'المنطقة';

  @override
  String get dpField_professional_title_ar => 'المسمى المهني بالعربية';

  @override
  String get dpField_professional_title_en => 'المسمى المهني بالإنجليزية';

  @override
  String get dpField_academic_degree_ar => 'الدرجة العلمية';

  @override
  String get dpField_years_of_experience => 'سنوات الخبرة';

  @override
  String get dpField_default_consultation_fee => 'سعر الكشف الافتراضي';

  @override
  String get dpField_bio_ar => 'نبذة تعريفية بالعربية';

  @override
  String get dpField_bio_en => 'نبذة تعريفية بالإنجليزية';

  @override
  String get dpField_vision_ar => 'الرؤية الطبية أو الرسالة المهنية';

  @override
  String get dpField_current_positions_ar => 'المناصب الحالية';

  @override
  String get dpField_past_positions_ar => 'المناصب السابقة';

  @override
  String get dpField_certifications_ar => 'الشهادات / الترخيص الطبي';

  @override
  String get dpField_fellowships_ar => 'الزمالات والدبلومات';

  @override
  String get dpField_phone => 'رقم الهاتف';

  @override
  String get dpField_whatsapp => 'واتساب';

  @override
  String get dpField_website => 'الموقع الإلكتروني';

  @override
  String get dpField_external_booking_url => 'رابط الحجز الخارجي';

  @override
  String get dpField_google_maps_url => 'رابط خرائط جوجل';

  @override
  String get dpField_facebook => 'فيسبوك';

  @override
  String get dpField_instagram => 'إنستجرام';

  @override
  String get dpField_linkedin => 'لينكد إن';

  @override
  String get dpField_youtube => 'يوتيوب';

  @override
  String get dpField_tiktok => 'تيك توك';

  @override
  String get dpField_seo_title => 'عنوان الصفحة في البحث';

  @override
  String get dpField_seo_description => 'وصف الصفحة في البحث';

  @override
  String get ddStatExperience => 'سنوات الخبرة';

  @override
  String ddStatYears(int years) {
    return '$years سنة';
  }

  @override
  String get ddStatRating => 'التقييم';

  @override
  String get ddStatFee => 'الكشف يبدأ من';

  @override
  String get ddStatClinics => 'العيادات';

  @override
  String ddMoney(String amount) {
    return '$amount ج.م';
  }

  @override
  String get ddShowMore => 'عرض المزيد';

  @override
  String get ddShowLess => 'عرض أقل';

  @override
  String get ddServices => 'الخدمات';

  @override
  String get ddBookAtClinic => 'احجز موعد';

  @override
  String get ddOpenLocation => 'فتح الموقع';

  @override
  String get ddPhoneOnly => 'الحجز عبر الهاتف فقط';

  @override
  String get ddLinksTitle => 'الموقع والروابط';

  @override
  String get ddMapLink => 'الموقع على الخريطة';

  @override
  String get ddNextAvailable => 'أقرب موعد متاح';

  @override
  String get ddNoSlotsShort => 'لا توجد مواعيد متاحة حاليًا';

  @override
  String get ddReviewsMore => 'عرض المزيد من التقييمات';

  @override
  String get ddReviewVerified => 'زيارة مؤكدة';

  @override
  String get ddReviewPatient => 'مريض';

  @override
  String get ddReviewsFailed => 'تعذّر تحميل التقييمات.';

  @override
  String get ddReviewsMoreFailed => 'تعذّر تحميل المزيد من التقييمات.';

  @override
  String get ddBackTooltip => 'رجوع';

  @override
  String get bkChooseClinic => 'اختر العيادة';

  @override
  String get bkChooseClinicHint =>
      'يعمل الطبيب في أكثر من عيادة. اختر العيادة التي تناسبك.';

  @override
  String get bkChangeClinic => 'تغيير';

  @override
  String bkSlotsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count موعد',
      many: '$count موعدًا',
      few: '$count مواعيد',
      two: 'موعدان',
      one: 'موعد واحد',
    );
    return '$_temp0';
  }

  @override
  String get bkPickTimeHint => 'اختر وقتًا لإتمام الحجز';

  @override
  String get bkTimezoneNote => 'المواعيد معروضة بتوقيت العيادة.';

  @override
  String get bkSlotUnavailable => 'غير متاح';

  @override
  String get bkPaymentRequired => 'تطلب هذه العيادة دفع الرسوم مسبقًا.';

  @override
  String get bkSignInToBook => 'سجّل الدخول لتأكيد الحجز';

  @override
  String get bkViewBooking => 'عرض تفاصيل الحجز';

  @override
  String get bkDone => 'تم';

  @override
  String get bkDoctor => 'الطبيب';

  @override
  String bkDuration(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get bkDurationLabel => 'المدة';

  @override
  String get bkClose => 'إغلاق';

  @override
  String get bkTime => 'الوقت';

  @override
  String get bkVerifyPhoneTitle => 'أكّد رقم هاتفك لإتمام الحجز';

  @override
  String bkVerifyPhoneBody(String phone) {
    return 'يتطلب الحجز رقم هاتف مؤكَّدًا. سنرسل رمز تحقق إلى $phone.';
  }

  @override
  String get bkVerifyPhoneAction => 'تأكيد رقم الهاتف';

  @override
  String get errorDoctorBusy => 'الطبيب محجوز في هذا الوقت. اختر موعدًا آخر.';

  @override
  String get mbSubtitle => 'تابع مواعيدك الطبية بسهولة';

  @override
  String get mbTabCancelled => 'الملغاة';

  @override
  String get mbNextAppointment => 'موعدك القادم';

  @override
  String get mbMoreUpcoming => 'مواعيد قادمة أخرى';

  @override
  String get mbViewDetails => 'عرض تفاصيل الحجز';

  @override
  String get mbFindDoctor => 'ابحث عن طبيب';

  @override
  String get mbEmptyUpcomingTitle => 'لا توجد حجوزات قادمة';

  @override
  String get mbEmptyUpcomingBody =>
      'احجز موعدك الطبي بسهولة مع الطبيب المناسب.';

  @override
  String get mbEmptyPastTitle => 'لا توجد حجوزات سابقة';

  @override
  String get mbEmptyPastBody => 'ستظهر هنا زياراتك بعد انتهاء مواعيدها.';

  @override
  String get mbEmptyCancelledTitle => 'لا توجد حجوزات ملغاة';

  @override
  String get mbEmptyCancelledBody => 'أي حجز يُلغى سيظهر هنا.';

  @override
  String get mbErrorTitle => 'تعذّر تحميل حجوزاتك';

  @override
  String get mbErrorBody => 'حدث خطأ أثناء تحميل الحجوزات. حاول مرة أخرى.';

  @override
  String get mbOfflineBody => 'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.';

  @override
  String get mbNow => 'الآن';

  @override
  String mbInMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      many: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتين',
      one: 'دقيقة',
    );
    return 'بعد $_temp0';
  }

  @override
  String mbInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعة',
      many: '$count ساعة',
      few: '$count ساعات',
      two: 'ساعتين',
      one: 'ساعة',
    );
    return 'بعد $_temp0';
  }

  @override
  String mbInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومين',
      one: 'يوم',
    );
    return 'بعد $_temp0';
  }

  @override
  String get bdTitle => 'تفاصيل الحجز';

  @override
  String get bdYourAppointment => 'موعدك';

  @override
  String get bdInfoTitle => 'معلومات الحجز';

  @override
  String get bdSpecialty => 'التخصص';

  @override
  String get bdDate => 'التاريخ';

  @override
  String get bdFee => 'رسوم الزيارة';

  @override
  String get bdReason => 'سبب الزيارة';

  @override
  String get bdNotes => 'ملاحظاتك للطبيب';

  @override
  String get bdPayment => 'الدفع';

  @override
  String get bdPayNotRequired => 'لا يتطلب دفعًا مسبقًا';

  @override
  String get bdPayProofPending => 'بانتظار إثبات الدفع';

  @override
  String get bdPayProofUploaded => 'تم رفع إثبات الدفع';

  @override
  String get bdPayAccepted => 'تم قبول الدفع';

  @override
  String get bdPayRejected => 'لم يُقبل إثبات الدفع';

  @override
  String get bdVisitConsultation => 'كشف';

  @override
  String get bdVisitProcedure => 'إجراء طبي';

  @override
  String get bdVisitCustom => 'زيارة';

  @override
  String get bdClinicTitle => 'العيادة والموقع';

  @override
  String get bdTimelineTitle => 'حالة الحجز';

  @override
  String get bdStepBooked => 'تم الحجز';

  @override
  String get bdStepAwaiting => 'بانتظار تأكيد العيادة';

  @override
  String get bdStepConfirmed => 'تم تأكيد الحجز';

  @override
  String get bdStepAppointment => 'موعد الكشف';

  @override
  String get bdStepCompleted => 'تمت الزيارة';

  @override
  String get bdStepNoShow => 'لم يتم الحضور';

  @override
  String get bdStepCancelledByPatient => 'ألغيتَ هذا الحجز';

  @override
  String get bdStepCancelledByClinic => 'ألغت العيادة هذا الحجز';

  @override
  String get bdStepExpired => 'انتهت صلاحية الحجز';

  @override
  String get bdStepRescheduled => 'تم تغيير هذا الموعد';

  @override
  String bdCancelBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعة',
      many: '$count ساعة',
      few: '$count ساعات',
      two: 'ساعتين',
      one: 'ساعة',
    );
    return 'يمكنك إلغاء الحجز حتى قبل موعدك بـ$_temp0.';
  }

  @override
  String get bdCancelClosed =>
      'انتهت مهلة الإلغاء الإلكتروني. للإلغاء تواصل مع العيادة.';

  @override
  String get bdCancellationReason => 'سبب الإلغاء';

  @override
  String get bdCancelKeep => 'تراجع';

  @override
  String get bdCancelConfirm => 'إلغاء الحجز';

  @override
  String get bdBookAgain => 'احجز موعدًا آخر';

  @override
  String get bdBookNew => 'احجز موعدًا جديدًا';

  @override
  String get bdCallClinic => 'اتصال بالعيادة';

  @override
  String get bdViewDoctor => 'عرض صفحة الطبيب';

  @override
  String get hmSearchHint => 'ابحث عن طبيب أو تخصص';

  @override
  String get hmQuickDoctors => 'كل الأطباء';

  @override
  String get hmQuickSpecialties => 'التخصصات';

  @override
  String get hmQuickOnline => 'حجز إلكتروني';

  @override
  String get hmQuickLowestFee => 'الأقل سعرًا';

  @override
  String get hmRecommendedTitle => 'أطباء مقترحون';

  @override
  String get hmAllSpecialties => 'كل التخصصات';

  @override
  String hmSpecialtyDoctors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طبيب',
      many: '$count طبيبًا',
      few: '$count أطباء',
      two: 'طبيبان',
      one: 'طبيب واحد',
      zero: 'لا يوجد أطباء بعد',
    );
    return '$_temp0';
  }

  @override
  String get hmBookNow => 'احجز الآن';

  @override
  String get hmViewProfile => 'عرض الملف';

  @override
  String get hmOnlineBooking => 'حجز إلكتروني';

  @override
  String get hmPhoneBooking => 'حجز عبر الهاتف';

  @override
  String get hmSeeAllDoctors => 'عرض كل الأطباء';

  @override
  String get hmClinicDoctors => 'عرض الأطباء';

  @override
  String get hmLoadErrorTitle => 'تعذّر تحميل البيانات';

  @override
  String get hmLoadErrorBody => 'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.';

  @override
  String get hmGuestTitle => 'سجّل الدخول لتجربة أفضل';

  @override
  String get hmJoinCta => 'هل أنت طبيب؟ انضم إلى العيادة';

  @override
  String get acSectionAccount => 'الحساب';

  @override
  String get acSectionSettings => 'الإعدادات';

  @override
  String get acPhoneVerified => 'رقم الهاتف موثّق';

  @override
  String get acPhoneUnverified => 'رقم الهاتف غير موثّق';

  @override
  String get acVerifyNow => 'تأكيد الرقم';

  @override
  String get acJoinNow => 'انضم الآن';

  @override
  String get acLanguageSheetTitle => 'اختر اللغة';

  @override
  String get acGuestTitle => 'مرحباً بك';

  @override
  String acUnreadBadge(int count) {
    return '$count جديد';
  }

  @override
  String get pfPersonalDetails => 'المعلومات الشخصية';

  @override
  String get pfContactDetails => 'بيانات التواصل';

  @override
  String get pfPhoneReadOnly =>
      'رقم الهاتف هو وسيلة تسجيل الدخول، ولا يمكن تغييره من هنا.';

  @override
  String get pfSaveChanges => 'حفظ التغييرات';

  @override
  String get pfReadOnly => 'للعرض فقط';

  @override
  String get ntToday => 'اليوم';

  @override
  String get ntYesterday => 'أمس';

  @override
  String get ntEarlier => 'أقدم';

  @override
  String ntUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إشعار غير مقروء',
      many: '$count إشعارًا غير مقروء',
      few: '$count إشعارات غير مقروءة',
      two: 'إشعاران غير مقروءين',
      one: 'إشعار واحد غير مقروء',
    );
    return '$_temp0';
  }

  @override
  String get ntAllRead => 'لا توجد إشعارات غير مقروءة';

  @override
  String get ntEmptyTitle => 'لا توجد إشعارات';

  @override
  String get ntEmptyBody => 'سنخبرك هنا بكل جديد يتعلق بحجوزاتك.';

  @override
  String get ntErrorTitle => 'تعذّر تحميل الإشعارات';

  @override
  String get ntErrorBody => 'حدث خطأ أثناء التحميل. حاول مرة أخرى.';

  @override
  String get ntOffline => 'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.';

  @override
  String get ntLoadOlder => 'عرض الإشعارات الأقدم';

  @override
  String get ntUnread => 'غير مقروء';

  @override
  String get ntUpdateFailed => 'تعذّر تحديث الإشعارات. حاول مرة أخرى.';

  @override
  String get ntRefreshFailed => 'تعذّر تحديث القائمة.';

  @override
  String get auShowPassword => 'إظهار كلمة المرور';

  @override
  String get auHidePassword => 'إخفاء كلمة المرور';

  @override
  String get auReadPolicy => 'قراءة';

  @override
  String get auForgotBody =>
      'أدخل رقم هاتفك المسجّل لإرسال رمز إعادة تعيين كلمة المرور.';

  @override
  String get auLogoLabel => 'شعار العيادة';

  @override
  String get auPoliciesRetry => 'تعذّر تحميل الشروط. حاول مرة أخرى.';
}
