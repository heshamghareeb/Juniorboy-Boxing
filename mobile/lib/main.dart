import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as timezone;
import 'core/resources/app_sizes.dart';
import 'core/resources/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/services/firebase_service.dart';
import 'core/services/notification_service.dart';
import 'features/profile/presentation/providers/profile_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  timezone.initializeTimeZones();
  await Hive.initFlutter();
  await Hive.openBox('jbb_cache');
  await Hive.openBox('jbb_device');
  try {
    await FirebaseService.initialize();
    if (!FirebaseService.useEmulators) {
      FirebaseMessaging.onBackgroundMessage(backgroundMessage);
    }
    runApp(const ProviderScope(child: JbbApp()));
  } catch (_) {
    runApp(
      MaterialApp(
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        home: const Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.s28),
              child: Center(child: Text(AppStrings.startupError)),
            ),
          ),
        ),
      ),
    );
  }
}

class JbbApp extends ConsumerWidget {
  const JbbApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    NotificationService.instance.navigate = (path) => router.go(path);
    ref.listen(profileProvider, (previous, next) {
      if (next.value?.isActive == true &&
          (previous?.value == null || previous?.value?.id != next.value?.id)) {
        NotificationService.instance.register().catchError((Object error) {
          debugPrint('Notification registration failed: $error');
        });
      }
    });
    return MaterialApp.router(
      title: AppStrings.gymName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}


