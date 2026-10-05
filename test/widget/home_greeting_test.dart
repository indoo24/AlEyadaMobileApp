import 'package:aleyada_mobile/core/auth/models.dart';
import 'package:aleyada_mobile/core/providers.dart';
import 'package:aleyada_mobile/core/theme/app_theme.dart';
import 'package:aleyada_mobile/features/home/home_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../fixtures/api_fixtures.dart';
import 'harness.dart';

/// A login response for [role]. `patient_profile` is dropped so the name comes
/// from the account itself, whatever the fixture's patient happens to be called.
/// What the Home screen fetches around the greeting. The harness matches on URL
/// only, so the filters the featured list sends do not matter here.
void _mockHomeData(DioAdapter a) {
  a.onGet('/specializations/', (s) => s.reply(200, specializationsResponse));
  a.onGet('/doctors/', (s) => s.reply(200, doctorListResponse));
}

Map<String, dynamic> _login(String role, {String fullName = 'Ahmed'}) => {
  'data': {
    'access': 'header.payload.signature',
    'refresh': 'header.payload.signature',
    'user': {
      ...meResponseData,
      'role': role,
      'full_name': fullName,
      'first_name': fullName,
      'last_name': '',
      'patient_profile': null,
      'requires_reacceptance': <String>[],
    },
  },
  'meta': <String, dynamic>{},
  'errors': <dynamic>[],
};

