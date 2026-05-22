import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    this.imageFile,
    this.radius = 20,
    this.borderColor,
  });

  final String? imageUrl;
  final File? imageFile;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final normalizedUrl = (imageUrl ?? '').trim();
    final strokeColor = borderColor ?? Colors.black.withOpacity(0.08);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: strokeColor),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _AvatarFallback(radius: radius),
          if (imageFile != null)
            Image.file(imageFile!, fit: BoxFit.cover)
          else if (normalizedUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: normalizedUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7F7F7), Color(0xFF1D1D1D)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _AvatarTexturePainter()),
          Center(
            child: Icon(
              Icons.person_rounded,
              size: radius * 1.22,
              color: Colors.black.withOpacity(0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width * 0.22;
    final stripeWidth = size.width * 0.12;
    final darkStripe = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..strokeWidth = stripeWidth;
    final lightStripe = Paint()
      ..color = Colors.white.withOpacity(0.16)
      ..strokeWidth = stripeWidth * 0.8;

    var x = -size.height;
    var useDark = true;
    while (x < size.width + size.height) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        useDark ? darkStripe : lightStripe,
      );
      x += step;
      useDark = !useDark;
    }

    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.55, -0.75),
        radius: 0.7,
        colors: [
          Colors.white.withOpacity(0.48),
          Colors.white.withOpacity(0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow);

    final shadow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.24),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, shadow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
