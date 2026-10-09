import 'package:flutter/material.dart';
import '../resources/app_assets.dart';
import '../resources/app_sizes.dart';
import '../resources/app_strings.dart';

class PageContent extends StatelessWidget {
  const PageContent({
    super.key,
    required this.children,
    this.title,
    this.refresh,
    this.showHeader = true,
  });
  final List<Widget> children;
  final String? title;
  final Future<void> Function()? refresh;
  final bool showHeader;
  @override
  Widget build(BuildContext context) {
    final view = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.s16,
        AppSizes.s12,
        AppSizes.s16,
        AppSizes.s28,
      ),
      children: [
        if (showHeader) ...[
          Image.asset(
            AppAssets.header,
            fit: BoxFit.fitWidth,
            semanticLabel:
                AppStrings.uiJuniorBoyBoxingDisciplineBuildsChampions,
          ),
          const SizedBox(height: AppSizes.s24),
        ],
        if (title != null) ...[
          Text(title!, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSizes.s20),
        ],
        ...children,
      ],
    );
    final content = refresh == null
        ? view
        : RefreshIndicator(onRefresh: refresh!, child: view);
    return Material(
      type: MaterialType.transparency,
      child: content,
    );
  }
}
