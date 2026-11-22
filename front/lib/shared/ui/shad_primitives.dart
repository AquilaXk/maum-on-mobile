// Clean-room surface, card, badge, and theme primitives built solely on Flutter Material.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
class ShadColorScheme {
  const ShadColorScheme({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.border,
    required this.input,
    required this.ring,
    required this.selection,
  });

  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color border;
  final Color input;
  final Color ring;
  final Color selection;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ShadColorScheme &&
        other.background == background &&
        other.foreground == foreground &&
        other.card == card &&
        other.cardForeground == cardForeground &&
        other.popover == popover &&
        other.popoverForeground == popoverForeground &&
        other.primary == primary &&
        other.primaryForeground == primaryForeground &&
        other.secondary == secondary &&
        other.secondaryForeground == secondaryForeground &&
        other.muted == muted &&
        other.mutedForeground == mutedForeground &&
        other.accent == accent &&
        other.accentForeground == accentForeground &&
        other.destructive == destructive &&
        other.destructiveForeground == destructiveForeground &&
        other.border == border &&
        other.input == input &&
        other.ring == ring &&
        other.selection == selection;
  }

  @override
  int get hashCode => Object.hash(
        background,
        foreground,
        card,
        cardForeground,
        popover,
        popoverForeground,
        primary,
        primaryForeground,
        secondary,
        secondaryForeground,
        muted,
        mutedForeground,
        accent,
        accentForeground,
        destructive,
        destructiveForeground,
        border,
        input,
        ring,
        selection,
      );
}

@immutable
class ShadBorder {
  const ShadBorder.all({
    this.color,
    this.width,
  });

  final Color? color;
  final double? width;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ShadBorder &&
        other.color == color &&
        other.width == width;
  }

  @override
  int get hashCode => Object.hash(color, width);
}

@immutable
class ShadCardTheme {
  const ShadCardTheme({
    this.backgroundColor,
    this.padding,
    this.radius,
    this.border,
    this.shadows,
  });

  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? radius;
  final ShadBorder? border;
  final List<BoxShadow>? shadows;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ShadCardTheme &&
        other.backgroundColor == backgroundColor &&
        other.padding == padding &&
        other.radius == radius &&
        other.border == border &&
        listEquals(other.shadows, shadows);
  }

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        padding,
        radius,
        border,
        shadows == null ? null : Object.hashAll(shadows!),
      );
}

@immutable
class ShadBadgeTheme {
  const ShadBadgeTheme({
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.foregroundColor,
    this.shape,
    this.padding,
  });

  final Color? backgroundColor;
  final Color? hoverBackgroundColor;
  final Color? foregroundColor;
  final OutlinedBorder? shape;
  final EdgeInsetsGeometry? padding;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ShadBadgeTheme &&
        other.backgroundColor == backgroundColor &&
        other.hoverBackgroundColor == hoverBackgroundColor &&
        other.foregroundColor == foregroundColor &&
        other.shape == shape &&
        other.padding == padding;
  }

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        hoverBackgroundColor,
        foregroundColor,
        shape,
        padding,
      );
}

@immutable
class ShadThemeData {
  const ShadThemeData({
    required this.brightness,
    required this.colorScheme,
    required this.radius,
    this.cardTheme,
    this.primaryBadgeTheme,
    this.secondaryBadgeTheme,
    this.outlineBadgeTheme,
    this.destructiveBadgeTheme,
  });

  final Brightness brightness;
  final ShadColorScheme colorScheme;
  final BorderRadius radius;
  final ShadCardTheme? cardTheme;
  final ShadBadgeTheme? primaryBadgeTheme;
  final ShadBadgeTheme? secondaryBadgeTheme;
  final ShadBadgeTheme? outlineBadgeTheme;
  final ShadBadgeTheme? destructiveBadgeTheme;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ShadThemeData &&
        other.brightness == brightness &&
        other.colorScheme == colorScheme &&
        other.radius == radius &&
        other.cardTheme == cardTheme &&
        other.primaryBadgeTheme == primaryBadgeTheme &&
        other.secondaryBadgeTheme == secondaryBadgeTheme &&
        other.outlineBadgeTheme == outlineBadgeTheme &&
        other.destructiveBadgeTheme == destructiveBadgeTheme;
  }

  @override
  int get hashCode => Object.hash(
        brightness,
        colorScheme,
        radius,
        cardTheme,
        primaryBadgeTheme,
        secondaryBadgeTheme,
        outlineBadgeTheme,
        destructiveBadgeTheme,
      );
}

