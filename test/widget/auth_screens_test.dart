import 'dart:async';

import 'package:aleyada_mobile/app/router.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/auth/otp_screen.dart';
import 'package:aleyada_mobile/features/auth/sign_in_screen.dart';
import 'package:aleyada_mobile/features/auth/sign_up_screen.dart';
import 'package:aleyada_mobile/features/auth/widgets/auth_widgets.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/api_fixtures.dart';
import 'harness.dart';

Map<String, dynamic> _errors(List<Map<String, Object?>> errors) => {
  'data': null,
  'meta': <String, dynamic>{},
  'errors': errors,
};

/// Answers the auth endpoints the three screens use, recording every request.
class _AuthServer {
  _AuthServer(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, handler) async {
          Response<dynamic> reply(Object? body, [int status = 200]) =>
              Response(requestOptions: o, statusCode: status, data: body);
          void fail(int status, Object? body) => handler.reject(
            DioException.badResponse(
              statusCode: status,
              requestOptions: o,
              response: reply(body, status),
            ),
            true,
          );

          requests.add(o);
          final gate = gates[o.path];
          if (gate != null) await gate.future;
          if (offline.contains(o.path)) {
            return handler.reject(
              DioException(requestOptions: o, type: DioExceptionType.connectionError),
              true,
            );
          }
          final error = errors[o.path];
          if (error != null) return fail(error.$1, error.$2);
          switch (o.path) {
            case '/auth/login/':
              return handler.resolve(reply(loginResponse));
            case '/legal/policies/current/':
              return handler.resolve(reply(currentPoliciesResponse));
            case '/auth/register/patient/':
              return handler.resolve(reply({'data': null, 'meta': {}, 'errors': []}, 201));
            case '/auth/password/forgot/':
            case '/auth/otp/request/':
              return handler.resolve(
                reply({
                  'data': {'sent': true},
                  'meta': {},
                  'errors': [],
                }),
              );
            case '/auth/otp/verify/':
              return handler.resolve(
                reply({
                  'data': {...loginResponse['data'] as Map, 'verified': true},
                  'meta': {},
                  'errors': [],
                }),
              );
          }
          handler.next(o);
        },
      ),
    );
  }

  final requests = <RequestOptions>[];
  final gates = <String, Completer<void>>{};
  final errors = <String, (int, Map<String, dynamic>)>{};
  final offline = <String>{};

  Iterable<RequestOptions> to(String path) => requests.where((r) => r.path == path);
}

