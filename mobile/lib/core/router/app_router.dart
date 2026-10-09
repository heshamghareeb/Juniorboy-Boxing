import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/ad_editor_screen.dart';
import '../../features/sessions/presentation/screens/session_editor_screen.dart';
import '../../features/sessions/presentation/screens/session_members_screen.dart';
import '../../features/blog/presentation/screens/blog_screen.dart';
import '../../features/home/domain/home_ad.dart';
import '../../features/sessions/models/session_model.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/membership/presentation/screens/membership_screen.dart';
import '../../features/profile/presentation/providers/profile_provider.dart';
import '../../features/profile/presentation/screens/complete_profile_screen.dart';
import '../../features/profile/presentation/screens/contact_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/information_screen.dart';
import '../../features/profile/presentation/screens/more_screen.dart';
import '../../features/profile/presentation/screens/my_bookings_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/payments/presentation/screens/payments_screen.dart';
import '../../features/profile/presentation/screens/waiver_screen.dart';
import '../../features/reviews/presentation/screens/reviews_screen.dart';
import '../../features/store/presentation/screens/store_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../resources/app_strings.dart';
import 'app_routes.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, next) => refresh.value++);
  ref.listen(profileProvider, (_, next) => refresh.value++);
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final profile = ref.read(profileProvider);
      final isAuth = state.uri.path == AppRoutes.welcome;
      if (auth.isLoading) return null;
      final user = auth.value;
      if (user == null && !isAuth) return AppRoutes.welcome;
      final signedIn = user != null &&
          !user.isAnonymous &&
          (user.hasGoogleProvider || user.hasAppleProvider);
      if (signedIn &&
          ![
            AppRoutes.completeProfile,
            AppRoutes.waiver,
            AppRoutes.privacy,
            AppRoutes.terms,
            AppRoutes.contact,
          ].contains(state.uri.path) &&
          (profile.value != null && !profile.value!.isProfileComplete)) {
        return AppRoutes.completeProfile;
      }
      if (user != null && isAuth) return AppRoutes.home;
      if (state.uri.path.startsWith(AppRoutes.admin) &&
          profile.value?.role != 'admin' &&
          profile.value?.role != 'superAdmin') {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (c, s) => const WelcomeScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                name: 'more',
                builder: (c, s) => const MoreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bookings,
                name: 'bookings',
                builder: (c, s) => const MyBookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (c, s) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: 'profile',
                builder: (c, s) => const EditProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.admin,
                name: 'admin',
                builder: (c, s) => const AdminDashboardScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.store,
        name: 'store',
        builder: (c, s) => const StoreScreen(),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        name: 'favorites',
        builder: (c, s) => const FavoritesScreen(),
      ),
      GoRoute(
        path: AppRoutes.membership,
        builder: (c, s) => const MembershipScreen(),
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (c, s) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (c, s) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.payments,
        builder: (c, s) => const PaymentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.reviews,
        builder: (c, s) => const ReviewsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAdEditor,
        builder: (c, s) =>
            AdEditorScreen(ad: s.extra is HomeAd ? s.extra as HomeAd : null),
      ),
      GoRoute(
        path: AppRoutes.adminSessionEditor,
        builder: (c, s) => SessionEditorScreen(
          session: s.extra is SessionModel ? s.extra as SessionModel : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.sessionMembers,
        builder: (c, s) => SessionMembersScreen(session: s.extra as SessionModel),
      ),
      GoRoute(path: AppRoutes.blog, builder: (c, s) => const BlogScreen()),
      GoRoute(
        path: AppRoutes.contact,
        builder: (c, s) => const ContactScreen(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (c, s) => const InformationScreen(title: 'About Us'),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (c, s) => const InformationScreen(
          title: 'Privacy Policy',
          text: AppStrings.privacy,
        ),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (c, s) {
          final showAccept =
              s.extra is Map && (s.extra as Map)['showAccept'] == true;
          return InformationScreen(
            title: AppStrings.termsOfParticipationTitle,
            text: AppStrings.termsOfParticipationBody,
            showAcceptButton: showAccept,
          );
        },
      ),
      GoRoute(path: AppRoutes.waiver, builder: (c, s) => const WaiverScreen()),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
