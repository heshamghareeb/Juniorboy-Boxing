import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../providers/profile_provider.dart';

import '../../../../core/widgets/jbb_button.dart';

class InformationScreen extends ConsumerWidget {
  const InformationScreen({
    super.key,
    required this.title,
    this.text,
    this.showAcceptButton = false,
  });

  final String title;
  final String? text;
  final bool? showAcceptButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.s24),
      child: Text(
        text ??
            ref.watch(settingsProvider).value?.aboutText ??
            AppStrings.uiDisciplineBuildsChampionsTrainLearnAndGrowAt,
        style: const TextStyle(
          height: AppSizes.lineHeightLegal,
          fontSize: AppSizes.font15,
        ),
      ),
    ),
    bottomNavigationBar: (showAcceptButton == true)
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.s24,
                vertical: AppSizes.s12,
              ),
              child: JbbButton(
                label: AppStrings.acceptAndContinue,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          )
        : null,
  );
}
