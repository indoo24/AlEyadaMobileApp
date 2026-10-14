import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/api/api_error.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';

/// Send a verification code to [phone] and open the code screen, which returns
/// to [next] once the phone is verified.
///
/// Purpose `signup` — the same request the booking sheet and the website's
/// booking step use to verify an existing account's phone. A failure (for
/// instance throttling) is reported in a snackbar and nothing navigates.
Future<void> startPhoneVerification(
  BuildContext context,
  WidgetRef ref, {
  required String phone,
  required String next,
}) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(authRepositoryProvider).requestOtp(phone: phone, purpose: 'signup');
    router.push(
      '${Routes.otp}?phone=${Uri.encodeComponent(phone)}&purpose=signup'
      '&next=${Uri.encodeComponent(next)}',
    );
  } on ApiException catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(messageForError(context, e))));
    }
  }
}
