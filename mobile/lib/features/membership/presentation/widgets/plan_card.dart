import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_card.dart';
import '../../domain/membership_plan.dart';

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

    final trainingTypeLabel = switch (plan.trainingType) {
      'group' => AppStrings.groupTraining,
      'duo' => AppStrings.duoTraining,
      _ => AppStrings.privateTraining,
    };

    return Semantics(
      selected: selected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.s14),
        child: JbbCard(
          selected: selected,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Badges & Actions Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Training type chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s8,
                      vertical: AppSizes.s4,
                    ),
                    decoration: BoxDecoration(
                      color: context.palette.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.radius6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          AppIcons.boxingGlove,
                          size: 12,
                          color: context.palette.accent,
                        ),
                        const SizedBox(width: AppSizes.s4),
                        Text(
                          trainingTypeLabel.toUpperCase(),
                          style: TextStyle(
                            color: context.palette.accent,
                            fontSize: AppSizes.font10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (discounted) ...[
                    const SizedBox(width: AppSizes.s6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.s8,
                        vertical: AppSizes.s4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSizes.radius6),
                      ),
                      child: Text(
                        '${plan.discountPercent.toStringAsFixed(0)}% OFF',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: AppSizes.font10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (plan.isRecommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.s8,
                        vertical: AppSizes.s4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade700,
                            Colors.orange.shade800,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppSizes.radius6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            AppStrings.uiRecommended,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppSizes.font10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              if (plan.imageUrl != null && plan.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: AppSizes.s12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radius10),
                  child: CachedNetworkImage(
                    imageUrl: plan.imageUrl!,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              const SizedBox(height: AppSizes.s12),

              // Plan Name
              Text(
                plan.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppSizes.font18,
                ),
              ),

              if ((plan.description ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSizes.s4),
                Text(
                  plan.description!,
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: AppSizes.font13,
                    height: 1.35,
                  ),
                ),
              ],

              const SizedBox(height: AppSizes.s14),
              const Divider(height: 1),
              const SizedBox(height: AppSizes.s12),

              // Price & Session breakdown
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (discounted) ...[
                              Text(
                                plan.priceLabel,
                                style: TextStyle(
                                  color: context.palette.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: AppSizes.font14,
                                ),
                              ),
                              const SizedBox(width: AppSizes.s6),
                            ],
                            Text(
                              discounted
                                  ? '\$${(sale / 100).toStringAsFixed(2)}'
                                  : plan.priceLabel,
                              style: TextStyle(
                                fontSize: AppSizes.font24,
                                fontWeight: FontWeight.bold,
                                color: discounted
                                    ? Colors.green.shade700
                                    : context.palette.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (plan.perSessionLabel.isNotEmpty) ...[
                          const SizedBox(height: AppSizes.s2),
                          Text(
                            plan.perSessionLabel,
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: AppSizes.font12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Selection Radio Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.s12,
                      vertical: AppSizes.s6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? context.palette.accent
                          : context.palette.separator.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppSizes.radius20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? Icons.check_circle : Icons.circle_outlined,
                          size: 14,
                          color: selected
                              ? Colors.white
                              : context.palette.textSecondary,
                        ),
                        const SizedBox(width: AppSizes.s6),
                        Text(
                          selected ? 'Selected' : 'Select',
                          style: TextStyle(
                            fontSize: AppSizes.font12,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? Colors.white
                                : context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
