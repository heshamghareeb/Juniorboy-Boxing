import 'package:flutter/material.dart';
import '../resources/app_icons.dart';
import '../resources/app_sizes.dart';
import '../theme/app_palette.dart';
import 'app_icon.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppSizes.radiusCard),
    child: ColoredBox(
      color: context.palette.surface,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: AppSizes.s56),
                child: Divider(
                  height: AppSizes.separatorWidth,
                  thickness: AppSizes.separatorWidth,
                  color: context.palette.separator,
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.icon,
    this.iconWidget,
    this.onTap,
    this.trailing,
  });
  final String title;
  final String? icon;
  final Widget? iconWidget;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.s14,
          vertical: AppSizes.s10,
        ),
        child: Row(
          children: [
            iconWidget ?? (icon != null ? IconChip(icon: icon!) : const SizedBox.shrink()),
            const SizedBox(width: AppSizes.s12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: AppSizes.font16),
              ),
            ),
            trailing ??
                AppIcon(
                  AppIcons.chevronRight,
                  size: AppSizes.s18,
                  color: context.palette.textTertiary,
                ),
          ],
        ),
      ),
    ),
  );
}

class IconChip extends StatelessWidget {
  const IconChip({super.key, required this.icon});
  final String icon;
  @override
  Widget build(BuildContext context) => Container(
    width: AppSizes.iconChip,
    height: AppSizes.iconChip,
    decoration: BoxDecoration(
      color: context.palette.accentTint,
      borderRadius: BorderRadius.circular(AppSizes.iconChipRadius),
    ),
    alignment: Alignment.center,
    child: AppIcon(icon, size: AppSizes.s18, color: context.palette.accent),
  );
}
