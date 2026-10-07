import 'dart:async';

import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/doctors/models.dart';
import 'package:aleyada_mobile/features/doctors/providers.dart';
import 'package:aleyada_mobile/features/doctors/repository.dart';
import 'package:aleyada_mobile/features/favorites/providers.dart';
import 'package:aleyada_mobile/features/home/home_screen.dart';
import 'package:aleyada_mobile/features/home/widgets/home_doctor_card.dart';
import 'package:aleyada_mobile/features/home/widgets/medical_center_card.dart';
import 'package:aleyada_mobile/features/home/widgets/specialty_section.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/api_fixtures.dart';
import '../fixtures/doctor_detail_fixtures.dart' as dd;
import '../fixtures/management_fixtures.dart';
import 'harness.dart';

Map<String, dynamic> _spec(String slug, String name, int count) => {
  'id': slug,
  'slug': slug,
  'name_ar': name,
  'name_en': '',
  'icon': null,
  'doctors_count': count,
  'children': <dynamic>[],
};

Map<String, dynamic> _clinic(String slug, String name) => {
  'id': 'id-$slug',
  'slug': slug,
  'name_ar': name,
  'name_en': '',
  'city': {'id': '1', 'name_ar': 'الغربية'},
  'area': {'id': '2', 'name_ar': 'طنطا'},
  'address_ar': 'شارع البحر',
  'avg_rating': '4.60',
  'reviews_count': 12,
  'primary_image': null,
};

/// Answers Home's endpoints by path, with per-section data, failure and delay.
class _HomeServer {
  _HomeServer(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, handler) async {
          Response<dynamic> reply(Object? body, [int status = 200]) =>
              Response(requestOptions: o, statusCode: status, data: body);
          void fail() => handler.reject(
            DioException.badResponse(
              statusCode: 500,
              requestOptions: o,
              response: reply(envelope(null), 500),
            ),
            true,
          );

          requests.add(o);
          final gate = gates[o.path];
          if (gate != null) await gate.future;
          if (failing.contains(o.path)) return fail();
          switch (o.path) {
            case '/specializations/':
              return handler.resolve(reply(envelope(specs)));
            case '/doctors/':
              return handler.resolve(reply(doctors));
            case '/clinics/':
              return handler.resolve(reply(paged(clinics)));
            case '/articles/':
              return handler.resolve(reply(paged(articles)));
            case '/locations/cities/':
              return handler.resolve(reply(envelope(<dynamic>[])));
          }
          final detail = RegExp(r'^/doctors/([^/]+)/$').firstMatch(o.path);
          if (detail != null) {
            final d = details[detail.group(1)];
            return d == null ? fail() : handler.resolve(reply(envelope(d)));
          }
          if (o.path.endsWith('/availability/')) {
            return handler.resolve(
              reply(envelope(dd.availability(o.queryParameters['clinic_id'] as String))),
            );
          }
          handler.next(o);
        },
      ),
    );
  }

  List<Map<String, dynamic>> specs = [
    _spec('urology', 'المسالك البولية', 0),
    _spec('dentistry', 'طب الأسنان', 4),
    _spec('ophthalmology', 'طب وجراحة العيون', 5),
    _spec('cardiology', 'طب وجراحة القلب', 1),
  ];
  Map<String, dynamic> doctors = doctorListResponse;
  List<Map<String, dynamic>> clinics = [_clinic('nakheel', 'عيادة النخيل')];
  List<Map<String, dynamic>> articles = [];
  Map<String, Map<String, dynamic>> details = {};
  final failing = <String>{};
  final gates = <String, Completer<void>>{};
  final requests = <RequestOptions>[];
}

