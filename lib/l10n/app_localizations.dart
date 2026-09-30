import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar'), Locale('en')];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'العيادة'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In ar, this message translates to:
  /// **'منصة طبية تساعدك تصل للطبيب المناسب بسهولة'**
  String get appTagline;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navDoctors.
  ///
  /// In ar, this message translates to:
  /// **'الأطباء'**
  String get navDoctors;

  /// No description provided for @navBookings.
  ///
  /// In ar, this message translates to:
  /// **'حجوزاتي'**
  String get navBookings;

  /// No description provided for @navAccount.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get navAccount;

  /// No description provided for @navDashboard.
  ///
  /// In ar, this message translates to:
  /// **'لوحة التحكم'**
  String get navDashboard;

  /// No description provided for @navSchedule.
  ///
  /// In ar, this message translates to:
  /// **'الجدول'**
  String get navSchedule;

  /// No description provided for @navNotifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get navNotifications;

  /// No description provided for @actionRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get actionCancel;

  /// No description provided for @actionConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get actionConfirm;

  /// No description provided for @actionSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get actionSave;

  /// No description provided for @actionSaving.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الحفظ…'**
  String get actionSaving;

  /// No description provided for @actionClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get actionClose;

  /// No description provided for @actionBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get actionBack;

  /// No description provided for @actionNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get actionNext;

  /// No description provided for @actionDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get actionDone;

  /// No description provided for @actionSearch.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get actionSearch;

  /// No description provided for @actionFilter.
  ///
  /// In ar, this message translates to:
  /// **'تصفية'**
  String get actionFilter;

  /// No description provided for @actionClearFilters.
  ///
  /// In ar, this message translates to:
  /// **'إزالة التصفية'**
  String get actionClearFilters;

  /// No description provided for @actionApply.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get actionApply;

  /// No description provided for @actionSeeAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get actionSeeAll;

  /// No description provided for @actionLoadMore.
  ///
  /// In ar, this message translates to:
  /// **'تحميل المزيد'**
  String get actionLoadMore;

  /// No description provided for @stateLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل…'**
  String get stateLoading;

  /// No description provided for @stateEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج'**
  String get stateEmpty;

  /// No description provided for @stateErrorTitle.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get stateErrorTitle;

  /// No description provided for @stateOfflineTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال'**
  String get stateOfflineTitle;

  /// No description provided for @stateOfflineBody.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من اتصالك بالإنترنت ثم أعد المحاولة.'**
  String get stateOfflineBody;

  /// No description provided for @authSignIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get authSignIn;

  /// No description provided for @authSignOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get authSignOut;

  /// No description provided for @authSignUp.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get authSignUp;

  /// No description provided for @authPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get authPhone;

  /// No description provided for @authPhoneHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: 01012345678'**
  String get authPhoneHint;

  /// No description provided for @authEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get authPassword;

  /// No description provided for @authFullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get authFullName;

  /// No description provided for @authForgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get authForgotPassword;

  /// No description provided for @authNoAccount.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟'**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟'**
  String get authHaveAccount;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لمتابعة حجوزاتك ومواعيدك.'**
  String get authSignInSubtitle;

  /// No description provided for @authSignUpSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ حسابك لحجز المواعيد ومتابعتها.'**
  String get authSignUpSubtitle;

  /// No description provided for @authPhoneRequired.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك أدخل رقم الهاتف.'**
  String get authPhoneRequired;

  /// No description provided for @authPasswordRequired.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك أدخل كلمة المرور.'**
  String get authPasswordRequired;

  /// No description provided for @authNameRequired.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك أدخل الاسم.'**
  String get authNameRequired;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور قصيرة جدًا.'**
  String get authPasswordTooShort;

  /// No description provided for @authGuestPrompt.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لمتابعة حجوزاتك.'**
  String get authGuestPrompt;

  /// No description provided for @otpTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد رقم الهاتف'**
  String get otpTitle;

  /// No description provided for @otpSentTo.
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا رمز تأكيد إلى {phone}'**
  String otpSentTo(String phone);

  /// No description provided for @otpCode.
  ///
  /// In ar, this message translates to:
  /// **'رمز التأكيد'**
  String get otpCode;

  /// No description provided for @otpVerify.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get otpVerify;

  /// No description provided for @otpResend.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال الرمز'**
  String get otpResend;

  /// No description provided for @otpCodeRequired.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك أدخل الرمز.'**
  String get otpCodeRequired;

  /// No description provided for @consentTitle.
  ///
  /// In ar, this message translates to:
  /// **'الموافقة على الشروط'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك راجع الشروط وسياسة الخصوصية للمتابعة.'**
  String get consentBody;

  /// No description provided for @consentAccept.
  ///
  /// In ar, this message translates to:
  /// **'أوافق على الشروط وسياسة الخصوصية'**
  String get consentAccept;

  /// No description provided for @consentRequired.
  ///
  /// In ar, this message translates to:
  /// **'يجب الموافقة على الشروط للمتابعة.'**
  String get consentRequired;

  /// No description provided for @consentReacceptTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحديث الشروط'**
  String get consentReacceptTitle;

  /// No description provided for @consentReacceptBody.
  ///
  /// In ar, this message translates to:
  /// **'حدّثنا الشروط وسياسة الخصوصية. راجعها للمتابعة.'**
  String get consentReacceptBody;

  /// No description provided for @doctorsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأطباء'**
  String get doctorsTitle;

  /// No description provided for @doctorsSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث باسم الطبيب أو التخصص'**
  String get doctorsSearchHint;

  /// No description provided for @doctorsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أطباء مطابقون لهذا البحث.'**
  String get doctorsEmpty;

  /// No description provided for @doctorsFilterSpecialty.
  ///
  /// In ar, this message translates to:
  /// **'التخصص'**
  String get doctorsFilterSpecialty;

  /// No description provided for @doctorsFilterCity.
  ///
  /// In ar, this message translates to:
  /// **'المدينة'**
  String get doctorsFilterCity;

  /// No description provided for @doctorsFilterArea.
  ///
  /// In ar, this message translates to:
  /// **'المنطقة'**
  String get doctorsFilterArea;

  /// No description provided for @doctorsFilterGender.
  ///
  /// In ar, this message translates to:
  /// **'نوع الطبيب'**
  String get doctorsFilterGender;

  /// No description provided for @doctorsFilterAny.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get doctorsFilterAny;

  /// No description provided for @doctorsFilterMale.
  ///
  /// In ar, this message translates to:
  /// **'ذكر'**
  String get doctorsFilterMale;

  /// No description provided for @doctorsFilterFemale.
  ///
  /// In ar, this message translates to:
  /// **'أنثى'**
  String get doctorsFilterFemale;

  /// No description provided for @doctorsResultCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا نتائج} =1{نتيجة واحدة} other{{count} نتيجة}}'**
  String doctorsResultCount(int count);

  /// No description provided for @doctorYearsExperience.
  ///
  /// In ar, this message translates to:
  /// **'{years} سنة خبرة'**
  String doctorYearsExperience(int years);

  /// No description provided for @doctorReviewsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا تقييمات} =1{تقييم واحد} other{{count} تقييم}}'**
  String doctorReviewsCount(int count);

  /// No description provided for @doctorFeeFrom.
  ///
  /// In ar, this message translates to:
  /// **'تبدأ من {fee} ج.م'**
  String doctorFeeFrom(String fee);

  /// No description provided for @doctorAbout.
  ///
  /// In ar, this message translates to:
  /// **'نبذة عن الطبيب'**
  String get doctorAbout;

  /// No description provided for @doctorClinics.
  ///
  /// In ar, this message translates to:
  /// **'العيادات'**
  String get doctorClinics;

  /// No description provided for @doctorWorkingHours.
  ///
  /// In ar, this message translates to:
  /// **'مواعيد العمل'**
  String get doctorWorkingHours;

  /// No description provided for @doctorReviews.
  ///
  /// In ar, this message translates to:
  /// **'التقييمات'**
  String get doctorReviews;

  /// No description provided for @doctorNoReviews.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تقييمات بعد.'**
  String get doctorNoReviews;

  /// No description provided for @doctorBookNow.
  ///
  /// In ar, this message translates to:
  /// **'احجز موعدًا'**
  String get doctorBookNow;

  /// No description provided for @doctorCall.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get doctorCall;

  /// No description provided for @doctorWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get doctorWhatsapp;

  /// No description provided for @doctorBookingUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الحجز الإلكتروني غير متاح لهذا الطبيب — تواصل مع العيادة مباشرة.'**
  String get doctorBookingUnavailable;

  /// No description provided for @doctorVerified.
  ///
  /// In ar, this message translates to:
  /// **'طبيب موثّق'**
  String get doctorVerified;

  /// No description provided for @bookingTitle.
  ///
  /// In ar, this message translates to:
  /// **'حجز موعد'**
  String get bookingTitle;

  /// No description provided for @bookingChooseDay.
  ///
  /// In ar, this message translates to:
  /// **'اختر اليوم'**
  String get bookingChooseDay;

  /// No description provided for @bookingChooseTime.
  ///
  /// In ar, this message translates to:
  /// **'اختر الوقت'**
  String get bookingChooseTime;

  /// No description provided for @bookingNoSlots.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواعيد متاحة في هذا اليوم.'**
  String get bookingNoSlots;

  /// No description provided for @bookingNoSlotsAtAll.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواعيد متاحة حاليًا. تواصل مع العيادة للاستفسار.'**
  String get bookingNoSlotsAtAll;

  /// No description provided for @bookingSummary.
  ///
  /// In ar, this message translates to:
  /// **'ملخص الحجز'**
  String get bookingSummary;

  /// No description provided for @bookingConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحجز'**
  String get bookingConfirm;

  /// No description provided for @bookingFee.
  ///
  /// In ar, this message translates to:
  /// **'سعر الكشف'**
  String get bookingFee;

  /// No description provided for @bookingClinic.
  ///
  /// In ar, this message translates to:
  /// **'العيادة'**
  String get bookingClinic;

  /// No description provided for @bookingDateTime.
  ///
  /// In ar, this message translates to:
  /// **'الموعد'**
  String get bookingDateTime;

  /// No description provided for @bookingSuccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد حجزك'**
  String get bookingSuccessTitle;

  /// No description provided for @bookingSuccessBody.
  ///
  /// In ar, this message translates to:
  /// **'سنرسل لك تنبيهًا قبل الموعد.'**
  String get bookingSuccessBody;

  /// No description provided for @bookingVisitType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الزيارة'**
  String get bookingVisitType;

  /// No description provided for @bookingVisitFirst.
  ///
  /// In ar, this message translates to:
  /// **'زيارة أولى'**
  String get bookingVisitFirst;

  /// No description provided for @bookingVisitFollowUp.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get bookingVisitFollowUp;

  /// No description provided for @bookingNotes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات (اختياري)'**
  String get bookingNotes;

  /// No description provided for @bookingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'حجوزاتي'**
  String get bookingsTitle;

  /// No description provided for @bookingsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حجوزات بعد.'**
  String get bookingsEmpty;

  /// No description provided for @bookingsEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن طبيب واحجز موعدك الأول.'**
  String get bookingsEmptyHint;

  /// No description provided for @bookingsUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'القادمة'**
  String get bookingsUpcoming;

  /// No description provided for @bookingsPast.
  ///
  /// In ar, this message translates to:
  /// **'السابقة'**
  String get bookingsPast;

  /// No description provided for @bookingCancelTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحجز'**
  String get bookingCancelTitle;

  /// No description provided for @bookingCancelBody.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد إلغاء هذا الحجز؟'**
  String get bookingCancelBody;

  /// No description provided for @bookingCancelReason.
  ///
  /// In ar, this message translates to:
  /// **'سبب الإلغاء (اختياري)'**
  String get bookingCancelReason;

  /// No description provided for @bookingCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الحجز.'**
  String get bookingCancelled;

  /// No description provided for @bookingReschedule.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الموعد'**
  String get bookingReschedule;

  /// No description provided for @bookingRescheduled.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير الموعد.'**
  String get bookingRescheduled;

  /// No description provided for @statusPending.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار التأكيد'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'مؤكد'**
  String get statusConfirmed;

  /// No description provided for @statusCompleted.
  ///
  /// In ar, this message translates to:
  /// **'تمت الزيارة'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغي'**
  String get statusCancelled;

  /// No description provided for @statusNoShow.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم الحضور'**
  String get statusNoShow;

  /// No description provided for @statusRescheduled.
  ///
  /// In ar, this message translates to:
  /// **'تم تغييره'**
  String get statusRescheduled;

  /// No description provided for @statusExpired.
  ///
  /// In ar, this message translates to:
  /// **'منتهي'**
  String get statusExpired;

  /// No description provided for @accountTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get accountTitle;

  /// No description provided for @accountProfile.
  ///
  /// In ar, this message translates to:
  /// **'بياناتي'**
  String get accountProfile;

  /// No description provided for @accountMyReviews.
  ///
  /// In ar, this message translates to:
  /// **'تقييماتي'**
  String get accountMyReviews;

  /// No description provided for @accountLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get accountLanguage;

  /// No description provided for @accountLanguageArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get accountLanguageArabic;

  /// No description provided for @accountLanguageEnglish.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get accountLanguageEnglish;

  /// No description provided for @accountSignOutConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تسجيل الخروج؟'**
  String get accountSignOutConfirm;

  /// No description provided for @accountFirstName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الأول'**
  String get accountFirstName;

  /// No description provided for @accountLastName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الأخير'**
  String get accountLastName;

  /// No description provided for @accountSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ بياناتك.'**
  String get accountSaved;

  /// No description provided for @joinTitle.
  ///
  /// In ar, this message translates to:
  /// **'انضم كطبيب'**
  String get joinTitle;

  /// No description provided for @joinIntro.
  ///
  /// In ar, this message translates to:
  /// **'أضف صفحتك على العيادة ليصل إليك المرضى.'**
  String get joinIntro;

  /// No description provided for @joinNameAr.
  ///
  /// In ar, this message translates to:
  /// **'اسم الطبيب بالعربية'**
  String get joinNameAr;

  /// No description provided for @joinNameEn.
  ///
  /// In ar, this message translates to:
  /// **'اسم الطبيب بالإنجليزية'**
  String get joinNameEn;

  /// No description provided for @joinNameEnHint.
  ///
  /// In ar, this message translates to:
  /// **'يُستخدم في رابط صفحتك'**
  String get joinNameEnHint;

  /// No description provided for @joinSpecialty.
  ///
  /// In ar, this message translates to:
  /// **'التخصص الرئيسي'**
  String get joinSpecialty;

  /// No description provided for @joinCity.
  ///
  /// In ar, this message translates to:
  /// **'المحافظة'**
  String get joinCity;

  /// No description provided for @joinArea.
  ///
  /// In ar, this message translates to:
  /// **'المنطقة'**
  String get joinArea;

  /// No description provided for @joinLicence.
  ///
  /// In ar, this message translates to:
  /// **'الشهادات / الترخيص الطبي'**
  String get joinLicence;

  /// No description provided for @joinLicenceHint.
  ///
  /// In ar, this message translates to:
  /// **'هذه البيانات تساعدنا على التحقق من حسابك بسرعة.'**
  String get joinLicenceHint;

  /// No description provided for @joinOnboardingScope.
  ///
  /// In ar, this message translates to:
  /// **'نستقبل حاليًا طلبات انضمام الأطباء في المناطق المتاحة بالقائمة فقط، ونتوسع قريبًا.'**
  String get joinOnboardingScope;

  /// No description provided for @joinRestLater.
  ///
  /// In ar, this message translates to:
  /// **'بقية بيانات صفحتك — الصورة والنبذة وسنوات الخبرة والروابط — تُستكمل من التطبيق بعد اعتماد حسابك.'**
  String get joinRestLater;

  /// No description provided for @joinSubmit.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get joinSubmit;

  /// No description provided for @joinSuccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل طلبك بنجاح'**
  String get joinSuccessTitle;

  /// No description provided for @joinSuccessBody.
  ///
  /// In ar, this message translates to:
  /// **'يراجع فريق العيادة بياناتك الآن، وسنتواصل معك على رقم هاتفك فور صدور القرار.'**
  String get joinSuccessBody;

  /// No description provided for @joinPatientUntilApproved.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك استخدام حسابك كمريض بشكل طبيعي في أثناء المراجعة.'**
  String get joinPatientUntilApproved;

  /// No description provided for @claimTitle.
  ///
  /// In ar, this message translates to:
  /// **'وجدنا صفحات قد تخصّك'**
  String get claimTitle;

  /// No description provided for @claimBody.
  ///
  /// In ar, this message translates to:
  /// **'إذا كانت إحدى هذه الصفحات لك، طالب بها بدلًا من إنشاء صفحة جديدة.'**
  String get claimBody;

  /// No description provided for @claimThisIsMe.
  ///
  /// In ar, this message translates to:
  /// **'هذه صفحتي'**
  String get claimThisIsMe;

  /// No description provided for @claimSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلب إثبات الملكية.'**
  String get claimSubmitted;

  /// No description provided for @claimSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطٍّ'**
  String get claimSkip;

  /// No description provided for @applicationPendingTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل طلبك بنجاح'**
  String get applicationPendingTitle;

  /// No description provided for @applicationPendingBody.
  ///
  /// In ar, this message translates to:
  /// **'يراجع فريق العيادة بياناتك الآن، وسنتواصل معك فور صدور القرار.'**
  String get applicationPendingBody;

  /// No description provided for @applicationClaimPendingTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب إثبات ملكية الصفحة قيد المراجعة'**
  String get applicationClaimPendingTitle;

  /// No description provided for @applicationClaimPendingBody.
  ///
  /// In ar, this message translates to:
  /// **'نراجع طلبك لإثبات ملكية صفحة {name}.'**
  String applicationClaimPendingBody(String name);

  /// No description provided for @applicationChangesTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلبك يحتاج إلى تعديل'**
  String get applicationChangesTitle;

  /// No description provided for @applicationChangesBody.
  ///
  /// In ar, this message translates to:
  /// **'راجع ملاحظة المراجع أدناه — سنتواصل معك على رقم هاتفك لاستكمال طلبك.'**
  String get applicationChangesBody;

  /// No description provided for @applicationRejectedTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم اعتماد طلبك'**
  String get applicationRejectedTitle;

  /// No description provided for @applicationRejectedBody.
  ///
  /// In ar, this message translates to:
  /// **'سنتواصل معك على رقم هاتفك لتوضيح الأسباب.'**
  String get applicationRejectedBody;

  /// No description provided for @applicationReviewerNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة المراجع:'**
  String get applicationReviewerNote;

  /// No description provided for @dashboardTitle.
  ///
  /// In ar, this message translates to:
  /// **'لوحة التحكم'**
  String get dashboardTitle;

  /// No description provided for @dashboardWelcome.
  ///
  /// In ar, this message translates to:
  /// **'أهلًا د. {name}'**
  String dashboardWelcome(String name);

  /// No description provided for @dashboardStatPatients.
  ///
  /// In ar, this message translates to:
  /// **'المرضى'**
  String get dashboardStatPatients;

  /// No description provided for @dashboardStatVisits.
  ///
  /// In ar, this message translates to:
  /// **'الزيارات'**
  String get dashboardStatVisits;

  /// No description provided for @dashboardStatRating.
  ///
  /// In ar, this message translates to:
  /// **'التقييم'**
  String get dashboardStatRating;

  /// No description provided for @dashboardStatViews.
  ///
  /// In ar, this message translates to:
  /// **'مشاهدات الصفحة'**
  String get dashboardStatViews;

  /// No description provided for @dashboardNotPublished.
  ///
  /// In ar, this message translates to:
  /// **'صفحتك غير منشورة بعد'**
  String get dashboardNotPublished;

  /// No description provided for @dashboardPublished.
  ///
  /// In ar, this message translates to:
  /// **'صفحتك منشورة'**
  String get dashboardPublished;

  /// No description provided for @dashboardActivationMissing.
  ///
  /// In ar, this message translates to:
  /// **'لإتمام نشر صفحتك، أكمل البيانات الناقصة.'**
  String get dashboardActivationMissing;

  /// No description provided for @dashboardTodayBookings.
  ///
  /// In ar, this message translates to:
  /// **'حجوزات اليوم'**
  String get dashboardTodayBookings;

  /// No description provided for @dashboardNoBookings.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حجوزات.'**
  String get dashboardNoBookings;

  /// No description provided for @dashboardMyClinics.
  ///
  /// In ar, this message translates to:
  /// **'عياداتي'**
  String get dashboardMyClinics;

  /// No description provided for @dashboardProfile.
  ///
  /// In ar, this message translates to:
  /// **'ملفي الطبي'**
  String get dashboardProfile;

  /// No description provided for @notificationsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In ar, this message translates to:
  /// **'تعليم الكل كمقروء'**
  String get notificationsMarkAllRead;

  /// No description provided for @reviewTitle.
  ///
  /// In ar, this message translates to:
  /// **'تقييم الزيارة'**
  String get reviewTitle;

  /// No description provided for @reviewRating.
  ///
  /// In ar, this message translates to:
  /// **'تقييمك'**
  String get reviewRating;

  /// No description provided for @reviewComment.
  ///
  /// In ar, this message translates to:
  /// **'تعليقك (اختياري)'**
  String get reviewComment;

  /// No description provided for @reviewSubmit.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التقييم'**
  String get reviewSubmit;

  /// No description provided for @reviewSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'شكرًا لك، تم إرسال تقييمك.'**
  String get reviewSubmitted;

  /// No description provided for @reviewableEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد زيارات بحاجة إلى تقييم.'**
  String get reviewableEmpty;

  /// No description provided for @errorGeneric.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع. حاول مرة أخرى.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالخادم. تحقق من الإنترنت.'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In ar, this message translates to:
  /// **'الخادم لا يستجيب حاليًا. حاول بعد قليل.'**
  String get errorServer;

  /// No description provided for @errorNotAuthenticated.
  ///
  /// In ar, this message translates to:
  /// **'من فضلك سجّل الدخول للمتابعة.'**
  String get errorNotAuthenticated;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'لا تملك صلاحية لهذا الإجراء.'**
  String get errorPermissionDenied;

  /// No description provided for @errorNotFound.
  ///
  /// In ar, this message translates to:
  /// **'العنصر المطلوب غير موجود.'**
  String get errorNotFound;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف أو كلمة المرور غير صحيحة.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorThrottled.
  ///
  /// In ar, this message translates to:
  /// **'حاولت كثيرًا. من فضلك انتظر قليلًا ثم أعد المحاولة.'**
  String get errorThrottled;

  /// No description provided for @errorAccountInactive.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحساب غير مُفعّل.'**
  String get errorAccountInactive;

  /// No description provided for @errorPhoneTaken.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرقم مسجل بالفعل.'**
  String get errorPhoneTaken;

  /// No description provided for @errorEmailTaken.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد الإلكتروني مسجل بالفعل.'**
  String get errorEmailTaken;

  /// No description provided for @errorSlotUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'هذا الموعد لم يعد متاحًا. اختر موعدًا آخر.'**
  String get errorSlotUnavailable;

  /// No description provided for @errorBookingConflict.
  ///
  /// In ar, this message translates to:
  /// **'لديك حجز آخر يتعارض مع هذا الموعد.'**
  String get errorBookingConflict;

  /// No description provided for @errorOutsideAvailability.
  ///
  /// In ar, this message translates to:
  /// **'هذا الوقت خارج مواعيد عمل الطبيب.'**
  String get errorOutsideAvailability;

  /// No description provided for @errorLeadTime.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن الحجز في هذا الوقت القريب. اختر موعدًا لاحقًا.'**
  String get errorLeadTime;

  /// No description provided for @errorTooManyBookings.
  ///
  /// In ar, this message translates to:
  /// **'لديك حجوزات كثيرة مع هذا الطبيب.'**
  String get errorTooManyBookings;

  /// No description provided for @errorInvalidOtp.
  ///
  /// In ar, this message translates to:
  /// **'الرمز غير صحيح أو انتهت صلاحيته.'**
  String get errorInvalidOtp;

  /// No description provided for @errorUploadTooLarge.
  ///
  /// In ar, this message translates to:
  /// **'حجم الملف كبير جدًا.'**
  String get errorUploadTooLarge;

  /// No description provided for @errorUnsupportedFile.
  ///
  /// In ar, this message translates to:
  /// **'نوع الملف غير مدعوم.'**
  String get errorUnsupportedFile;

  /// No description provided for @uploadChoosePhoto.
  ///
  /// In ar, this message translates to:
  /// **'اختر صورة'**
  String get uploadChoosePhoto;

  /// No description provided for @uploadFromCamera.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get uploadFromCamera;

  /// No description provided for @uploadFromGallery.
  ///
  /// In ar, this message translates to:
  /// **'معرض الصور'**
  String get uploadFromGallery;

  /// No description provided for @uploadProgress.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الرفع… {percent}%'**
  String uploadProgress(int percent);

  /// No description provided for @semanticDoctorPhoto.
  ///
  /// In ar, this message translates to:
  /// **'صورة الطبيب'**
  String get semanticDoctorPhoto;

  /// No description provided for @semanticRating.
  ///
  /// In ar, this message translates to:
  /// **'التقييم {value} من ٥'**
  String semanticRating(String value);

  /// No description provided for @semanticBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get semanticBack;

  /// No description provided for @semanticClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get semanticClose;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return LAr();
    case 'en':
      return LEn();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
