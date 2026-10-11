import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_icon.dart';

/// Small overlapping circles showing up to [maxVisible] member photos, with
/// a "+N" bubble for the rest — used on session cards to hint who's joined
/// without needing the full list (tapping the card shows full names).
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.photoUrls,
    required this.totalCount,
    this.maxVisible = 5,
    this.radius = 14,
  });

  final List<String> photoUrls;
  final int totalCount;
  final int maxVisible;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final visibleCount = min(totalCount, maxVisible);
    final overflow = totalCount - visibleCount;
    final step = radius * 1.3;
    final totalSlots = visibleCount + (overflow > 0 ? 1 : 0);

    if (totalCount <= 0) {
      return SizedBox(
        height: radius * 2,
        width: radius * 2,
        child: CircleAvatar(
          radius: radius,
          backgroundColor: context.palette.accentTint,
          child: AppIcon(AppIcons.user, size: radius, color: context.palette.accent),
        ),
      );
    }

    return SizedBox(
      height: radius * 2,
      width: (totalSlots > 0 ? step * (totalSlots - 1) : 0) + (radius * 2),
      child: Stack(
        children: [
          for (var i = 0; i < visibleCount; i++)
            Positioned(
              left: i * step,
              child: CircleAvatar(
                radius: radius,
                backgroundColor: context.palette.background,
                child: CircleAvatar(
                  radius: radius - 2,
                  backgroundColor: context.palette.accentTint,
                  backgroundImage: i < photoUrls.length && photoUrls[i].isNotEmpty
                      ? CachedNetworkImageProvider(photoUrls[i])
                      : null,
                  child: i >= photoUrls.length || photoUrls[i].isEmpty
                      ? AppIcon(
                          AppIcons.user,
                          size: radius * 0.9,
                          color: context.palette.accent,
                        )
                      : null,
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visibleCount * step,
              child: CircleAvatar(
                radius: radius,
                backgroundColor: context.palette.background,
                child: CircleAvatar(
                  radius: radius - 2,
                  backgroundColor: context.palette.accent,
                  child: Text(
                    '+$overflow',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
