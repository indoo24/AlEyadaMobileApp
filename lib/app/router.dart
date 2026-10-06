import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/models.dart';
import '../core/providers.dart';
import '../features/auth/consent_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/sign_up_screen.dart';
import '../features/bookings/booking_detail_screen.dart';
import '../features/bookings/bookings_screen.dart';
import '../features/doctors/doctor_detail_screen.dart';
import '../features/doctors/doctors_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/join_doctor_screen.dart';
import '../features/practice/practice_screen.dart';
import '../features/profile/account_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import 'shell.dart';
import 'splash.dart';

/// Route names, so nothing navigates by a hand-typed string.
class Routes {
  const Routes._();

  static const splash = '/splash';
  static const home = '/';
  static const doctors = '/doctors';
  static const doctor = '/doctors/:slug';
  static const bookings = '/bookings';
  static const favorites = '/favorites';
  static const bookingDetail = '/bookings/:id';
  static const account = '/account';
  static const editProfile = '/account/edit';
  static const notifications = '/notifications';

  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const otp = '/verify';
  static const consent = '/consent';

  static const join = '/join';
  static const practice = '/practice';

  static String doctorPath(String slug) => '/doctors/$slug';
  static String bookingPath(String id) => '/bookings/$id';
}

/// Routes a signed-out visitor may not see.
const _authenticatedOnly = <String>{
  Routes.bookings,
  Routes.account,
  Routes.editProfile,
  Routes.notifications,
  Routes.practice,
};

/// Routes that only make sense when signed out.
const _guestOnly = <String>{Routes.signIn, Routes.signUp};

final routerProvider = Provider<GoRouter>((ref) {
  // A plain Listenable so go_router re-evaluates its guards the instant the
  // session changes, rather than on the next navigation.
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      // Hold everyone on the splash until the session question is answered.
      // Showing a sign-in screen to someone who is signed in is the most visible
      // way to get session restoration wrong.
      if (auth.isRestoring) {
        return loc == Routes.splash ? null : Routes.splash;
      }
      if (loc == Routes.splash) {
        // Session settled, but let the launch animation finish before leaving.
        if (!ref.read(splashAnimationDoneProvider)) return null;
        return auth.hasSession ? _homeFor(auth.user) : Routes.home;
      }

      // Policies moved on: the backend will refuse every write until they are
      // re-accepted, so there is nothing useful to do elsewhere first.
      final user = auth.user;
      if (auth.isAuthenticated && user!.mustReacceptPolicies && loc != Routes.consent) {
        return Routes.consent;
      }
      if (loc == Routes.consent && (user == null || !user.mustReacceptPolicies)) {
        return _homeFor(user);
      }

      if (!auth.hasSession && _isProtected(loc)) {
        // Remember where they were headed so signing in resumes it.
        return '${Routes.signIn}?next=${Uri.encodeComponent(state.uri.toString())}';
      }

      if (auth.hasSession && _guestOnly.contains(loc)) {
        return _homeFor(user);
      }

      // The practice area belongs to approved doctors. An applicant is
      // deliberately role=patient while under review, so this also keeps them out
      // of a dashboard that would 403 on every request.
      if (loc.startsWith(Routes.practice) && auth.isAuthenticated && !user!.isActiveDoctor) {
        return Routes.home;
      }

      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: Routes.signIn,
        builder: (_, state) => SignInScreen(next: state.uri.queryParameters['next']),
      ),
      GoRoute(path: Routes.signUp, builder: (_, __) => const SignUpScreen()),
      GoRoute(
        path: Routes.otp,
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return OtpScreen(
            phone: q['phone'] ?? '',
            purpose: q['purpose'] ?? 'signup',
            next: q['next'],
          );
        },
      ),
      GoRoute(path: Routes.consent, builder: (_, __) => const ConsentScreen()),
      GoRoute(path: Routes.join, builder: (_, __) => const JoinDoctorScreen()),

      // The tabbed area. A shell so the bottom bar does not rebuild between tabs.
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: Routes.doctors,
            builder: (_, state) =>
                DoctorsScreen(autofocus: state.uri.queryParameters['focus'] == '1'),
          ),
          GoRoute(path: Routes.bookings, builder: (_, __) => const BookingsScreen()),
          GoRoute(path: Routes.favorites, builder: (_, __) => const FavoritesScreen()),
          GoRoute(path: Routes.practice, builder: (_, __) => const PracticeScreen()),
          GoRoute(path: Routes.account, builder: (_, __) => const AccountScreen()),
        ],
      ),

      GoRoute(
        path: Routes.doctor,
        builder: (_, state) => DoctorDetailScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: Routes.bookingDetail,
        builder: (_, state) => BookingDetailScreen(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(path: Routes.editProfile, builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: Routes.notifications, builder: (_, __) => const NotificationsScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('404 — ${state.uri}')),
    ),
  );
});

bool _isProtected(String location) =>
    _authenticatedOnly.any((r) => location == r || location.startsWith('$r/'));

/// Where a given user belongs on launch.
///
/// A doctor's home is their practice; everyone else starts in the directory —
/// the same split the website makes.
String _homeFor(Me? user) {
  if (user != null && user.isActiveDoctor) return Routes.practice;
  return Routes.home;
}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen<AuthState>(
      authControllerProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
    // The splash is left when the animation ends, not only when auth changes.
    _splashSub = ref.listen<bool>(
      splashAnimationDoneProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
  }

  late final ProviderSubscription<AuthState> _sub;
  late final ProviderSubscription<bool> _splashSub;

  @override
  void dispose() {
    _sub.close();
    _splashSub.close();
    super.dispose();
  }
}