class ShadTheme extends InheritedWidget {
  const ShadTheme({
    required this.data,
    required super.child,
    super.key,
  });

  final ShadThemeData data;

  static ShadThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShadTheme>()?.data;
  }

  static ShadThemeData of(BuildContext context) {
    final data = maybeOf(context);
    if (data == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('ShadTheme.of() called with a context without ShadTheme.'),
        ErrorDescription(
          'Ensure a ShadTheme or MaumShadThemeScope ancestor wraps this widget.',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return data;
  }

  @override
  bool updateShouldNotify(ShadTheme oldWidget) => data != oldWidget.data;
}

class ShadCard extends StatelessWidget {
  const ShadCard({
    this.child,
    this.padding,
    this.backgroundColor,
    this.radius,
    this.border,
    this.shadows,
    this.width,
    this.height,
    this.rowMainAxisSize = MainAxisSize.min,
    this.rowMainAxisAlignment = MainAxisAlignment.spaceBetween,
    this.columnCrossAxisAlignment = CrossAxisAlignment.start,
    super.key,
  });

  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final BorderRadius? radius;
  final ShadBorder? border;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;
  final MainAxisSize rowMainAxisSize;
  final MainAxisAlignment rowMainAxisAlignment;
  final CrossAxisAlignment columnCrossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.maybeOf(context);
    final materialTheme = Theme.of(context);
    final cardTheme = shadTheme?.cardTheme;

    final effectiveBackground = backgroundColor ??
        cardTheme?.backgroundColor ??
        shadTheme?.colorScheme.card ??
        materialTheme.colorScheme.surface;
    final effectiveForeground = shadTheme?.colorScheme.cardForeground ??
        materialTheme.colorScheme.onSurface;
    final effectivePadding =
        padding ?? cardTheme?.padding ?? const EdgeInsets.all(16);
    final effectiveRadius = radius ??
        cardTheme?.radius ??
        shadTheme?.radius ??
        BorderRadius.circular(16);
    final effectiveShadows = shadows ?? cardTheme?.shadows;

    final Border? effectiveBoxBorder;
    final effectiveBorderSpec = border ?? cardTheme?.border;
    if (effectiveBorderSpec != null) {
      final borderWidth = effectiveBorderSpec.width ?? 1.0;
      if (borderWidth <= 0) {
        effectiveBoxBorder = null;
      } else {
        final borderColor = effectiveBorderSpec.color ??
            shadTheme?.colorScheme.border ??
            materialTheme.colorScheme.outlineVariant;
        effectiveBoxBorder = Border.all(color: borderColor, width: borderWidth);
      }
    } else if (shadTheme == null) {
      effectiveBoxBorder = Border.all(
        color: materialTheme.colorScheme.outlineVariant,
        width: 1,
      );
    } else {
      effectiveBoxBorder = null;
    }

    Widget? body;
    if (child != null) {
      final column = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: columnCrossAxisAlignment,
        children: [child!],
      );
      final flexChild = columnCrossAxisAlignment == CrossAxisAlignment.stretch
          ? Expanded(child: column)
          : Flexible(fit: FlexFit.loose, child: column);
      body = Row(
        mainAxisSize: rowMainAxisSize,
        mainAxisAlignment: rowMainAxisAlignment,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [flexChild],
      );
    }

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: effectiveRadius,
        border: effectiveBoxBorder,
        boxShadow: effectiveShadows,
      ),
      child: Padding(
        padding: effectivePadding,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: effectiveForeground),
          child: body ?? const SizedBox.shrink(),
        ),
      ),
    );

    if (width != null || height != null) {
      return SizedBox(
        width: width,
        height: height,
        child: decorated,
      );
    }
    return decorated;
  }
}

enum ShadBadgeVariant { primary, secondary, outline, destructive }

class ShadBadge extends StatelessWidget {
  const ShadBadge({
    required this.child,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.foregroundColor,
    this.shape,
    this.padding,
    super.key,
  }) : variant = ShadBadgeVariant.primary;

  const ShadBadge.secondary({
    required this.child,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.foregroundColor,
    this.shape,
    this.padding,
    super.key,
  }) : variant = ShadBadgeVariant.secondary;

