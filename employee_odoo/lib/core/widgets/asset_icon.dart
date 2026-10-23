import 'package:flutter/material.dart';

/// Uses a bundled asset when present; otherwise falls back to [fallback].
class AssetIcon extends StatelessWidget {
  const AssetIcon({
    super.key,
    required this.assetPath,
    required this.fallback,
    this.size = 18,
    this.color,
  });

  final String assetPath;
  final IconData fallback;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      color: color,
      errorBuilder: (_, __, ___) => Icon(
        fallback,
        size: size,
        color: color ?? const Color(0xFF999999),
      ),
    );
  }
}
