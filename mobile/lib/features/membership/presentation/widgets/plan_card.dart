import '../../../../core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_colors.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_card.dart';
import '../../domain/membership_plan.dart';
import '../../../favorites/presentation/widgets/favorite_heart_button.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.selected,
    required this.onTap,
  });
  final MembershipPlan plan;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final discounted = plan.discountActive && plan.discountPercent > 0;
    final sale = ((plan.price ?? 0) * (1 - plan.discountPercent / 100)).round();
    return Semantics(
      selected: selected,
      button: true,
      child: JbbCard(
        selected: selected,
        onTap: onTap,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plan.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radius8),
                child: CachedNetworkImage(
                  imageUrl: plan.imageUrl!,
                  height: 88,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: AppSizes.s10),
            ],
            Text(
              switch (plan.trainingType) {
                'group' => AppStrings.groupTraining,
                'duo' => AppStrings.duoTraining,
                _ => AppStrings.privateTraining,
              },
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: AppSizes.font10,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppSizes.s6),
            if (discounted)
              Text(
                '${plan.discountPercent.toStringAsFixed(0)}% OFF',
                style: TextStyle(
                  color: context.palette.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (plan.isRecommended == true)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.s10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.palette.accent,
                    borderRadius: BorderRadius.circular(AppSizes.radius4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s8,
                      vertical: AppSizes.s4,
                    ),
                    child: Text(
                      AppStrings.uiRecommended,
                      style: const TextStyle(
                        color: AppColors.onAccent,
                        fontSize: AppSizes.font11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: AppSizes.labelTracking,
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                AppIcon(
                  selected ? AppIcons.checkCircle : AppIcons.circle,
                  color: selected
                      ? context.palette.accent
                      : context.palette.textSecondary,
                ),
                SizedBox(width: AppSizes.s12),
                Expanded(
                  child: Text(
                    plan.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.font17,
                    ),
                  ),
                ),
                if (discounted)
                  Text(
                    plan.priceLabel,
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                if (discounted) SizedBox(width: AppSizes.s6),
                Text(
                  discounted
                      ? '\$${(sale / 100).toStringAsFixed(2)}'
                      : plan.priceLabel,
                  style: TextStyle(
                    fontSize: AppSizes.font22,
                    fontWeight: FontWeight.bold,
                    color: discounted ? context.palette.success : null,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: AppSizes.s36,
                top: AppSizes.s8,
              ),
              child: Text(
                plan.perSessionLabel,
                style: TextStyle(color: context.palette.textSecondary),
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
          child: FavoriteHeartButton(
            id: plan.id,
            type: FavoriteTargetType.plan,
            size: 18,
            padding: const EdgeInsets.all(6),
          ),
        ),
      ],
    ),
  ),
);
  }
}