  const ShadBadge.outline({
    required this.child,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.foregroundColor,
    this.shape,
    this.padding,
    super.key,
  }) : variant = ShadBadgeVariant.outline;

  const ShadBadge.destructive({
    required this.child,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.foregroundColor,
    this.shape,
    this.padding,
    super.key,
  }) : variant = ShadBadgeVariant.destructive;

  const ShadBadge.raw({
    required this.variant,
    required this.child,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.foregroundColor,
    this.shape,
    this.padding,
    super.key,
  });

  final ShadBadgeVariant variant;
  final Widget child;
  final Color? backgroundColor;
  final Color? hoverBackgroundColor;
  final Color? foregroundColor;
  final OutlinedBorder? shape;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.maybeOf(context);
    final materialTheme = Theme.of(context);
    final materialScheme = materialTheme.colorScheme;
    final badgeTheme = switch (variant) {
      ShadBadgeVariant.primary => shadTheme?.primaryBadgeTheme,
      ShadBadgeVariant.secondary => shadTheme?.secondaryBadgeTheme,
      ShadBadgeVariant.outline => shadTheme?.outlineBadgeTheme,
      ShadBadgeVariant.destructive => shadTheme?.destructiveBadgeTheme,
    };

    final fallbackBackground = switch (variant) {
      ShadBadgeVariant.primary =>
        shadTheme?.colorScheme.primary ?? materialScheme.primary,
      ShadBadgeVariant.secondary =>
        shadTheme?.colorScheme.secondary ?? materialScheme.secondaryContainer,
      ShadBadgeVariant.outline => Colors.transparent,
      ShadBadgeVariant.destructive =>
        shadTheme?.colorScheme.destructive ?? materialScheme.error,
    };
    final fallbackForeground = switch (variant) {
      ShadBadgeVariant.primary =>
        shadTheme?.colorScheme.primaryForeground ?? materialScheme.onPrimary,
      ShadBadgeVariant.secondary =>
        shadTheme?.colorScheme.secondaryForeground ??
            materialScheme.onSecondaryContainer,
      ShadBadgeVariant.outline =>
        shadTheme?.colorScheme.foreground ?? materialScheme.onSurface,
      ShadBadgeVariant.destructive =>
        shadTheme?.colorScheme.destructiveForeground ?? materialScheme.onError,
    };
    final fallbackBorderColor =
        shadTheme?.colorScheme.border ?? materialScheme.outlineVariant;
    final OutlinedBorder defaultShape = variant == ShadBadgeVariant.outline
        ? StadiumBorder(side: BorderSide(color: fallbackBorderColor))
        : const StadiumBorder();

    final effectiveBackground =
        backgroundColor ?? badgeTheme?.backgroundColor ?? fallbackBackground;
    final effectiveHoverBackground = hoverBackgroundColor ??
        badgeTheme?.hoverBackgroundColor ??
        effectiveBackground;
    final effectiveForeground =
        foregroundColor ?? badgeTheme?.foregroundColor ?? fallbackForeground;
    final effectiveShape = shape ?? badgeTheme?.shape ?? defaultShape;
    final effectivePadding = padding ??
        badgeTheme?.padding ??
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

    final content = Padding(
      padding: effectivePadding,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: effectiveForeground,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: effectiveForeground, size: 14),
          child: child,
        ),
      ),
    );

    if (effectiveHoverBackground != effectiveBackground) {
      return _HoverBadgeSurface(
        backgroundColor: effectiveBackground,
        hoverBackgroundColor: effectiveHoverBackground,
        shape: effectiveShape,
        child: content,
      );
    }

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: effectiveBackground,
        shape: effectiveShape,
      ),
      child: content,
    );
  }
}

class _HoverBadgeSurface extends StatefulWidget {
  const _HoverBadgeSurface({
    required this.backgroundColor,
    required this.hoverBackgroundColor,
    required this.shape,
    required this.child,
  });

  final Color backgroundColor;
  final Color hoverBackgroundColor;
  final OutlinedBorder shape;
  final Widget child;

  @override
  State<_HoverBadgeSurface> createState() => _HoverBadgeSurfaceState();
}

class _HoverBadgeSurfaceState extends State<_HoverBadgeSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: _hovered ? widget.hoverBackgroundColor : widget.backgroundColor,
          shape: widget.shape,
        ),
        child: widget.child,
      ),
    );
  }
}
