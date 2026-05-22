import 'package:flutter/material.dart';

import '../core/craft_hub_theme.dart';

class CraftHubBackground extends StatelessWidget {
  const CraftHubBackground({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.bgSoft,
            palette.bg,
            palette.bg.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -90,
            left: -40,
            child: _glow(const Color(0xFF6F1D8E), 220),
          ),
          Positioned(
            top: 220,
            right: -70,
            child: _glow(const Color(0xFF0B546E), 220),
          ),
          Positioned(
            bottom: -120,
            left: 20,
            child: _glow(const Color(0xFF5E186F), 240),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  static Widget _glow(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.32),
              color.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class CraftHubPanel extends StatelessWidget {
  const CraftHubPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 24,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class CraftHubSegmentedTabBar extends StatelessWidget {
  const CraftHubSegmentedTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.radius = 24,
    this.innerRadius = 18,
    this.labelColor = const Color(0xFF16071F),
    this.unselectedLabelColor = CraftHubColors.muted,
  });

  final TabController controller;
  final List<Widget> tabs;
  final double radius;
  final double innerRadius;
  final Color labelColor;
  final Color unselectedLabelColor;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    final inactiveLabelColor = Theme.of(context).brightness == Brightness.dark
        ? unselectedLabelColor
        : palette.muted;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.border),
        gradient: LinearGradient(
          colors: [
            palette.panelAlt.withValues(alpha: 0.96),
            palette.panel.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(innerRadius),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelColor: labelColor,
        unselectedLabelColor: inactiveLabelColor,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
        ),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(innerRadius),
          gradient: const LinearGradient(
            colors: [CraftHubColors.cyan, CraftHubColors.lavender],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(
              color: CraftHubColors.purple.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        tabs: tabs,
      ),
    );
  }
}

class CraftHubStatChip extends StatelessWidget {
  const CraftHubStatChip({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
    this.icon,
  });

  final String label;
  final String value;
  final bool highlight;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: highlight
            ? CraftHubColors.lavender.withValues(alpha: 0.14)
            : palette.panelAlt.withValues(alpha: 0.9),
        border: Border.all(
          color: highlight ? CraftHubColors.lavender : palette.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: highlight ? CraftHubColors.cyan : palette.muted,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: palette.text,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: highlight ? palette.text : palette.muted,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class CraftHubEmptyState extends StatelessWidget {
  const CraftHubEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return CraftHubPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CraftHubIconBubble(icon: icon, size: 58, active: true),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class CraftHubGradientText extends StatelessWidget {
  const CraftHubGradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient = CraftHubColors.accentAlt,
  });

  final String text;
  final TextStyle? style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style ?? Theme.of(context).textTheme.headlineMedium;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: resolvedStyle),
    );
  }
}

class CraftHubSectionTitle extends StatelessWidget {
  const CraftHubSectionTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                eyebrow.toUpperCase(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: CraftHubColors.lavender,
                ),
              ),
            ),
            ...?(trailing == null ? null : [trailing!]),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ],
    );
  }
}

class CraftHubTag extends StatelessWidget {
  const CraftHubTag({
    super.key,
    required this.label,
    this.icon,
    this.highlight = false,
  });

  final String label;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? CraftHubColors.lavender.withValues(alpha: 0.18)
            : palette.panelAlt.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight ? CraftHubColors.cyan : palette.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: CraftHubColors.cyan),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
        ],
      ),
    );
  }
}

class CraftHubIconBubble extends StatelessWidget {
  const CraftHubIconBubble({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 52,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? CraftHubColors.lavender.withValues(alpha: 0.18)
            : palette.panelAlt.withValues(alpha: 0.9),
        border: Border.all(
          color: active ? CraftHubColors.lavender : palette.border,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: CraftHubColors.purple.withValues(alpha: 0.28),
                  blurRadius: 22,
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: palette.text),
    );
    if (onTap == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(size),
      onTap: onTap,
      child: child,
    );
  }
}
