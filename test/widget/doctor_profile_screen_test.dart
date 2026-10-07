import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/profile/profile_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fixtures/doctor_profile_fixtures.dart';
import '../fixtures/management_fixtures.dart';
import 'harness.dart';

void main() {
  late TestHarness h;
  late ProfileServer server;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    h = TestHarness();
    server = ProfileServer(h.dio);
    h.adapter.onPost('/auth/logout/', (s) => s.reply(204, null));
    // refreshUser() after a save
    h.adapter.onGet('/auth/me/', (s) => s.reply(200, envelope(doctorUser())));
    container = ProviderContainer(overrides: h.overrides);
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> signIn(Map<String, dynamic> user) => container
      .read(authControllerProvider.notifier)
      .adoptSession(const AuthTokens(access: 'a', refresh: 'r'), user: Me.fromJson(user));

  Future<void> pumpProfile(
    WidgetTester tester, {
    Map<String, dynamic>? user,
    Locale locale = const Locale('ar'),
    // Tall, so the lazy list builds every section; the layout group below uses
    // real phone heights and scrolls instead.
    Size size = const Size(360, 4200),
    double textScale = 1.0,
    Widget home = const ProfileScreen(),
  }) async {
    await signIn(user ?? doctorUser());
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(
          path: Routes.editAccount,
          builder: (_, __) => Scaffold(appBar: AppBar(), body: const Text('account editor')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text, {bool last = false}) async {
    final f = last ? find.text(text).last : find.text(text).first;
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester, 4);
  }

  Future<void> startEditing(WidgetTester tester) => tapText(tester, 'تعديل');

  // ================================================================= view mode
  group('a doctor sees a professional profile', () {
    testWidgets('built from what the API returns, grouped into sections', (tester) async {
      await pumpProfile(tester);

      expect(find.text('الملف المهني'), findsOneWidget);
      expect(find.text('د. نرمين أحمد فؤاد'), findsOneWidget);
      expect(find.text('أخصائية أمراض النساء والتوليد وعلاج العقم'), findsWidgets);
      expect(find.text('معتمد'), findsOneWidget);
      expect(find.text('صفحتك منشورة'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('(5 تقييم)'), findsOneWidget);

      for (final title in [
        'المعلومات الأساسية',
        'المعلومات المهنية',
        'النبذة والرؤية',
        'الخبرات',
        'المؤهلات والشهادات',
        'التواصل',
        'الروابط وحسابات التواصل',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWidgets('each field with a value appears under its label', (tester) async {
      await pumpProfile(tester);
      for (final text in [
        'Nermeen Ahmed Fouad',
        'ماجستير طب النساء والتوليد',
        '10',
        '160.00',
        'أخصائية أمراض النساء والتوليد والعقم.',
        'رعاية طبية آمنة وواضحة.',
        'تعمل بمستشفى طنطا العام.',
        'سبق لها العمل في مستشفى دار القمة.',
        'ماجستير أمراض النساء والتوليد – جامعة بنها',
        'https://www.facebook.com/share/18DXiV3Cig/',
        'https://www.instagram.com/nenoelwakeel/',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('+201010636122'), findsNWidgets(2), reason: 'phone and WhatsApp');
      expect(find.text('أنثى'), findsOneWidget);
    });

    testWidgets('specialties, with the primary one marked', (tester) async {
      await pumpProfile(tester);
      expect(find.text('أمراض النساء والتوليد · الرئيسي'), findsOneWidget);
      expect(find.text('علاج العقم'), findsOneWidget);
    });

    testWidgets('city and area appear by name once the city list is known', (tester) async {
      await pumpProfile(tester);
      expect(find.text('الغربية'), findsOneWidget);
      expect(find.text('طنطا'), findsOneWidget);
      expect(find.text(cityId), findsNothing, reason: 'never a raw id');
    });

    testWidgets('education, certificates and services, from their own endpoints', (tester) async {
      await pumpProfile(tester);
      expect(find.text('المؤهلات العلمية'), findsOneWidget);
      expect(find.text('بكالوريوس الطب والجراحة'), findsOneWidget);
      expect(find.text('جامعة بنها · 2012'), findsOneWidget);
      expect(find.text('الشهادات'), findsOneWidget);
      expect(find.text('زمالة المجلس المصري'), findsOneWidget);
      expect(find.text('ظاهرة للمرضى'), findsOneWidget);
      expect(find.text('الخدمات والأسعار'), findsOneWidget);
      expect(find.text('متابعة حمل'), findsOneWidget);
      expect(find.text('250.00 ج.م'), findsOneWidget);
    });

    testWidgets('empty lists are not shown at all', (tester) async {
      server
        ..education = []
        ..certificates = []
        ..services = [];
      await pumpProfile(tester);
      for (final t in ['المؤهلات العلمية', 'الشهادات', 'الخدمات والأسعار']) {
        expect(find.text(t), findsNothing, reason: t);
      }
    });

    testWidgets('a rejected profile says why', (tester) async {
      server
        ..profile = ownProfile(overrides: {'verification_status': 'rejected', 'is_published': false})
        ..rejectionReason = 'الوثائق غير واضحة';
      await pumpProfile(tester);
      expect(find.text('مرفوض'), findsOneWidget);
      expect(find.text('صفحتك غير منشورة بعد'), findsOneWidget);
      expect(find.text('سبب الرفض: الوثائق غير واضحة'), findsOneWidget);
    });

    testWidgets('a draft and a profile under review are labelled', (tester) async {
      server.profile = ownProfile(overrides: {'verification_status': 'draft', 'credential_fields': <String>[]});
      await pumpProfile(tester);
      expect(find.text('مسودة'), findsOneWidget);
    });

    testWidgets('an unrated doctor shows no rating, not 0.0', (tester) async {
      server.profile = ownProfile(overrides: {'avg_rating': '0.00', 'reviews_count': 0});
      await pumpProfile(tester);
      expect(find.text('لا توجد تقييمات'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('links open outside the app', (tester) async {
      final launched = <Map<Object?, Object?>>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') launched.add(Map<Object?, Object?>.from(call.arguments as Map));
        return true;
      });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
      );
      await pumpProfile(tester);
      await tapText(tester, 'https://www.instagram.com/nenoelwakeel/');
      expect(launched.single['url'], 'https://www.instagram.com/nenoelwakeel/');
      expect(launched.single['useSafariVC'], false);
    });
  });

  // ============================================================= missing data
  group('missing and empty data', () {
    testWidgets('a sparse profile shows only what exists — no empty sections, no "null"', (tester) async {
      server.profile = {
        'id': 'p',
        'full_name_ar': 'سمير علي',
        'verification_status': 'draft',
        'is_published': false,
        'phone': null,
        'bio_ar': null,
        'years_of_experience': null,
        'default_consultation_fee': null,
        'social_links': null,
        'specializations': null,
        'editable_fields': <String>[],
        'credential_fields': <String>[],
      };
      server
        ..education = []
        ..certificates = []
        ..services = [];
      await pumpProfile(tester);

      expect(find.text('سمير علي'), findsWidgets, reason: 'the header, and its own row');
      for (final title in [
        'المعلومات المهنية',
        'النبذة والرؤية',
        'الخبرات',
        'المؤهلات والشهادات',
        'التواصل',
        'الروابط وحسابات التواصل',
        'الظهور في نتائج البحث',
      ]) {
        expect(find.text(title), findsNothing, reason: title);
      }
      expect(find.textContaining('null'), findsNothing);
      expect(find.text('تعديل'), findsNothing, reason: 'nothing editable');
    });

    testWidgets('empty text and null numbers are skipped, not shown as blanks', (tester) async {
      server.profile = ownProfile(overrides: {
        'bio_en': '',
        'professional_title_en': '   ',
        'years_of_experience': null,
        'default_consultation_fee': null,
        'website': null,
      });
      await pumpProfile(tester);
      expect(find.text('نبذة تعريفية بالإنجليزية'), findsNothing);
      expect(find.text('المسمى المهني بالإنجليزية'), findsNothing);
      expect(find.text('سنوات الخبرة'), findsNothing);
      expect(find.text('سعر الكشف الافتراضي'), findsNothing);
      expect(find.text('الموقع الإلكتروني'), findsNothing);
    });
  });

  // ================================================================ editing
  group('editing', () {
    testWidgets('every field the server lists as editable becomes an input', (tester) async {
      await pumpProfile(tester);
      await startEditing(tester);
      // 23 text-like fields and the five social networks (listed as social_links).
      expect(find.byType(TextField), findsNWidgets(27));
    });

    testWidgets('only the fields the server lists; the rest stay read-only text', (tester) async {
      server.profile = ownProfile(overrides: {'editable_fields': ['bio_ar', 'phone']});
      await pumpProfile(tester);
      await startEditing(tester);
      expect(find.byType(TextField), findsNWidgets(2));
      // A field not listed is still shown — as text.
      expect(find.text('Nermeen Ahmed Fouad'), findsOneWidget);
      expect(find.text('ماجستير طب النساء والتوليد'), findsOneWidget);
    });

    testWidgets('with nothing editable there is no edit button', (tester) async {
      server.profile = ownProfile(overrides: {'editable_fields': <String>[]});
      await pumpProfile(tester);
      expect(find.text('تعديل'), findsNothing);
    });

    testWidgets('an empty editable field can be filled in', (tester) async {
      server.profile = ownProfile(overrides: {'editable_fields': ['website'], 'website': ''});
      await pumpProfile(tester);
      expect(find.text('الموقع الإلكتروني'), findsNothing);
      await startEditing(tester);
      expect(find.text('الموقع الإلكتروني'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('fields held for review say so', (tester) async {
      server.profile = ownProfile(overrides: {
        'editable_fields': ['full_name_ar', 'bio_ar'],
        'credential_fields': ['full_name_ar'],
      });
      await pumpProfile(tester);
      await startEditing(tester);
      expect(find.text('يراجع تغيير هذا الحقل من الإدارة قبل تطبيقه.'), findsOneWidget, reason: 'only on the credential field');
    });

    testWidgets('a draft profile has no review notes', (tester) async {
      server.profile = ownProfile(overrides: {'verification_status': 'draft', 'credential_fields': <String>[]});
      await pumpProfile(tester);
      await startEditing(tester);
      expect(find.text('يراجع تغيير هذا الحقل من الإدارة قبل تطبيقه.'), findsNothing);
    });

    testWidgets('cancel puts everything back', (tester) async {
      server.profile = ownProfile(overrides: {'editable_fields': ['bio_ar']});
      await pumpProfile(tester);
      await startEditing(tester);
      await tester.enterText(find.byType(TextField), 'نص مختلف تمامًا');
      await tapText(tester, 'إلغاء');
      expect(find.text('أخصائية أمراض النساء والتوليد والعقم.'), findsOneWidget);
      expect(find.text('نص مختلف تمامًا'), findsNothing);
      expect(server.patches, isEmpty);
    });
  });

  // ================================================================= saving
  group('saving', () {
    setUp(() {
      server.profile = ownProfile(overrides: {
        'editable_fields': ['years_of_experience', 'bio_ar', 'phone', 'default_consultation_fee'],
        'credential_fields': <String>[],
      });
    });

    testWidgets('sends only what changed, then re-reads the profile', (tester) async {
      await pumpProfile(tester);
      final before = server.profileGets;
      await startEditing(tester);
      // years_of_experience, default_consultation_fee, bio_ar, phone — in screen order.
      await tester.enterText(find.byType(TextField).at(0), '12');
      await tapText(tester, 'حفظ');

      expect(server.patches, hasLength(1));
      expect(server.lastPatchBody, {'years_of_experience': 12});
      expect(server.profileGets, greaterThan(before), reason: 'the profile is read back');
      expect(find.text('تم حفظ الملف المهني'), findsOneWidget);
      // Back in view mode, showing what the server now holds.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('several fields in one request, typed correctly', (tester) async {
      await pumpProfile(tester);
      await startEditing(tester);
      await tester.enterText(find.byType(TextField).at(0), '15');
      await tester.enterText(find.byType(TextField).at(1), '200');
      await tester.enterText(find.byType(TextField).at(2), 'نبذة جديدة');
      await tester.enterText(find.byType(TextField).at(3), '+201099999999');
      await tapText(tester, 'حفظ');
      expect(server.lastPatchBody, {
        'years_of_experience': 15,
        'default_consultation_fee': '200',
        'bio_ar': 'نبذة جديدة',
        'phone': '+201099999999',
      });
    });

    testWidgets('clearing a number sends null', (tester) async {
      await pumpProfile(tester);
      await startEditing(tester);
      await tester.enterText(find.byType(TextField).at(0), '');
      await tapText(tester, 'حفظ');
      expect(server.lastPatchBody, {'years_of_experience': null});
    });

    testWidgets('nothing changed: no request, and it says so', (tester) async {
      await pumpProfile(tester);
      await startEditing(tester);
      await tapText(tester, 'حفظ');
      expect(server.patches, isEmpty);
      expect(find.text('لم تغيّر شيئًا.'), findsOneWidget);
    });

    testWidgets('a number that is not a number is refused before anything is sent', (tester) async {
      await pumpProfile(tester);
      await startEditing(tester);
      await tester.enterText(find.byType(TextField).at(1), '1.2.3');
      await tapText(tester, 'حفظ');
      expect(server.patches, isEmpty);
      expect(find.text('أدخل رقمًا صحيحًا'), findsOneWidget);
    });

    testWidgets('a server rejection is shown against the field, and the edit stays open', (tester) async {
      server.patchError = {
        'data': null,
        'meta': <String, dynamic>{},
        'errors': [
          {'code': 'invalid', 'detail': 'رقم الهاتف غير صالح.', 'field': 'phone'},
        ],
      };
      await pumpProfile(tester);
      await startEditing(tester);
      await tester.enterText(find.byType(TextField).at(3), '123');
      await tapText(tester, 'حفظ');
      expect(find.text('رقم الهاتف غير صالح.'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4), reason: 'still editing; nothing is lost');
      expect(find.text('تم حفظ الملف المهني'), findsNothing);
    });

    testWidgets('a change to a credential field is reported as sent for review', (tester) async {
      server.profile = ownProfile(overrides: {
        'editable_fields': ['full_name_ar', 'bio_ar'],
        'credential_fields': ['full_name_ar'],
      });
      await pumpProfile(tester);
      await startEditing(tester);
      await tester.enterText(find.byType(TextField).at(0), 'اسم جديد');
      await tapText(tester, 'حفظ');
      expect(find.textContaining('أُرسلت لمراجعة الإدارة'), findsOneWidget);
    });

    testWidgets('a change to an ordinary field is not', (tester) async {
      server.profile = ownProfile(overrides: {
        'editable_fields': ['full_name_ar', 'bio_ar'],
        'credential_fields': ['full_name_ar'],
      });
      await pumpProfile(tester);
      await startEditing(tester);
      await tester.enterText(find.byType(TextField).at(1), 'نبذة');
      await tapText(tester, 'حفظ');
      expect(find.text('تم حفظ الملف المهني'), findsOneWidget);
      expect(find.textContaining('أُرسلت لمراجعة الإدارة'), findsNothing);
    });

    testWidgets('a social network is sent under its own key', (tester) async {
      server.profile = ownProfile(overrides: {'editable_fields': ['social_links']});
      await pumpProfile(tester);
      await startEditing(tester);
      // facebook, instagram, linkedin, youtube, tiktok.
      await tester.enterText(find.byType(TextField).at(3), 'https://youtube.com/c/x');
      await tapText(tester, 'حفظ');
      expect(server.lastPatchBody, {'youtube': 'https://youtube.com/c/x'});
    });

    testWidgets('the save button is busy while the request is out', (tester) async {
      await pumpProfile(tester);
      await startEditing(tester);
      await tester.enterText(find.byType(TextField).at(0), '13');
      await tester.ensureVisible(find.text('حفظ'));
      await tester.tap(find.text('حفظ'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await settle(tester);
    });
  });

  // =============================================================== the states
  group('loading and failure', () {
    testWidgets('skeletons while the profile loads', (tester) async {
      server.profileDelay = const Duration(seconds: 2);
      await pumpProfile(tester);
      expect(find.text('د. نرمين أحمد فؤاد'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(find.text('د. نرمين أحمد فؤاد'), findsOneWidget);
    });

    testWidgets('a failed load shows retry, and retry works', (tester) async {
      server.failProfileGet = true;
      await pumpProfile(tester);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      server.failProfileGet = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await settle(tester);
      expect(find.text('د. نرمين أحمد فؤاد'), findsOneWidget);
    });

    testWidgets('a failing list reports itself and can be retried, without hiding the rest', (tester) async {
      server.failServices = true;
      await pumpProfile(tester);
      expect(find.text('الخدمات والأسعار'), findsOneWidget);
      expect(find.text('تعذّر تحميل هذا القسم.'), findsOneWidget);
      expect(find.text('د. نرمين أحمد فؤاد'), findsOneWidget);

      server.failServices = false;
      await tapText(tester, 'إعادة المحاولة');
      expect(find.text('متابعة حمل'), findsOneWidget);
    });
  });

  // ================================================================== roles
  group('roles and accounts', () {
    testWidgets('a patient keeps the account editor, unchanged', (tester) async {
      await pumpProfile(tester, user: patientUser());
      expect(find.text('الاسم الأول'), findsOneWidget);
      expect(find.text('الاسم الأخير'), findsOneWidget);
      expect(find.text('الملف المهني'), findsNothing);
      expect(server.requests.where((r) => r.path == '/doctor/profile/'), isEmpty, reason: 'no doctor request for a patient');
    });

    testWidgets('a doctor whose profile is not approved is not shown the doctor view', (tester) async {
      await pumpProfile(tester, user: {...doctorUser(), 'doctor_profile': null});
      expect(find.text('الملف المهني'), findsNothing);
      expect(find.text('الاسم الأول'), findsOneWidget);
    });

    testWidgets('the account\'s own details are still one tap away', (tester) async {
      await pumpProfile(tester);
      await tapText(tester, 'بيانات الحساب');
      expect(find.text('account editor'), findsOneWidget);
    });

    testWidgets('a different doctor never sees the previous doctor\'s profile', (tester) async {
      await pumpProfile(tester);
      expect(find.text('د. نرمين أحمد فؤاد'), findsOneWidget);

      server.profile = ownProfile(overrides: {'id': 'profile-2', 'full_name_ar': 'سمير حسن', 'full_name_en': 'Samir Hassan'});
      await signIn(doctorUser(id: 'another-doctor'));
      await settle(tester);
      expect(find.text('د. سمير حسن'), findsOneWidget);
      expect(find.text('د. نرمين أحمد فؤاد'), findsNothing);
    });

    testWidgets('a patient who signs in afterwards gets the patient view', (tester) async {
      await pumpProfile(tester);
      expect(find.text('الملف المهني'), findsOneWidget);
      await signIn(patientUser());
      await settle(tester);
      expect(find.text('الملف المهني'), findsNothing);
      expect(find.text('الاسم الأول'), findsOneWidget);
    });
  });

  // ============================================================ localisation
  group('English', () {
    testWidgets('labels and the English name', (tester) async {
      await pumpProfile(tester, locale: const Locale('en'));
      expect(find.text('Professional profile'), findsOneWidget);
      expect(find.text('Basic information'), findsOneWidget);
      expect(find.text('Nermeen Ahmed Fouad'), findsWidgets, reason: 'no Arabic prefix on the English name');
      expect(find.text('د. Nermeen Ahmed Fouad'), findsNothing);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Name in Arabic'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget, reason: 'the apps existing gender wording');
    });
  });

  // ================================================================== layout
  group('layout', () {
    for (final entry in {
      'small phone': const Size(320, 568),
      'standard phone': const Size(360, 800),
      'large phone': const Size(412, 915),
    }.entries) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final scale in const [1.0, 1.6]) {
          testWidgets('no overflow: ${entry.key}, ${locale.languageCode}, text x$scale', (tester) async {
            await pumpProfile(tester, size: entry.value, locale: locale, textScale: scale);
            final list = find.descendant(of: find.byType(RefreshIndicator), matching: find.byType(Scrollable));
            Future<void> scroll() async {
              for (var i = 0; i < 8; i++) {
                await tester.drag(list.first, const Offset(0, -500));
                await tester.pump(const Duration(milliseconds: 100));
              }
            }

            await scroll();
            expect(tester.takeException(), isNull, reason: 'viewing');

            await tester.drag(list.first, const Offset(0, 6000));
            await settle(tester, 3);
            await tester.tap(find.text(locale.languageCode == 'ar' ? 'تعديل' : 'Edit'));
            await settle(tester, 4);
            await scroll();
            expect(tester.takeException(), isNull, reason: 'editing');
            await settle(tester, 5);
          });
        }
      }
    }
  });
}