void main() {
  late TestHarness h;
  late _HomeServer server;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    server = _HomeServer(h.dio);
    container = ProviderContainer(overrides: h.overrides);
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 10]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> signIn(Map<String, dynamic> user) => container
      .read(authControllerProvider.notifier)
      .adoptSession(
        const AuthTokens(access: 'a', refresh: 'r'),
        user: Me.fromJson(user),
      );

  Future<void> pumpHome(
    WidgetTester tester, {
    Size size = const Size(390, 2600),
    Locale locale = const Locale('ar'),
    double textScale = 1.0,
  }) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: Routes.doctors,
          builder: (_, s) => Scaffold(body: Text('directory ${s.uri}')),
        ),
        GoRoute(
          path: Routes.doctor,
          builder: (_, s) => Scaffold(body: Text('profile ${s.pathParameters['slug']}')),
        ),
        GoRoute(
          path: Routes.join,
          builder: (_, __) => const Scaffold(body: Text('join')),
        ),
        GoRoute(
          path: Routes.signIn,
          builder: (_, __) => const Scaffold(body: Text('sign in')),
        ),
        GoRoute(
          path: Routes.notifications,
          builder: (_, __) => const Scaffold(body: Text('notifications')),
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

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester, 6);
  }

  DoctorQuery query() => container.read(doctorQueryProvider);

  group('header and search', () {
    testWidgets('a patient is greeted by name, with no title', (tester) async {
      await signIn(patientUser());
      await pumpHome(tester);
      final name = Me.fromJson(patientUser()).greetingName;
      expect(find.text('أهلاً $name، سلامتك'), findsOneWidget);
      expect(find.textContaining('د.'), findsNothing);
      expect(find.byTooltip('الإشعارات'), findsOneWidget);
    });

    testWidgets('a guest gets the generic greeting, no bell, and a sign-in card', (tester) async {
      await pumpHome(tester);
      expect(find.text('مرحباً بك في العيادة'), findsOneWidget);
      expect(find.byTooltip('الإشعارات'), findsNothing);
      await tap(tester, find.widgetWithText(FilledButton, 'تسجيل الدخول'));
      expect(find.text('sign in'), findsOneWidget);
    });

    testWidgets('the search field opens the existing search, focused', (tester) async {
      await pumpHome(tester);
      await tap(tester, find.text('ابحث عن طبيب أو تخصص'));
      expect(find.text('directory /doctors?focus=1'), findsOneWidget);
    });
  });

  group('quick discovery: real directory queries', () {
    testWidgets('online booking filters to booking_enabled', (tester) async {
      await pumpHome(tester);
      await tap(tester, find.text('حجز إلكتروني').first);
      expect(query().bookingEnabled, isTrue);
      expect(query().toQuery()['booking_enabled'], true);
      expect(find.textContaining('directory /doctors'), findsOneWidget);
    });

    testWidgets('lowest fee sorts by fee', (tester) async {
      await pumpHome(tester);
      await tap(tester, find.text('الأقل سعرًا'));
      expect(query().toQuery()['sort'], 'fee_asc');
    });

    testWidgets('four across on a normal phone; a 2 × 2 grid when words would break', (
      tester,
    ) async {
      double rowOf(String label) => tester.getCenter(find.text(label).first).dy;

      await pumpHome(tester, size: const Size(360, 2600));
      expect(rowOf('كل الأطباء'), rowOf('الأقل سعرًا'));

      await pumpHome(tester, size: const Size(320, 2600), textScale: 1.5);
      expect(rowOf('كل الأطباء'), rowOf('التخصصات'));
      expect(rowOf('حجز إلكتروني'), greaterThan(rowOf('كل الأطباء')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('all doctors clears any previous filter', (tester) async {
      container.read(doctorQueryProvider.notifier).state = const DoctorQuery(gender: 'female');
      await pumpHome(tester);
      await tap(tester, find.text('كل الأطباء'));
      expect(query().hasFilters, isFalse);
    });
  });

  group('specialties', () {
    testWidgets('most doctors first, with real counts; none shown for zero', (tester) async {
      await pumpHome(tester);
      final tiles = tester.widgetList<SpecialtyTile>(find.byType(SpecialtyTile)).toList();
      expect(tiles.map((t) => t.specialty.slug), [
        'ophthalmology',
        'dentistry',
        'cardiology',
        'urology',
      ]);
      expect(find.text('5 أطباء'), findsOneWidget);
      expect(find.text('طبيب واحد'), findsOneWidget);
      expect(find.text('لا يوجد أطباء بعد'), findsNothing);
    });

    testWidgets('a tile opens the directory on that specialty', (tester) async {
      await pumpHome(tester);
      await tap(tester, find.text('طب الأسنان'));
      expect(query().specialization, 'dentistry');
    });

    testWidgets('"see all" and the shortcut open every specialty in a sheet', (tester) async {
      await pumpHome(tester);
      await tap(tester, find.text('التخصصات').first);
      expect(find.text('كل التخصصات'), findsOneWidget);
      final sheet = find.ancestor(of: find.text('كل التخصصات'), matching: find.byType(BottomSheet));
      expect(find.descendant(of: sheet, matching: find.byType(SpecialtyTile)), findsNWidgets(4));

      await tap(tester, find.descendant(of: sheet, matching: find.text('المسالك البولية')));
      expect(query().specialization, 'urology');
    });

    testWidgets('no specialties: the section is not shown at all', (tester) async {
      server.specs = [];
      await pumpHome(tester);
      expect(find.text('التخصصات الطبية'), findsNothing);
    });

    testWidgets('icons come from one consistent mapping', (tester) async {
      await pumpHome(tester);
      for (final t in tester.widgetList<SpecialtyTile>(find.byType(SpecialtyTile))) {
        expect(specialtyIcon(t.specialty), isNotNull);
      }
      expect(
        specialtyIcon(Specialization.fromJson(_spec('dentistry', 'x', 0))),
        Icons.sentiment_satisfied_alt_outlined,
      );
      expect(
        specialtyIcon(Specialization.fromJson(_spec('something-new', 'x', 0))),
        Icons.medical_services_outlined,
      );
    });
  });

  group('recommended doctors', () {
    testWidgets('cards show real fields; unrated is not 0.0', (tester) async {
      await pumpHome(tester);
      expect(find.text('أطباء مقترحون'), findsOneWidget);
      expect(find.byType(HomeDoctorCard), findsNWidgets(2));
      expect(find.text('محمد ابراهيم'), findsOneWidget);
      expect(find.text('لا توجد تقييمات'), findsOneWidget, reason: 'the first has no reviews');
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('300.00 ج.م'), findsNWidgets(2));
      expect(find.text('حجز إلكتروني'), findsWidgets);
      expect(find.text('عرض الكل (+15)'), findsOneWidget, reason: '17 doctors, 2 shown');
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('the heart is the shared favourites state', (tester) async {
      await pumpHome(tester);
      await tap(tester, find.byTooltip('إضافة إلى المفضلة').first);
      expect(container.read(favoritesProvider).contains(doctorCardData['id'] as String), isTrue);
    });

    testWidgets('"book now" opens the real booking sheet for that doctor', (tester) async {
      server.details['mohamed-ebrahim'] = dd.publicDoctor(overrides: {'slug': 'mohamed-ebrahim'});
      await pumpHome(tester, size: const Size(390, 844));
      await tap(tester, find.widgetWithText(FilledButton, 'احجز الآن').first);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('حجز موعد'), findsOneWidget);
      expect(find.text('اختر العيادة'), findsOneWidget, reason: 'two bookable clinics');
    });

    testWidgets('no bookable clinic, or no profile: "book now" opens the profile', (tester) async {
      await pumpHome(tester, size: const Size(390, 844));
      await tap(tester, find.widgetWithText(FilledButton, 'احجز الآن').first);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('profile mohamed-ebrahim'), findsOneWidget);
    });

    testWidgets('a contact-only doctor offers the profile, not booking', (tester) async {
      server.doctors = {
        ...doctorListResponse,
        'data': [
          {...doctorCardData, 'booking_enabled': false},
        ],
      };
      await pumpHome(tester);
      expect(find.text('احجز الآن'), findsNothing);
      expect(find.text('عرض الملف'), findsOneWidget);
      expect(find.text('حجز عبر الهاتف'), findsOneWidget);
    });

    testWidgets('tapping a card opens that doctor', (tester) async {
      await pumpHome(tester);
      await tap(tester, find.text('محمد ابراهيم'));
      expect(find.text('profile mohamed-ebrahim'), findsOneWidget);
    });
  });

  group('clinics and articles', () {
    testWidgets('a clinic opens the doctors who work there', (tester) async {
      await pumpHome(tester);
      expect(find.byType(MedicalCenterCard), findsOneWidget);
      await tap(tester, find.text('عيادة النخيل'));
      expect(query().clinic, 'nakheel');
      expect(query().clinicName, 'عيادة النخيل');
    });

    testWidgets('with no published articles, there is no articles section', (tester) async {
      await pumpHome(tester);
      expect(find.text('مقالات العيادة الطبية'), findsNothing);
    });

    testWidgets('published articles appear', (tester) async {
      server.articles = [
        {
          'id': 'a1',
          'slug': 'a1',
          'title_ar': 'التغذية لمرضى السكري',
          'excerpt': 'ملخص',
          'featured_image': null,
          'category': {'id': 'k', 'name_ar': 'تغذية', 'slug': 'k'},
          'is_certified': false,
        },
      ];
      await pumpHome(tester);
      expect(find.text('مقالات العيادة الطبية'), findsOneWidget);
      expect(find.text('التغذية لمرضى السكري'), findsOneWidget);
    });
  });

  group('loading, empty and errors', () {
    testWidgets('loading shows placeholders in the cards\' shape, then content', (tester) async {
      server.gates['/doctors/'] = Completer<void>();
      await pumpHome(tester);
      expect(find.byType(HomeDoctorCardSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      server.gates['/doctors/']!.complete();
      await settle(tester);
      expect(find.byType(HomeDoctorCardSkeleton), findsNothing);
      expect(find.byType(HomeDoctorCard), findsNWidgets(2));
    });

    testWidgets('one failing section says so; the rest still renders', (tester) async {
      server.failing.add('/clinics/');
      await pumpHome(tester);
      expect(find.text('تعذّر تحميل هذا القسم.'), findsOneWidget);
      expect(find.byType(HomeDoctorCard), findsNWidgets(2));
      expect(find.text('تعذّر تحميل البيانات'), findsNothing);
    });

    testWidgets('everything failing: one friendly error, and retry recovers', (tester) async {
      server.failing.addAll(['/specializations/', '/doctors/', '/clinics/']);
      await pumpHome(tester);
      expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);
      expect(find.byType(HomeDoctorCard), findsNothing);
      expect(find.text('ابحث عن طبيب أو تخصص'), findsOneWidget, reason: 'search still works');

      server.failing.clear();
      await tap(tester, find.text('إعادة المحاولة'));
      expect(find.text('تعذّر تحميل البيانات'), findsNothing);
      expect(find.byType(HomeDoctorCard), findsNWidgets(2));
    });

    testWidgets('no doctors in this city: a compact message, not a giant card', (tester) async {
      server.doctors = paged(const []);
      await pumpHome(tester);
      expect(find.text('لا يوجد أطباء في هذه المدينة بعد.'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final width in const [320.0, 360.0, 390.0, 412.0]) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final scale in const [1.0, 1.5]) {
          testWidgets('no overflow: ${width.toInt()}px, ${locale.languageCode}, text x$scale', (
            tester,
          ) async {
            await signIn(doctorUser());
            await pumpHome(tester, size: Size(width, 760), locale: locale, textScale: scale);
            final feed = find.byType(Scrollable).first;
            for (var i = 0; i < 8; i++) {
              await tester.drag(feed, const Offset(0, -500));
              await settle(tester, 2);
            }
            // The doctor strip scrolls sideways too.
            final strip = find.ancestor(
              of: find.byType(HomeDoctorCard).first,
              matching: find.byType(Scrollable),
            );
            if (strip.evaluate().isNotEmpty) {
              await tester.drag(strip.first, const Offset(400, 0));
              await tester.drag(strip.first, const Offset(-400, 0));
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
