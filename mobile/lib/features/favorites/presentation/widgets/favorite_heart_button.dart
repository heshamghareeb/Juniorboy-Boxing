import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_palette.dart';
import '../providers/favorites_provider.dart';

enum FavoriteTargetType { product, plan, session }

class FavoriteHeartButton extends ConsumerStatefulWidget {
  const FavoriteHeartButton({
    super.key,
    required this.id,
    required this.type,
    this.size = 22,
    this.padding = const EdgeInsets.all(8),
    this.backgroundColor,
  });

  final String id;
  final FavoriteTargetType type;
  final double size;
  final EdgeInsets padding;
  final Color? backgroundColor;

  @override
  ConsumerState<FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends ConsumerState<FavoriteHeartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool currentIsFav) async {
    HapticFeedback.lightImpact();
    _controller.forward(from: 0.0);
    final repo = ref.read(favoritesRepositoryProvider);
    if (widget.type == FavoriteTargetType.product) {
      await repo.toggleProductFavorite(widget.id);
    } else if (widget.type == FavoriteTargetType.plan) {
      await repo.togglePlanFavorite(widget.id);
    } else {
      await repo.toggleSessionFavorite(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFav = switch (widget.type) {
      FavoriteTargetType.product =>
        (ref.watch(favoriteProductIdsProvider).value ?? const []).contains(widget.id),
      FavoriteTargetType.plan =>
        (ref.watch(favoritePlanIdsProvider).value ?? const []).contains(widget.id),
      FavoriteTargetType.session =>
        (ref.watch(favoriteSessionIdsProvider).value ?? const []).contains(widget.id),
    };

    final bgColor = widget.backgroundColor ??
        context.palette.surface.withValues(alpha: 0.85);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggle(isFav),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isFav
                    ? Colors.redAccent.withValues(alpha: 0.4)
                    : context.palette.separator.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isFav
                      ? Colors.redAccent.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: widget.size,
              color: isFav ? Colors.redAccent : context.palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