void main() {
  late TestHarness h;
  late _AuthServer server;
  late ProviderContainer container;

  setUpAll(() async {
    final cairo = FontLoader('Cairo')..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf'));
    await cairo.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    h = TestHarness();
    server = _AuthServer(h.dio);
    container = ProviderContainer(overrides: h.overrides);
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    String location, {
    Size size = const Size(390, 1100),
    Locale locale = const Locale('ar'),
    double textScale = 1.0,
  }) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('home page')),
        ),
        GoRoute(
          path: Routes.signIn,
          builder: (_, s) => SignInScreen(next: s.uri.queryParameters['next']),
        ),
        GoRoute(path: Routes.signUp, builder: (_, __) => const SignUpScreen()),
        GoRoute(
          path: Routes.otp,
          builder: (_, s) => OtpScreen(
            phone: s.uri.queryParameters['phone'] ?? '',
            purpose: s.uri.queryParameters['purpose'] ?? 'signup',
            next: s.uri.queryParameters['next'],
          ),
        ),
        GoRoute(
          path: '/doctors/:slug',
          builder: (_, s) => Scaffold(body: Text('doctor ${s.pathParameters['slug']}')),
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

  Finder field(String label) => find.descendant(
    of: find.byWidgetPredicate((w) => w is AuthTextField && w.label == label),
    matching: find.byType(TextField),
  );

  Finder primary(String label) => find.widgetWithText(FilledButton, label);

  // ========================================================================
  group('Sign in', () {
    testWidgets('the new logo, title and an untouched form', (tester) async {
      await pump(tester, Routes.signIn);
      final logo = tester.widget<Image>(
        find.descendant(of: find.byType(AuthLogo), matching: find.byType(Image)),
      );
      expect((logo.image as AssetImage).assetName, 'assets/logo.png');
      expect(logo.fit, BoxFit.contain, reason: 'never stretched or cropped');
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.text('سجّل الدخول لمتابعة حجوزاتك ومواعيدك.'), findsOneWidget);
      expect(
        find.text('من فضلك أدخل رقم الهاتف.'),
        findsNothing,
        reason: 'no errors before trying',
      );
      expect(server.requests, isEmpty);
    });

    testWidgets('empty fields are caught before any request, and clear as you type', (
      tester,
    ) async {
      await pump(tester, Routes.signIn);
      await tap(tester, primary('تسجيل الدخول'));
      expect(find.text('من فضلك أدخل رقم الهاتف.'), findsOneWidget);
      expect(server.to('/auth/login/'), isEmpty);

      await tester.enterText(field('رقم الهاتف'), '01012345678');
      await tester.pump();
      expect(find.text('من فضلك أدخل رقم الهاتف.'), findsNothing);

      await tap(tester, primary('تسجيل الدخول'));
      expect(find.text('من فضلك أدخل كلمة المرور.'), findsOneWidget);
      expect(server.to('/auth/login/'), isEmpty);
    });

    testWidgets('a phone signs in with the same request as before, and resumes the destination', (
      tester,
    ) async {
      await pump(tester, '${Routes.signIn}?next=%2Fdoctors%2Fdr-x');
      await tester.enterText(field('رقم الهاتف'), '01012345678');
      await tester.enterText(field('كلمة المرور'), 'secret123');
      await tap(tester, primary('تسجيل الدخول'));

      expect(server.to('/auth/login/').single.data, {
        'phone': '01012345678',
        'password': 'secret123',
      });
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);
      expect(find.text('doctor dr-x'), findsOneWidget);
    });

    testWidgets('an email identifier is still sent as email', (tester) async {
      await pump(tester, Routes.signIn);
      await tester.enterText(field('رقم الهاتف'), 'me@example.com');
      await tester.enterText(field('كلمة المرور'), 'secret123');
      await tap(tester, primary('تسجيل الدخول'));
      expect(server.to('/auth/login/').single.data, {
        'email': 'me@example.com',
        'password': 'secret123',
      });
    });

    testWidgets('wrong credentials: a clear message, and the button works again', (tester) async {
      server.errors['/auth/login/'] = (
        400,
        _errors([
          {'code': 'invalid_credentials', 'detail': 'Invalid credentials.', 'field': null},
        ]),
      );
      await pump(tester, Routes.signIn);
      await tester.enterText(field('رقم الهاتف'), '01012345678');
      await tester.enterText(field('كلمة المرور'), 'wrong');
      await tap(tester, primary('تسجيل الدخول'));

      expect(find.text('رقم الهاتف أو كلمة المرور غير صحيحة.'), findsOneWidget);
      expect(find.text('Invalid credentials.'), findsNothing);
      expect(tester.widget<FilledButton>(primary('تسجيل الدخول')).onPressed, isNotNull);
    });

    testWidgets('no connection: the network message', (tester) async {
      server.offline.add('/auth/login/');
      await pump(tester, Routes.signIn);
      await tester.enterText(field('رقم الهاتف'), '01012345678');
      await tester.enterText(field('كلمة المرور'), 'secret123');
      await tap(tester, primary('تسجيل الدخول'));
      expect(find.text('تعذّر الاتصال بالخادم. تحقق من الإنترنت.'), findsOneWidget);
    });

    testWidgets('one request however often it is submitted', (tester) async {
      server.gates['/auth/login/'] = Completer<void>();
      await pump(tester, Routes.signIn);
      await tester.enterText(field('رقم الهاتف'), '01012345678');
      await tester.enterText(field('كلمة المرور'), 'secret123');
      await tester.tap(primary('تسجيل الدخول'));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      server.gates['/auth/login/']!.complete();
      await settle(tester);
      expect(server.to('/auth/login/'), hasLength(1));
    });

    testWidgets('the password can be shown and hidden, with spoken labels', (tester) async {
      await pump(tester, Routes.signIn);
      TextField pw() => tester.widget<TextField>(field('كلمة المرور'));
      expect(pw().obscureText, isTrue);
      await tap(tester, find.bySemanticsLabel('إظهار كلمة المرور'));
      expect(pw().obscureText, isFalse);
      expect(find.bySemanticsLabel('إخفاء كلمة المرور'), findsOneWidget);
    });

    testWidgets('forgot password: the existing reset flow', (tester) async {
      await pump(tester, Routes.signIn);
      await tap(tester, find.text('نسيت كلمة المرور؟'));
      final sheet = find.byType(BottomSheet);
      await tester.enterText(
        find.descendant(of: sheet, matching: find.byType(TextField)),
        '01012345678',
      );
      await tap(tester, find.descendant(of: sheet, matching: primary('التالي')));

      expect(server.to('/auth/password/forgot/').single.data, {'phone': '01012345678'});
      expect(find.byType(OtpScreen), findsOneWidget);
      expect(tester.widget<OtpScreen>(find.byType(OtpScreen)).purpose, 'password_reset');
    });

    testWidgets('create account opens sign-up, and its sign-in link comes back', (tester) async {
      await pump(tester, Routes.signIn);
      await tap(tester, find.widgetWithText(TextButton, 'إنشاء حساب'));
      expect(find.byType(SignUpScreen), findsOneWidget);
      await tap(tester, find.widgetWithText(TextButton, 'تسجيل الدخول'));
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  // ========================================================================
  group('Sign up', () {
    Future<void> fill(WidgetTester tester, {String email = ''}) async {
      await tester.enterText(field('الاسم الكامل'), 'يوسف قنديل');
      await tester.enterText(field('رقم الهاتف'), '01112345678');
      if (email.isNotEmpty) await tester.enterText(field('البريد الإلكتروني'), email);
      await tester.enterText(field('كلمة المرور'), 'secret123');
      await tester.pump();
    }

    Future<void> pumpSignUp(WidgetTester tester) async {
      await pump(tester, Routes.signIn);
      await tap(tester, find.widgetWithText(TextButton, 'إنشاء حساب'));
    }

    testWidgets('the logo, title, and the backend\'s current policies', (tester) async {
      await pumpSignUp(tester);
      expect(find.byType(AuthLogo), findsOneWidget);
      expect(find.text('أنشئ حسابك لحجز المواعيد ومتابعتها.'), findsOneWidget);
      expect(find.text('أوافق على الشروط وسياسة الخصوصية'), findsOneWidget);
      expect(find.text('سياسة الخصوصية'), findsOneWidget);
      expect(find.text('الشروط والأحكام'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });

    testWidgets('a policy opens its own text', (tester) async {
      await pumpSignUp(tester);
      await tap(tester, find.text('الشروط والأحكام'));
      expect(find.text('نص الشروط والأحكام.'), findsOneWidget);
    });

    testWidgets('required fields are checked first; email stays optional', (tester) async {
      await pumpSignUp(tester);
      await tap(tester, primary('إنشاء حساب'));
      expect(find.text('من فضلك أدخل الاسم.'), findsOneWidget);
      expect(find.text('من فضلك أدخل رقم الهاتف.'), findsOneWidget);
      expect(find.text('من فضلك أدخل كلمة المرور.'), findsOneWidget);
      expect(server.to('/auth/register/patient/'), isEmpty);
    });

    testWidgets('the agreement is required, as before', (tester) async {
      await pumpSignUp(tester);
      await fill(tester);
      await tap(tester, primary('إنشاء حساب'));
      expect(find.text('يجب الموافقة على الشروط للمتابعة.'), findsOneWidget);
      expect(server.to('/auth/register/patient/'), isEmpty);
      // Ticking it (the sentence is the tap target too) clears the message.
      await tap(tester, find.text('أوافق على الشروط وسياسة الخصوصية'));
      expect(find.text('يجب الموافقة على الشروط للمتابعة.'), findsNothing);
    });

    testWidgets('success: the same payload, then the OTP step', (tester) async {
      await pumpSignUp(tester);
      await fill(tester, email: 'yousef@example.com');
      await tap(tester, find.byType(Checkbox));
      await tap(tester, primary('إنشاء حساب'));

      expect(server.to('/auth/register/patient/').single.data, {
        'full_name': 'يوسف قنديل',
        'phone': '01112345678',
        'email': 'yousef@example.com',
        'password': 'secret123',
        'accepted_policy_versions': [
          '0b6f3c1e-2a4d-4e8b-9c11-5f7a2d9e8a01',
          '7d2e9a40-1b3c-4f5d-8e6a-0c9b8a7f6e02',
        ],
      });
      final otp = tester.widget<OtpScreen>(find.byType(OtpScreen));
      expect((otp.phone, otp.purpose), ('01112345678', 'signup'));
    });

    testWidgets('server field errors land under their fields and clear on edit', (tester) async {
      server.errors['/auth/register/patient/'] = (
        400,
        _errors([
          {'code': 'phone_taken', 'detail': 'phone taken', 'field': 'phone'},
          {'code': 'invalid', 'detail': 'أدخل بريدًا إلكترونيًا صحيحًا.', 'field': 'email'},
        ]),
      );
      await pumpSignUp(tester);
      await fill(tester, email: 'x@');
      await tap(tester, find.byType(Checkbox));
      await tap(tester, primary('إنشاء حساب'));

      expect(find.text('phone taken'), findsOneWidget, reason: 'field errors show the server text');
      expect(find.text('أدخل بريدًا إلكترونيًا صحيحًا.'), findsOneWidget);
      await tester.enterText(field('البريد الإلكتروني'), 'x@example.com');
      await tester.pump();
      expect(find.text('أدخل بريدًا إلكترونيًا صحيحًا.'), findsNothing);
      expect(find.text('phone taken'), findsOneWidget, reason: 'only the edited field clears');
    });

    testWidgets('one registration however often it is submitted', (tester) async {
      server.gates['/auth/register/patient/'] = Completer<void>();
      await pumpSignUp(tester);
      await fill(tester);
      await tap(tester, find.byType(Checkbox));
      await tester.tap(primary('إنشاء حساب'));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      server.gates['/auth/register/patient/']!.complete();
      await settle(tester);
      expect(server.to('/auth/register/patient/'), hasLength(1));
    });

    testWidgets('policies that fail to load can be retried', (tester) async {
      server.errors['/legal/policies/current/'] = (500, _errors([]));
      await pumpSignUp(tester);
      expect(find.text('تعذّر تحميل الشروط. حاول مرة أخرى.'), findsOneWidget);
      expect(tester.widget<FilledButton>(primary('إنشاء حساب')).onPressed, isNull);
      server.errors.remove('/legal/policies/current/');
      await tap(tester, find.text('إعادة المحاولة'));
      expect(find.text('الشروط والأحكام'), findsOneWidget);
    });
  });

  // ========================================================================
  group('Verification code', () {
    testWidgets('verifying signs in and continues', (tester) async {
      await pump(tester, '${Routes.otp}?phone=01112345678&purpose=signup&next=%2Fdoctors%2Fdr-x');
      expect(find.byType(AuthLogo), findsOneWidget);
      expect(find.textContaining('01112345678'), findsOneWidget);
      await tester.enterText(field('رمز التأكيد'), '123456');
      await tap(tester, primary('تأكيد'));
      expect(server.to('/auth/otp/verify/').single.data, {
        'phone': '01112345678',
        'purpose': 'signup',
        'code': '123456',
      });
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);
      expect(find.text('doctor dr-x'), findsOneWidget);
    });

    testWidgets('a wrong code says so; resend asks for a new one', (tester) async {
      server.errors['/auth/otp/verify/'] = (
        400,
        _errors([
          {'code': 'otp_invalid', 'detail': 'bad', 'field': null},
        ]),
      );
      await pump(tester, '${Routes.otp}?phone=01112345678&purpose=signup');
      await tester.enterText(field('رمز التأكيد'), '000000');
      await tap(tester, primary('تأكيد'));
      expect(find.text('الرمز غير صحيح أو انتهت صلاحيته.'), findsOneWidget);
      await tap(tester, find.text('إعادة إرسال الرمز'));
      expect(server.to('/auth/otp/request/').single.data, {
        'phone': '01112345678',
        'purpose': 'signup',
      });
    });
  });

  // ========================================================================
  group('layout', () {
    for (final width in const [320.0, 360.0, 390.0, 412.0]) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        for (final scale in const [1.0, 1.5]) {
          testWidgets('no overflow: ${width.toInt()}px, ${locale.languageCode}, text x$scale', (
            tester,
          ) async {
            for (final route in [
              Routes.signIn,
              Routes.signUp,
              '${Routes.otp}?phone=0111&purpose=signup',
            ]) {
              await pump(tester, route, size: Size(width, 720), locale: locale, textScale: scale);
              // Show every error at once — the tallest the forms get.
              final cta = find.byType(FilledButton).last;
              await tester.ensureVisible(cta);
              await tester.pump();
              await tester.tap(cta, warnIfMissed: false);
              await settle(tester, 4);
              await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
              await settle(tester, 2);
              expect(tester.takeException(), isNull, reason: route);
            }
          });
        }
      }
    }

    testWidgets('with the keyboard open the focused field and the button stay reachable', (
      tester,
    ) async {
      await pump(tester, Routes.signIn, size: const Size(320, 640));
      tester.view.viewInsets = const FakeViewPadding(bottom: 560); // ~280 logical
      addTearDown(tester.view.resetViewInsets);
      await tester.showKeyboard(field('كلمة المرور'));
      await settle(tester, 4);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(primary('تسجيل الدخول'));
      await tester.pump();
      final button = tester.getRect(primary('تسجيل الدخول'));
      expect(button.bottom, lessThanOrEqualTo(640 - 280 + 1));
    });
  });
}
