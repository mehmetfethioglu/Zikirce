import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ImageLightboxModal {
  const ImageLightboxModal._();

  static void show(
    BuildContext context, {
    required String imageSource,
    String? caption,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) {
        ImageProvider provider;
        if (imageSource.startsWith('http')) {
          provider = NetworkImage(imageSource);
        } else if (File(imageSource).existsSync()) {
          provider = FileImage(File(imageSource));
        } else {
          provider = const AssetImage('assets/images/sample_illustration.png');
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: PhotoView(
                  imageProvider: provider,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3.5,
                  backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                          const SizedBox(height: 12),
                          const Text(
                            'Görsel yüklenemedi',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 48,
                right: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
              if (caption != null && caption.isNotEmpty)
                Positioned(
                  bottom: 40,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
