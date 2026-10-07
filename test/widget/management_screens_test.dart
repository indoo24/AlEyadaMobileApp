import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/management/assistants_screen.dart';
import 'package:aleyada_mobile/features/management/clinics_screen.dart';
import 'package:aleyada_mobile/features/management/schedule_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/management_fixtures.dart';
import 'harness.dart';

void main() {
  late TestHarness h;
  late RequestLog log;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    h = TestHarness();
    log = RequestLog(h.dio);
    mockDoctorApi(h.adapter);
    h.adapter.onGet('/locations/cities/', (s) => s.reply(200, envelope(<dynamic>[])));
    container = ProviderContainer(overrides: h.overrides);
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Locale locale = const Locale('ar'),
    Size size = const Size(360, 900),
    double textScale = 1.0,
  }) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await container
        .read(authControllerProvider.notifier)
        .adoptSession(const AuthTokens(access: 'a', refresh: 'r'), user: Me.fromJson(doctorUser()));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: screen,
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

  // =========================================================== clinics
  group('clinics', () {
    testWidgets('lists each clinic with its status and, if blocked, why', (tester) async {
      await pumpScreen(tester, const ClinicsScreen());

      expect(find.text('عيادة د. نرمين أحمد فؤاد'), findsOneWidget);
      expect(find.text('مركز النيل الطبي'), findsOneWidget);
      expect(find.text('العيادة الرئيسية'), findsOneWidget);
      expect(find.text('أنشأتها'), findsOneWidget);
      expect(find.text('جاهزة لاستقبال الحجوزات'), findsOneWidget);
      expect(find.text('غير جاهزة لاستقبال الحجوزات بعد'), findsOneWidget);
      // The API sends codes; the doctor reads sentences.
      expect(find.text('لم تُحدَّد مواعيد عمل العيادة بعد'), findsOneWidget);
      expect(find.text('استقبال الحجوزات الإلكترونية متوقف في شروطك'), findsOneWidget);
      expect(find.text('clinic_hours_not_set'), findsNothing);
      // A code this build has no wording for is shown as sent, not hidden.
      expect(find.text('some_future_code'), findsOneWidget);
    });

    testWidgets('saving terms sends the doctor\'s fees and booking switch to the terms endpoint', (
      tester,
    ) async {
      h.adapter.onPatch('/doctor/clinics/link-1/terms/', (s) => s.reply(200, envelope(clinicOwned)));
      await pumpScreen(tester, const ClinicsScreen());

      await tapText(tester, 'شروطي في هذه العيادة');
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '250');
      await tester.enterText(fields.at(1), '');
      await tester.pump();
      await tapText(tester, 'حفظ الشروط');

      expect(log.count('PATCH', '/doctor/clinics/link-1/terms/'), 1);
      expect(log.body('PATCH', '/doctor/clinics/link-1/terms/'), {
        'consultation_fee': '250',
        'followup_fee': null,
        'booking_enabled': true,
      });
      expect(find.text('تم الحفظ'), findsOneWidget);
    });

    testWidgets('a fee that is not a number is refused before anything is sent', (tester) async {
      await pumpScreen(tester, const ClinicsScreen());
      await tapText(tester, 'شروطي في هذه العيادة');
      await tester.enterText(find.byType(TextField).at(0), '1.2.3');
      await tester.pump();
      await tapText(tester, 'حفظ الشروط');
      expect(log.count('PATCH', '/doctor/clinics/link-1/terms/'), 0);
    });

    testWidgets('a server refusal is shown, not swallowed', (tester) async {
      h.adapter.onPatch(
        '/doctor/clinics/link-1/terms/',
        (s) => s.reply(403, {
          'data': null,
          'meta': <String, dynamic>{},
          'errors': [
            {'code': 'permission_denied', 'detail': 'ليس لديك صلاحية.', 'field': null},
          ],
        }),
      );
      await pumpScreen(tester, const ClinicsScreen());
      await tapText(tester, 'شروطي في هذه العيادة');
      await tapText(tester, 'حفظ الشروط');
      expect(find.text('تم الحفظ'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('opening hours: edit a shift and the whole week is replaced', (tester) async {
      h.adapter.onPut('/doctor/clinics/link-1/working-hours/', (s) => s.reply(200, envelope(<dynamic>[])));
      await pumpScreen(tester, const ClinicsScreen());

      await tapText(tester, 'مواعيد العمل');
      expect(find.text('09:00'), findsOneWidget);
      await tapText(tester, 'إضافة فترة');
      await tapText(tester, 'حفظ المواعيد');

      expect(log.body('PUT', '/doctor/clinics/link-1/working-hours/'), {
        'shifts': [
          {'weekday': 6, 'open_time': '09:00', 'close_time': '17:00'},
          {'weekday': 6, 'open_time': '09:00', 'close_time': '17:00'},
        ],
      });
    });

    testWidgets('a shift can be removed', (tester) async {
      h.adapter.onPut('/doctor/clinics/link-1/working-hours/', (s) => s.reply(200, envelope(<dynamic>[])));
      await pumpScreen(tester, const ClinicsScreen());
      await tapText(tester, 'مواعيد العمل');
      await tester.tap(find.byTooltip('حذف').first);
      await settle(tester, 3);
      await tapText(tester, 'حفظ المواعيد');
      expect(log.body('PUT', '/doctor/clinics/link-1/working-hours/'), {'shifts': <dynamic>[]});
    });

    testWidgets('a clinic the doctor does not own: no hours editing, no invitations', (tester) async {
      await pumpScreen(tester, const ClinicsScreen());
      // Two clinics, so two "opening hours" sections; only the owner's has the editor.
      expect(find.text('دعوة طبيب'), findsOneWidget, reason: 'owners only');
      expect(find.text('حفظ المواعيد'), findsNothing);
      await tapText(tester, 'مواعيد العمل', last: true);
      expect(find.text('لم تُحدَّد مواعيد العمل بعد.'), findsOneWidget);
      expect(find.text('حفظ المواعيد'), findsNothing);
    });

    testWidgets('inviting a doctor posts the phone and message', (tester) async {
      h.adapter.onPost('/doctor/clinics/link-1/invitations/', (s) => s.reply(201, envelope({'phone': '01099998888', 'message': ''})));
      await pumpScreen(tester, const ClinicsScreen());
      await tapText(tester, 'دعوة طبيب');
      expect(find.text('لا توجد دعوات مرسلة.'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '01099998888');
      await tester.enterText(fields.at(1), 'تعال');
      await tester.pump();
      await tapText(tester, 'إرسال الدعوة');

      expect(log.body('POST', '/doctor/clinics/link-1/invitations/'), {
        'phone': '01099998888',
        'message': 'تعال',
      });
      expect(find.text('تم إرسال الدعوة'), findsOneWidget);
    });

    testWidgets('sent invitations are listed with their status', (tester) async {
      h.adapter.onGet(
        '/doctor/clinics/link-1/invitations/',
        (s) => s.reply(200, envelope([
          {'id': 'i1', 'status': 'pending', 'invited_doctor': {'full_name_ar': 'د. سمير'}, 'message': ''},
          {'id': 'i2', 'status': 'accepted', 'invited_doctor': {'full_name_ar': 'د. هالة'}, 'message': ''},
        ])),
      );
      await pumpScreen(tester, const ClinicsScreen());
      await tapText(tester, 'دعوة طبيب');
      expect(find.text('د. سمير'), findsOneWidget);
      expect(find.text('قيد الانتظار'), findsOneWidget);
      expect(find.text('مقبولة'), findsOneWidget);
    });

    testWidgets('adding a clinic', (tester) async {
      h.adapter.onPost('/doctor/clinics/create/', (s) => s.reply(201, envelope(clinicOwned)));
      await pumpScreen(tester, const ClinicsScreen());
      await tapText(tester, 'إضافة عيادة');

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'عيادة جديدة');
      await tester.enterText(fields.at(1), 'شارع النصر');
      await tester.pump();
      await tapText(tester, 'إنشاء العيادة');

      expect(log.body('POST', '/doctor/clinics/create/'), {
        'name_ar': 'عيادة جديدة',
        'address_ar': 'شارع النصر',
      });
    });

    testWidgets('a clinic needs a name', (tester) async {
      await pumpScreen(tester, const ClinicsScreen());
      await tapText(tester, 'إضافة عيادة');
      await tapText(tester, 'إنشاء العيادة');
      expect(log.count('POST', '/doctor/clinics/create/'), 0);
    });

    testWidgets('no clinics: an empty state with the add action', (tester) async {
      h.adapter.onGet('/doctor/clinics/', (s) => s.reply(200, paged([])));
      await pumpScreen(tester, const ClinicsScreen());
      expect(find.text('لم تُضف أي عيادة بعد'), findsOneWidget);
      expect(find.text('إضافة عيادة'), findsOneWidget);
    });

    testWidgets('a failure shows retry, and retry works', (tester) async {
      h.adapter.onGet('/doctor/clinics/', (s) => s.reply(500, envelope(null)));
      await pumpScreen(tester, const ClinicsScreen());
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      h.adapter.onGet('/doctor/clinics/', (s) => s.reply(200, paged([clinicOwned])));
      await tester.tap(find.text('إعادة المحاولة'));
      await settle(tester);
      expect(find.text('عيادة د. نرمين أحمد فؤاد'), findsOneWidget);
    });

    testWidgets('loads with skeleton-free layout on a small phone at large text', (tester) async {
      await pumpScreen(tester, const ClinicsScreen(), size: const Size(320, 568), textScale: 1.6);
      await tapText(tester, 'شروطي في هذه العيادة');
      await tapText(tester, 'مواعيد العمل');
      await tapText(tester, 'دعوة طبيب');
      expect(tester.takeException(), isNull);
    });
  });

  // ========================================================= assistants
  group('assistants', () {
    testWidgets('lists assistants with where they work and how much they may do', (tester) async {
      await pumpScreen(tester, const AssistantsScreen());
      expect(find.text('منى السيد'), findsOneWidget);
      expect(find.text('+201012345678'), findsOneWidget);
      expect(find.text('عيادة د. نرمين أحمد فؤاد'), findsOneWidget);
      expect(find.text('1 صلاحية'), findsOneWidget, reason: 'only can_view_bookings is on');
    });

    testWidgets('no assistants: the empty state from the design, with an add button', (tester) async {
      h.adapter.onGet('/doctor/assistants/', (s) => s.reply(200, paged([])));
      await pumpScreen(tester, const AssistantsScreen());
      expect(find.text('لم يتم إضافة أي مساعد بعد'), findsOneWidget);
      expect(find.text('إضافة مساعد'), findsOneWidget);
    });

    testWidgets('changing permissions patches the assignment with every flag', (tester) async {
      h.adapter.onPatch('/doctor/assignments/asg-1/', (s) => s.reply(200, envelope({})));
      await pumpScreen(tester, const AssistantsScreen());

      await tapText(tester, 'عيادة د. نرمين أحمد فؤاد');
      await tapText(tester, 'إلغاء الحجوزات');
      await tapText(tester, 'حفظ');

      final body = log.body('PATCH', '/doctor/assignments/asg-1/');
      final flags = Map<String, dynamic>.from(body['flags'] as Map);
      expect(flags['can_cancel_bookings'], isTrue);
      expect(flags['can_view_bookings'], isTrue, reason: 'unchanged flags are kept');
      expect(flags.length, 9);
    });

    testWidgets('revoking asks first, then deletes the assignment', (tester) async {
      h.adapter.onDelete('/doctor/assignments/asg-1/', (s) => s.reply(204, null));
      await pumpScreen(tester, const AssistantsScreen());

      await tapText(tester, 'عيادة د. نرمين أحمد فؤاد');
      await tapText(tester, 'سحب الوصول');
      expect(log.count('DELETE', '/doctor/assignments/asg-1/'), 0, reason: 'confirmation first');
      expect(find.textContaining('سحب وصول هذا المساعد'), findsOneWidget);

      await tester.tap(find.text('سحب الوصول').last);
      await settle(tester, 4);
      expect(log.count('DELETE', '/doctor/assignments/asg-1/'), 1);
    });

    testWidgets('revoking can be cancelled', (tester) async {
      await pumpScreen(tester, const AssistantsScreen());
      await tapText(tester, 'عيادة د. نرمين أحمد فؤاد');
      await tapText(tester, 'سحب الوصول');
      await tester.tap(find.text('إلغاء').last);
      await settle(tester, 4);
      expect(log.count('DELETE', '/doctor/assignments/asg-1/'), 0);
    });

    testWidgets('adding an assistant posts the details, the clinic and the chosen permissions', (
      tester,
    ) async {
      h.adapter.onPost('/doctor/assistants/create/', (s) => s.reply(201, envelope(assistantData)));
      await pumpScreen(tester, const AssistantsScreen());
      await tapText(tester, 'إضافة مساعد');

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'ريم');
      await tester.enterText(fields.at(1), '01012345678');
      await tester.pump();
      await tapText(tester, 'عرض الحجوزات');
      await tapText(tester, 'إضافة المساعد');

      final body = log.body('POST', '/doctor/assistants/create/');
      expect(body['full_name'], 'ريم');
      expect(body['phone'], '01012345678');
      expect(body.containsKey('clinic'), isFalse, reason: 'all clinics unless one is chosen');
      final flags = Map<String, dynamic>.from(body['flags'] as Map);
      expect(flags['can_view_bookings'], isTrue);
      expect(flags['can_cancel_bookings'], isFalse);
    });

    testWidgets('name and phone are required', (tester) async {
      await pumpScreen(tester, const AssistantsScreen());
      await tapText(tester, 'إضافة مساعد');
      await tapText(tester, 'إضافة المساعد');
      expect(log.count('POST', '/doctor/assistants/create/'), 0);
    });

    testWidgets('a failure shows retry', (tester) async {
      h.adapter.onGet('/doctor/assistants/', (s) => s.reply(500, envelope(null)));
      await pumpScreen(tester, const AssistantsScreen());
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('fits a small phone at large text', (tester) async {
      await pumpScreen(tester, const AssistantsScreen(), size: const Size(320, 568), textScale: 1.6);
      await tapText(tester, 'عيادة د. نرمين أحمد فؤاد');
      expect(tester.takeException(), isNull);
    });
  });

  // ============================================================ schedule
  group('schedule: appointments', () {
    testWidgets('shows the upcoming appointments by default, grouped by day', (tester) async {
      await pumpScreen(tester, const ScheduleScreen());

      expect(log.last('GET', '/doctor/bookings/').queryParameters['upcoming'], true);
      expect(find.text('محمد جاد'), findsOneWidget);
      expect(find.text('سارة علي'), findsOneWidget);
      expect(find.text('موعدان'), findsOneWidget);
      expect(find.text('بانتظار التأكيد'), findsOneWidget);
      expect(find.text('مؤكد'), findsWidgets);
    });

    testWidgets('"all" drops the upcoming filter', (tester) async {
      await pumpScreen(tester, const ScheduleScreen());
      await tapText(tester, 'الكل');
      expect(log.last('GET', '/doctor/bookings/').queryParameters.containsKey('upcoming'), isFalse);
    });

    testWidgets('a status filter is sent to the backend, not applied locally', (tester) async {
      await pumpScreen(tester, const ScheduleScreen());
      await tapText(tester, 'كل الحالات');
      await tapText(tester, 'تمت الزيارة', last: true);
      expect(log.last('GET', '/doctor/bookings/').queryParameters['status'], 'completed');
    });

    testWidgets('a pending appointment can be confirmed or cancelled', (tester) async {
      h.adapter.onPost('/doctor/bookings/b1/confirm/', (s) => s.reply(200, envelope({'reason': ''})));
      await pumpScreen(tester, const ScheduleScreen());

      await tapText(tester, 'تأكيد');
      expect(log.count('POST', '/doctor/bookings/b1/confirm/'), 1);
      expect(find.text('تم تحديث الموعد'), findsOneWidget);
      expect(log.count('GET', '/doctor/bookings/'), 2, reason: 'the list is reloaded after an action');
    });

    testWidgets('a confirmed appointment can be completed', (tester) async {
      h.adapter.onPost('/doctor/bookings/b2/complete/', (s) => s.reply(200, envelope({'reason': ''})));
      await pumpScreen(tester, const ScheduleScreen());
      await tapText(tester, 'اكتملت');
      expect(log.count('POST', '/doctor/bookings/b2/complete/'), 1);
    });

    testWidgets('cancelling asks for an optional reason and sends it', (tester) async {
      h.adapter.onPost('/doctor/bookings/b1/cancel/', (s) => s.reply(200, envelope({'reason': ''})));
      await pumpScreen(tester, const ScheduleScreen());

      await tester.ensureVisible(find.text('إلغاء').first);
      await tester.tap(find.text('إلغاء').first);
      await settle(tester, 4);
      await tester.enterText(find.byType(TextField).last, 'سفر');
      await tester.tap(find.text('إلغاء الموعد').last);
      await settle(tester, 4);

      expect(log.body('POST', '/doctor/bookings/b1/cancel/'), {'reason': 'سفر'});
    });

    testWidgets('no-show is offered on a confirmed appointment; whether it is allowed yet is the servers call', (
      tester,
    ) async {
      h.adapter.onPost(
        '/doctor/bookings/later/no-show/',
        (s) => s.reply(409, {
          'data': null,
          'meta': <String, dynamic>{},
          'errors': [
            {'code': 'too_early', 'detail': 'لم يحن موعد الكشف بعد.', 'field': null},
          ],
        }),
      );
      h.adapter.onGet(
        '/doctor/bookings/',
        (s) => s.reply(200, paged([
          booking('later', status: 'confirmed', name: 'مريض قادم', startAt: '2099-01-01T08:00:00Z'),
        ])),
      );
      await pumpScreen(tester, const ScheduleScreen());

      // No client-side clock: the button is there even for a future appointment…
      expect(find.text('لم يحضر'), findsOneWidget);
      await tapText(tester, 'لم يحضر');
      // …and the server's refusal is what the doctor reads.
      expect(log.count('POST', '/doctor/bookings/later/no-show/'), 1);
      expect(find.text('لم يحن موعد الكشف بعد.'), findsOneWidget);
      expect(find.text('تم تحديث الموعد'), findsNothing);
    });

    testWidgets('a pending appointment cannot be marked no-show or completed', (tester) async {
      await pumpScreen(tester, const ScheduleScreen());
      // b1 is pending, b2 confirmed: one of each action, from the right booking.
      expect(find.text('تأكيد'), findsOneWidget);
      expect(find.text('اكتملت'), findsOneWidget);
      expect(find.text('لم يحضر'), findsOneWidget);
    });

    testWidgets('finished appointments have no actions', (tester) async {
      h.adapter.onGet(
        '/doctor/bookings/',
        (s) => s.reply(200, paged([booking('d', status: 'completed', startAt: '2030-01-01T08:00:00Z')])),
      );
      await pumpScreen(tester, const ScheduleScreen());
      expect(find.text('تأكيد'), findsNothing);
      expect(find.text('اكتملت'), findsNothing);
      expect(find.text('إلغاء'), findsNothing);
    });

    testWidgets('a rejected action shows the reason and leaves the list alone', (tester) async {
      h.adapter.onPost(
        '/doctor/bookings/b1/confirm/',
        (s) => s.reply(409, {
          'data': null,
          'meta': <String, dynamic>{},
          'errors': [
            {'code': 'conflict', 'detail': 'تعذر تأكيد الحجز.', 'field': null},
          ],
        }),
      );
      await pumpScreen(tester, const ScheduleScreen());
      await tapText(tester, 'تأكيد');
      expect(find.text('تم تحديث الموعد'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('no appointments: an empty state', (tester) async {
      h.adapter.onGet('/doctor/bookings/', (s) => s.reply(200, paged([])));
      await pumpScreen(tester, const ScheduleScreen());
      expect(find.text('لا توجد مواعيد.'), findsOneWidget);
    });

    testWidgets('a failure shows retry', (tester) async {
      h.adapter.onGet('/doctor/bookings/', (s) => s.reply(500, envelope(null)));
      await pumpScreen(tester, const ScheduleScreen());
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      h.adapter.onGet('/doctor/bookings/', (s) => s.reply(200, paged([booking('x', startAt: '2030-01-01T08:00:00Z')])));
      await tester.tap(find.text('إعادة المحاولة'));
      await settle(tester);
      expect(find.text('محمد جاد'), findsOneWidget);
    });

    testWidgets('more pages are loaded as the list is scrolled', (tester) async {
      final firstPage = [
        for (var i = 0; i < 8; i++)
          booking('p$i', name: 'مريض $i', startAt: '2030-01-0${i + 1}T08:00:00Z'),
      ];
      final secondPage = [booking('p8', name: 'مريض 8', startAt: '2030-02-01T08:00:00Z')];
      // The adapter matches on the path alone, so answer by page here.
      h.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (o, handler) {
            if (o.path == '/doctor/bookings/') {
              log.calls.add(o); // answering here, so the recorder below never sees it
              final page = o.queryParameters['page'] as int? ?? 1;
              handler.resolve(
                Response(
                  requestOptions: o,
                  statusCode: 200,
                  data: page == 1
                      ? paged(firstPage, count: 9, pages: 2)
                      : paged(secondPage, count: 9, page: 2, pages: 2),
                ),
              );
            } else {
              handler.next(o);
            }
          },
        ),
      );
      await pumpScreen(tester, const ScheduleScreen(), size: const Size(360, 600));
      List<RequestOptions> page2() => log
          .where('GET', '/doctor/bookings/')
          .where((c) => c.queryParameters['page'] == 2)
          .toList();
      expect(page2(), isEmpty);

      final list = find.byType(CustomScrollView);
      for (var i = 0; i < 6; i++) {
        await tester.drag(list, const Offset(0, -700));
        await tester.pump(const Duration(milliseconds: 150));
      }
      await settle(tester);
      expect(page2(), hasLength(1), reason: 'once, not per scroll tick');
      await tester.scrollUntilVisible(find.text('مريض 8'), 300, scrollable: find.descendant(of: list, matching: find.byType(Scrollable)).first);
      expect(find.text('مريض 8'), findsOneWidget);
    });

    testWidgets('fits a small phone at large text', (tester) async {
      await pumpScreen(tester, const ScheduleScreen(), size: const Size(320, 568), textScale: 1.6);
      expect(tester.takeException(), isNull);
    });
  });

  group('schedule: availability', () {
    Future<void> openTab(WidgetTester tester) async {
      await tapText(tester, 'أوقات التوفّر');
    }

    testWidgets('lists the weekly windows', (tester) async {
      await pumpScreen(tester, const ScheduleScreen());
      await openTab(tester);
      expect(find.text('السبت'), findsOneWidget);
      expect(find.text('09:00 – 13:00'), findsOneWidget);
      expect(find.text('30 دقيقة للموعد'), findsOneWidget);
      expect(find.text('عيادة د. نرمين أحمد فؤاد'), findsOneWidget);
    });

    testWidgets('a window can be switched off', (tester) async {
      h.adapter.onPatch('/doctor/availability-windows/win-1/', (s) => s.reply(200, envelope(windowData)));
      await pumpScreen(tester, const ScheduleScreen());
      await openTab(tester);
      await tester.tap(find.byType(Switch));
      await settle(tester, 4);
      expect(log.body('PATCH', '/doctor/availability-windows/win-1/'), {'is_active': false});
    });

    testWidgets('deleting asks first', (tester) async {
      h.adapter.onDelete('/doctor/availability-windows/win-1/', (s) => s.reply(204, null));
      await pumpScreen(tester, const ScheduleScreen());
      await openTab(tester);
      await tester.tap(find.byTooltip('حذف'));
      await settle(tester, 4);
      expect(log.count('DELETE', '/doctor/availability-windows/win-1/'), 0);
      await tester.tap(find.text('حذف').last);
      await settle(tester, 4);
      expect(log.count('DELETE', '/doctor/availability-windows/win-1/'), 1);
    });

    testWidgets('adding a window posts the clinic, day, hours and visit length', (tester) async {
      h.adapter
        ..onPost('/doctor/availability-windows/', (s) => s.reply(201, envelope(windowData)))
        ..onGet('/doctor/availability-windows/', (s) => s.reply(200, paged([windowData])));
      await pumpScreen(tester, const ScheduleScreen());
      await openTab(tester);
      await tapText(tester, 'إضافة فترة توفّر');
      await tapText(tester, 'إضافة', last: true);

      expect(log.body('POST', '/doctor/availability-windows/'), {
        'clinic': 'clinic-1',
        'weekday': 6,
        'start_time': '09:00',
        'end_time': '17:00',
        'default_duration_minutes': 30,
        'slot_step_minutes': 30,
      });
    });

    testWidgets('no windows: an empty state with the add action', (tester) async {
      h.adapter.onGet('/doctor/availability-windows/', (s) => s.reply(200, paged([])));
      await pumpScreen(tester, const ScheduleScreen());
      await openTab(tester);
      expect(find.text('لم تحدد أوقات توفّر بعد.'), findsOneWidget);
      expect(find.text('إضافة فترة توفّر'), findsOneWidget);
    });

    testWidgets('a failure shows retry', (tester) async {
      h.adapter.onGet('/doctor/availability-windows/', (s) => s.reply(500, envelope(null)));
      await pumpScreen(tester, const ScheduleScreen());
      await openTab(tester);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });
  });
}
