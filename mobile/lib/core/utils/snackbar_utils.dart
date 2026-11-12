import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

String friendlyError(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Check your email and password.',
      'email-already-in-use' =>
        'This email already has an account. Sign in instead.',
      'network-request-failed' ||
      'unavailable' => 'Connection unavailable. Check your internet and retry.',
      'permission-denied' => 'You do not have access to this action.',
      _ => error.message ?? 'Unable to complete the action. Please retry.',
    };
  }
  return 'Unable to complete the action. Please retry.\n($error)';
}

OverlayEntry? _activeToast;

/// Displays a sleek, modern floating toast pill on screen.
void showToast(
  BuildContext context,
  String text, {
  IconData? icon = Icons.info_outline,
  Color? iconColor,
  Duration duration = const Duration(milliseconds: 2200),
}) {
  _activeToast?.remove();
  _activeToast = null;

  final overlay = Overlay.maybeOf(context);
  if (overlay == null) {
    showMessage(context, text);
    return;
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ToastPillWidget(
      text: text,
      icon: icon,
      iconColor: iconColor,
      duration: duration,
      onDismissed: () {
        if (_activeToast == entry) {
          entry.remove();
          _activeToast = null;
        }
      },
    ),
  );

  _activeToast = entry;
  overlay.insert(entry);
}

class _ToastPillWidget extends StatefulWidget {
  const _ToastPillWidget({
    required this.text,
    required this.icon,
    this.iconColor,
    required this.duration,
    required this.onDismissed,
  });

  final String text;
  final IconData? icon;
  final Color? iconColor;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_ToastPillWidget> createState() => _ToastPillWidgetState();
}

class _ToastPillWidgetState extends State<_ToastPillWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
    _timer = Timer(widget.duration, _hide);
  }

  Future<void> _hide() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 60, left: 24, right: 24),
            child: FadeTransition(
              opacity: _opacity,
              child: SlideTransition(
                position: _slide,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xF21D1D22),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: widget.iconColor ?? Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showMessage(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
