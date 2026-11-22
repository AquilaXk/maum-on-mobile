// Staggered three-dot typing indicator with reduced-motion fallback.
import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class JumpingDotsIndicator extends StatefulWidget {
  const JumpingDotsIndicator({
    this.dotSize = 7,
    this.spacing = 5,
    this.color,
    this.semanticLabel = '답변을 작성하고 있어요',
    super.key,
  });

  final double dotSize;
  final double spacing;
  final Color? color;
  final String semanticLabel;

  @override
  State<JumpingDotsIndicator> createState() => _JumpingDotsIndicatorState();
}

class _JumpingDotsIndicatorState extends State<JumpingDotsIndicator>
    with SingleTickerProviderStateMixin {
  static const int _dotCount = 3;
  static const double _jumpHeight = 5;

  AnimationController? _controller;
  bool _animationsDisabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled == _animationsDisabled && (_controller != null || disabled)) {
      return;
    }
    _animationsDisabled = disabled;
    if (disabled) {
      _controller?.stop();
      _controller?.dispose();
      _controller = null;
      return;
    }
    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? context.maumTokens.primary;

    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(_dotCount, (index) {
            final child = _DotCircle(
              size: widget.dotSize,
              color: dotColor,
            );
            final dot = _controller == null
                ? Opacity(
                    opacity: 0.72 + (index * 0.12).clamp(0.0, 0.28),
                    child: child,
                  )
                : _AnimatedJumpingDot(
                    animation: _controller!,
                    index: index,
                    jumpHeight: _jumpHeight,
                    child: child,
                  );
            return Padding(
              padding: EdgeInsets.only(
                right: index == _dotCount - 1 ? 0 : widget.spacing,
              ),
              child: dot,
            );
          }),
        ),
      ),
    );
  }
}

class _AnimatedJumpingDot extends StatelessWidget {
  const _AnimatedJumpingDot({
    required this.animation,
    required this.index,
    required this.jumpHeight,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final double jumpHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = index * 0.16;
    final peak = start + 0.24;
    final settle = start + 0.48;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, dotChild) {
        final t = animation.value;
        final double dy;
        final double opacity;
        if (t < start || t > settle) {
          dy = 0;
          opacity = 0.48;
        } else if (t <= peak) {
          final progress = Curves.easeOut.transform((t - start) / (peak - start));
          dy = -jumpHeight * progress;
          opacity = 0.48 + 0.52 * progress;
        } else {
          final progress = Curves.easeIn.transform((t - peak) / (settle - peak));
          dy = -jumpHeight * (1 - progress);
          opacity = 1.0 - 0.52 * progress;
        }
        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(opacity: opacity, child: dotChild),
        );
      },
    );
  }
}

class _DotCircle extends StatelessWidget {
  const _DotCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(dimension: size),
    );
  }
}
