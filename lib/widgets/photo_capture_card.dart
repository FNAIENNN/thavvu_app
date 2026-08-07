import 'dart:io';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PhotoCaptureCard extends StatelessWidget {
  final String label;
  final String hint;
  final bool mandatory;
  final VoidCallback? onTap;
  final String? imagePath;
  final VoidCallback? onClear;

  const PhotoCaptureCard({
    super.key,
    required this.label,
    this.hint = 'Tap to capture',
    this.mandatory = false,
    this.onTap,
    this.imagePath,
    this.onClear,
  });

  bool get _hasImage => imagePath != null && imagePath!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _hasImage ? AppTheme.successBg : AppTheme.infoBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (_hasImage ? AppTheme.success : AppTheme.info).withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            _buildThumb(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hasImage
                        ? 'Photo attached · tap to retake'
                        : (mandatory ? '$hint (Required)' : hint),
                    style: TextStyle(
                      fontSize: 11,
                      color: _hasImage ? AppTheme.success : AppTheme.info,
                    ),
                  ),
                ],
              ),
            ),
            if (_hasImage && onClear != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                onPressed: onClear,
                tooltip: 'Remove photo',
              )
            else
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb() {
    if (_hasImage) {
      final file = File(imagePath!);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          color: AppTheme.success.withOpacity(0.15),
          child: file.existsSync()
              ? Image.file(file, fit: BoxFit.cover)
              : const Icon(Icons.image, color: AppTheme.success),
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.info.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Text('📷', style: TextStyle(fontSize: 22)),
    );
  }
}
