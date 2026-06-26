import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_theme.dart';

/// Widget réutilisable pour afficher l'image d'un plat.
/// - [imageUrl] peut être une URL http(s) ou un data URI base64 (data:image/...)
/// - Si null ou vide → affiche l'icône fourchette par défaut
/// Conserve exactement le même espace, la même forme et les mêmes coins arrondis.
class ProductImage extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  final double iconSize;
  final Color? bgColor;

  const ProductImage({
    super.key,
    required this.imageUrl,
    this.height = 100,
    this.width,
    this.borderRadius,
    this.iconSize = 36,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = bgColor ?? AppTheme.primary.withValues(alpha: 0.1);
    final radius = borderRadius ?? BorderRadius.circular(0);
    final url = imageUrl ?? '';
    final hasImage = url.isNotEmpty;

    Widget imageContent;

    if (!hasImage) {
      // Pas d'image — icône fourchette
      imageContent = Container(
        color: bg,
        child: Center(
          child: Icon(Icons.restaurant, color: AppTheme.primary, size: iconSize),
        ),
      );
    } else if (url.startsWith('data:image/')) {
      // Data URI base64
      imageContent = _Base64Image(dataUri: url, fit: BoxFit.cover, bg: bg, iconSize: iconSize);
    } else {
      // URL réseau standard
      imageContent = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          color: bg,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
          ),
        ),
        errorWidget: (context, _, __) => Container(
          color: bg,
          child: Center(
            child: Icon(Icons.restaurant, color: AppTheme.primary, size: iconSize),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: width ?? double.infinity,
        child: imageContent,
      ),
    );
  }
}

// ── Widget interne pour les data URIs base64 ──────────────────────────────
class _Base64Image extends StatelessWidget {
  final String dataUri;
  final BoxFit fit;
  final Color bg;
  final double iconSize;

  const _Base64Image({
    required this.dataUri,
    required this.fit,
    required this.bg,
    required this.iconSize,
  });

  Uint8List? _decode() {
    try {
      final comma = dataUri.indexOf(',');
      if (comma == -1) return null;
      final b64 = dataUri.substring(comma + 1);
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decode();
    if (bytes == null) {
      return Container(
        color: bg,
        child: Center(child: Icon(Icons.restaurant, color: AppTheme.primary, size: iconSize)),
      );
    }
    return Image.memory(bytes, fit: fit, gaplessPlayback: true);
  }
}

/// Version carrée avec coins arrondis uniformes — pour les petites cartes
class ProductImageSmall extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double radius;

  const ProductImageSmall({
    super.key,
    required this.imageUrl,
    this.size = 60,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ProductImage(
      imageUrl: imageUrl,
      height: size,
      width: size,
      borderRadius: BorderRadius.circular(radius),
      iconSize: size * 0.45,
    );
  }
}