void main() {
  late TestHarness h;
  late ProviderContainer container;
  late DioAdapter adapter;

  setUp(() {
    h = TestHarness();
    adapter = h.adapter;
    container = ProviderContainer(overrides: h.overrides);
    _mockHomeData(adapter);
    adapter.onPost('/auth/logout/', (s) => s.reply(204, null));
  });

  tearDown(() => container.dispose());

  // Accounts by phone. Adopting the session puts the user into the same
  // AuthState a login would; the role is whatever the backend's `user` carried.
  final accounts = <String, Map<String, dynamic>>{};

  void loginAs(String phone, String role, {String fullName = 'Ahmed'}) =>
      accounts[phone] = _login(role, fullName: fullName);

  // Not pumpAndSettle: a pending request leaves a Skeleton animating forever,
  // and "never settles" would then look like a hang instead of a failure.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // A mocked request completes on the fake clock, so awaiting it without
  // pumping would wait forever. Start it, pump, then collect the result.
  Future<void> run(WidgetTester tester, Future<void> Function() call) async {
    final pending = call();
    await settle(tester);
    await pending;
  }

  Future<void> pumpHome(WidgetTester tester, {Locale locale = const Locale('ar')}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> signIn(WidgetTester tester, String phone) async {
    final data = accounts[phone]!['data'] as Map;
    await container
        .read(authControllerProvider.notifier)
        .adoptSession(
          AuthTokens(access: data['access'] as String, refresh: data['refresh'] as String),
          user: Me.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
        );
    await settle(tester);
  }

  group('greeting by account role', () {
    testWidgets('patient, Arabic: no title', (tester) async {
      loginAs('01', 'patient');
      await pumpHome(tester);
      await signIn(tester, '01');

      expect(find.text('أهلاً Ahmed'), findsOneWidget);
      expect(find.textContaining('د.'), findsNothing);
    });

    testWidgets('doctor, Arabic: د.', (tester) async {
      loginAs('02', 'doctor');
      await pumpHome(tester);
      await signIn(tester, '02');

      expect(find.text('أهلاً د. Ahmed'), findsOneWidget);
    });

    testWidgets('patient, English: no title', (tester) async {
      loginAs('01', 'patient');
      await pumpHome(tester, locale: const Locale('en'));
      await signIn(tester, '01');

      expect(find.text('Welcome Ahmed'), findsOneWidget);
      // Scoped to the greeting: the page also has a "Doctors" section heading.
      expect(find.textContaining('Welcome Dr'), findsNothing);
      expect(find.textContaining('Welcome Doctor'), findsNothing);
    });

    testWidgets('doctor, English: Dr.', (tester) async {
      loginAs('02', 'doctor');
      await pumpHome(tester, locale: const Locale('en'));
      await signIn(tester, '02');

      expect(find.text('Welcome Dr. Ahmed'), findsOneWidget);
    });

    testWidgets('an unrecognised role gets no title', (tester) async {
      loginAs('03', 'chief_wizard');
      await pumpHome(tester, locale: const Locale('en'));
      await signIn(tester, '03');

      expect(container.read(currentUserProvider)!.role, UserRole.unknown);
      expect(find.text('Welcome Ahmed'), findsOneWidget);
    });

    testWidgets('a missing role gets no title', (tester) async {
      final body = _login('patient');
      ((body['data'] as Map)['user'] as Map).remove('role');
      accounts['04'] = body;
      await pumpHome(tester, locale: const Locale('en'));
      await signIn(tester, '04');

      expect(find.text('Welcome Ahmed'), findsOneWidget);
    });

    testWidgets('a patient whose name starts with Dr. is not given a title', (tester) async {
      loginAs('01', 'patient', fullName: 'Dr. Ahmed');
      await pumpHome(tester, locale: const Locale('en'));
      await signIn(tester, '01');

      expect(find.text('Welcome Ahmed'), findsOneWidget);
    });

    testWidgets('a doctor whose name already starts with a title gets it once', (tester) async {
      loginAs('02', 'doctor', fullName: 'د. Ahmed');
      await pumpHome(tester);
      await signIn(tester, '02');

      expect(find.text('أهلاً د. Ahmed'), findsOneWidget);
    });
  });

  testWidgets('the greeting follows logout and a login as a different account type', (tester) async {
    loginAs('01', 'patient');
    loginAs('02', 'doctor');
    await pumpHome(tester, locale: const Locale('en'));

    await signIn(tester, '01');
    expect(find.text('Welcome Ahmed'), findsOneWidget);

    await run(tester, container.read(authControllerProvider.notifier).signOut);
    expect(find.textContaining('Welcome'), findsNothing, reason: 'nobody is signed in');

    await signIn(tester, '02');
    expect(find.text('Welcome Dr. Ahmed'), findsOneWidget);

    await run(tester, container.read(authControllerProvider.notifier).signOut);
    await signIn(tester, '01');
    expect(find.text('Welcome Ahmed'), findsOneWidget, reason: 'the title must not stick');
  });

  testWidgets('after an app restart the role comes back from /auth/me/', (tester) async {
    final restarted = TestHarness(refreshToken: 'r');
    final restartedAdapter = DioAdapter(dio: restarted.dio);
    restartedAdapter.onGet('/auth/me/', (s) => s.reply(200, {
      'data': (_login('doctor')['data'] as Map)['user'],
      'meta': <String, dynamic>{},
      'errors': <dynamic>[],
    }));
    _mockHomeData(restartedAdapter);
    final c = ProviderContainer(overrides: restarted.overrides);
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    final restore = c.read(authControllerProvider.notifier).restore();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await restore;

    expect(find.text('Welcome Dr. Ahmed'), findsOneWidget);
  });

  group('Me title handling', () {
    Me meNamed(String name, {String role = 'patient'}) => Me.fromJson({
      ...meResponseData,
      'role': role,
      'patient_profile': null,
      'full_name': name,
    });

    test('isDoctor follows the backend role and nothing else', () {
      expect(meNamed('Ahmed', role: 'doctor').isDoctor, isTrue);
      expect(meNamed('Ahmed').isDoctor, isFalse);
      expect(meNamed('Ahmed', role: 'assistant').isDoctor, isFalse);
      expect(meNamed('Ahmed', role: 'admin').isDoctor, isFalse);
      expect(meNamed('Ahmed', role: 'nonsense').isDoctor, isFalse);
      expect(meNamed('Dr. Ahmed').isDoctor, isFalse, reason: 'a name is not a role');
    });

    test('a leading title is removed from the short name', () {
      for (final name in [
        'Dr. Ahmed Ali',
        'Dr Ahmed Ali',
        'dr. Ahmed Ali',
        'Doctor Ahmed Ali',
        'د. Ahmed Ali',
        'د/ Ahmed Ali',
        'د.Ahmed Ali',
        'دكتور Ahmed Ali',
        'الدكتور Ahmed Ali',
        'الدكتورة Ahmed Ali',
      ]) {
        expect(meNamed(name).shortName, 'Ahmed Ali', reason: name);
      }
    });

    test('names that merely begin with the same letters are left alone', () {
      expect(meNamed('Drake Ali').shortName, 'Drake Ali');
      expect(meNamed('دعاء محمد').shortName, 'دعاء محمد');
      expect(meNamed('دينا علي').shortName, 'دينا علي');
      expect(meNamed('Doctorow Smith').shortName, 'Doctorow Smith');
    });

    test('a name that is only a title is not erased', () {
      expect(meNamed('Dr.').shortName, 'Dr.');
    });
  });
}
