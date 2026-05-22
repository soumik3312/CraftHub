import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/craft_hub_theme.dart';
import '../../widgets/craft_hub_ui.dart';

class CraftHubSplashScreen extends StatefulWidget {
  const CraftHubSplashScreen({super.key});

  @override
  State<CraftHubSplashScreen> createState() => _CraftHubSplashScreenState();
}

class _CraftHubSplashScreenState extends State<CraftHubSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CraftHubBackground(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final orbit = math.sin(t * math.pi * 2);
            final drift = math.cos(t * math.pi * 2);
            final pulse = 0.95 + (math.sin(t * math.pi * 2) * 0.05);

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 110 + (orbit * 18),
                  left: 28 + (drift * 10),
                  child: _AmbientOrb(
                    size: 110,
                    color: CraftHubColors.cyan.withValues(alpha: 0.16),
                  ),
                ),
                Positioned(
                  top: 180 + (drift * 20),
                  right: 26 + (orbit * 14),
                  child: _AmbientOrb(
                    size: 138,
                    color: CraftHubColors.lavender.withValues(alpha: 0.14),
                  ),
                ),
                Positioned(
                  bottom: 150 + (orbit * 16),
                  left: 50 + (drift * 10),
                  child: _AmbientOrb(
                    size: 126,
                    color: const Color(0xFF2563EB).withValues(alpha: 0.16),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.scale(
                            scale: pulse,
                            child: _LogoStage(progress: t),
                          ),
                          const SizedBox(height: 28),
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                                  colors: [
                                    CraftHubColors.cyan,
                                    Colors.white,
                                    CraftHubColors.lavender,
                                  ],
                                ).createShader(
                                  Rect.fromLTWH(
                                    0,
                                    0,
                                    bounds.width,
                                    bounds.height,
                                  ),
                                ),
                            child: Text(
                              'CraftHub',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.4,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Build projects, find collaborators, and ship together.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: palette.text.withValues(alpha: 0.8),
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 30),
                          _AnimatedLoader(progress: t),
                          const SizedBox(height: 16),
                          Text(
                            'Loading your workspace',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: palette.muted.withValues(alpha: 0.9),
                                  letterSpacing: 0.3,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LogoStage extends StatelessWidget {
  const _LogoStage({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    final rotation = (progress - 0.5) * 0.08;
    final glowStrength = 0.24 + (math.sin(progress * math.pi * 2) * 0.08);

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: rotation,
          child: Container(
            width: 206,
            height: 206,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  CraftHubColors.cyan.withValues(alpha: glowStrength),
                  CraftHubColors.lavender.withValues(
                    alpha: glowStrength * 0.72,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 166,
          height: 166,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1.2,
            ),
          ),
        ),
        Transform.rotate(
          angle: -rotation * 3,
          child: Container(
            width: 134,
            height: 134,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(38),
              gradient: LinearGradient(
                colors: [
                  palette.panel.withValues(alpha: 0.98),
                  palette.panelAlt.withValues(alpha: 0.96),
                  const Color(0xFF163A76).withValues(alpha: 0.92),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedLoader extends StatelessWidget {
  const _AnimatedLoader({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final wave = math.sin((progress * math.pi * 2) + (index * 0.8));
        final scale = 0.88 + ((wave + 1) * 0.12);
        final opacity = 0.35 + ((wave + 1) * 0.22);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == 1
                    ? CraftHubColors.cyan.withValues(alpha: opacity)
                    : CraftHubColors.lavender.withValues(alpha: opacity),
                boxShadow: [
                  BoxShadow(
                    color: CraftHubColors.cyan.withValues(alpha: opacity * 0.7),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}
