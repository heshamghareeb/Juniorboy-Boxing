import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const themeModeKey = 'themeMode';
ThemeMode parseThemeMode(Object? value) => switch (value) {
  'light' => ThemeMode.light,
  'system' => ThemeMode.system,
  _ => ThemeMode.dark,
};

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => parseThemeMode(Hive.box('jbb_device').get(themeModeKey));
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await Hive.box('jbb_device').put(themeModeKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
