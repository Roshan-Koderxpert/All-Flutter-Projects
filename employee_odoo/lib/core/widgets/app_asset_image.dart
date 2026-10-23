import 'package:flutter/material.dart';

/// Loads a bundled asset; shows [fallback] when the file is missing.
class AppAssetImage extends StatelessWidget {
  const AppAssetImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
    this.fallback,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      color: color,
      errorBuilder: (_, __, ___) =>
          fallback ??
          Icon(
            Icons.image_not_supported_outlined,
            size: width ?? height ?? 18,
            color: color ?? Colors.grey,
          ),
    );
  }
}
