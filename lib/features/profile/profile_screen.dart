import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'doctor_profile_screen.dart';
import 'edit_profile_screen.dart';

/// What "my profile" opens.
///
/// An approved doctor gets their professional profile; everyone else keeps the
/// account editor exactly as it was. The choice follows the backend's role (via
/// the auth state), so it updates if the account or its role changes.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDoctor = ref.watch(currentUserProvider.select((u) => u?.isActiveDoctor ?? false));
    return isDoctor ? const DoctorProfileScreen() : const EditProfileScreen();
  }
}
