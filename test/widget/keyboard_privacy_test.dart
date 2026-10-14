import 'package:aleyada_mobile/core/widgets/form_fields.dart';
import 'package:aleyada_mobile/features/auth/otp_screen.dart';
import 'package:aleyada_mobile/features/auth/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  TextField fieldIn(WidgetTester tester, Finder of) =>
      tester.widget<TextField>(find.descendant(of: of, matching: find.byType(TextField)));

  void expectPrivate(TextField f, {required bool private, String? reason}) {
    expect(f.enableIMEPersonalizedLearning, !private, reason: reason);
    expect(f.enableSuggestions, !private, reason: reason);
    expect(f.autocorrect, !private, reason: reason);
  }

  testWidgets('AppTextField: private fields keep their text out of the keyboard', (tester) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      TestHarness().wrap(
        Scaffold(
          body: ListView(
            children: [
              AppTextField(key: const Key('plain'), label: 'name', controller: c),
              AppTextField(key: const Key('notes'), label: 'notes', controller: c, private: true),
              AppTextField(key: const Key('pw'), label: 'pw', controller: c, obscure: true),
              // A password shown in clear is still a password.
              AppTextField(
                key: const Key('shown'),
                label: 'pw',
                controller: c,
                onToggleObscure: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expectPrivate(
      fieldIn(tester, find.byKey(const Key('plain'))),
      private: false,
      reason: 'ordinary',
    );
    expectPrivate(
      fieldIn(tester, find.byKey(const Key('notes'))),
      private: true,
      reason: 'private',
    );
    expectPrivate(fieldIn(tester, find.byKey(const Key('pw'))), private: true, reason: 'obscured');
    expectPrivate(
      fieldIn(tester, find.byKey(const Key('shown'))),
      private: true,
      reason: 'revealed',
    );
  });

  testWidgets('AuthTextField: the same rules', (tester) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      TestHarness().wrap(
        Scaffold(
          body: ListView(
            children: [
              AuthTextField(
                key: const Key('plain'),
                label: 'phone',
                controller: c,
                icon: Icons.phone,
              ),
              AuthTextField(
                key: const Key('code'),
                label: 'code',
                controller: c,
                icon: Icons.password,
                private: true,
              ),
              AuthTextField(
                key: const Key('shown'),
                label: 'pw',
                controller: c,
                icon: Icons.lock,
                onToggleObscure: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expectPrivate(fieldIn(tester, find.byKey(const Key('plain'))), private: false);
    expectPrivate(fieldIn(tester, find.byKey(const Key('code'))), private: true);
    expectPrivate(fieldIn(tester, find.byKey(const Key('shown'))), private: true);
  });

  testWidgets('the OTP code and the new password are private', (tester) async {
    await tester.pumpWidget(
      TestHarness().wrap(const OtpScreen(phone: '01012345678', purpose: 'password_reset')),
    );
    await tester.pump();
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields, hasLength(2));
    for (final f in fields) {
      expectPrivate(f, private: true);
    }
  });
}
