import 'package:aleyada_mobile/core/widgets/form_fields.dart';
import 'package:aleyada_mobile/features/auth/consent_screen.dart';
import 'package:aleyada_mobile/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/api_fixtures.dart';
import 'harness.dart';

void main() {
  late TestHarness h;
  late List<RequestOptions> consentPosts;

  setUp(() {
    h = TestHarness(refreshToken: 'r');
    consentPosts = [];
    h.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST' && options.path == '/consents/') consentPosts.add(options);
          handler.next(options);
        },
      ),
    );
    h.adapter.onGet('/legal/policies/current/', (s) => s.reply(200, currentPoliciesResponse));
    h.adapter.onGet('/auth/me/', (s) => s.reply(200, meResponse));
  });

  Future<L> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(h.wrap(const ConsentScreen()));
    await tester.pumpAndSettle();
    return L.of(tester.element(find.byType(ConsentScreen)));
  }

  FilledButton confirmButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('renders both policies with their versions', (tester) async {
    await pumpScreen(tester);

    expect(find.text('سياسة الخصوصية'), findsOneWidget);
    expect(find.text('الشروط والأحكام'), findsOneWidget);
    expect(find.text('1.0'), findsNWidgets(2));
  });

  testWidgets('confirm is blocked until the box is checked', (tester) async {
    await pumpScreen(tester);

    expect(confirmButton(tester).onPressed, isNull);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(consentPosts, isEmpty, reason: 'nothing is sent without acceptance');
  });

  testWidgets('checked: posts every current version id as policy_version_ids', (tester) async {
    h.adapter.onPost(
      '/consents/',
      (s) => s.reply(200, {
        'data': {'policy_version_ids': <String>[]},
        'meta': <String, dynamic>{},
        'errors': <dynamic>[],
      }),
    );
    await pumpScreen(tester);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(confirmButton(tester).onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(consentPosts, hasLength(1));
    expect(consentPosts.single.data, {
      'policy_version_ids': [
        '0b6f3c1e-2a4d-4e8b-9c11-5f7a2d9e8a01',
        '7d2e9a40-1b3c-4f5d-8e6a-0c9b8a7f6e02',
      ],
    });
    expect(find.text('هذا الحقل مطلوب.'), findsNothing);
  });

  testWidgets('a field-attributed rejection is explained, not shown raw', (tester) async {
    h.adapter.onPost('/consents/', (s) => s.reply(400, consentIdsRequiredError));
    final l = await pumpScreen(tester);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // The bare detail would read as if the checkbox were the missing field.
    expect(find.text('هذا الحقل مطلوب.'), findsNothing);
    expect(
      find.descendant(of: find.byType(FormErrorBanner), matching: find.text(l.consentSubmitRejected)),
      findsOneWidget,
    );
    expect(confirmButton(tester).onPressed, isNotNull, reason: 'the user can try again');
  });

  testWidgets('a general rejection still goes through the shared mapping', (tester) async {
    h.adapter.onPost('/consents/', (s) => s.reply(429, throttledError));
    final l = await pumpScreen(tester);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text(l.errorThrottled), findsOneWidget);
  });
}
