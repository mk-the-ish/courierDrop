import "package:flutter/material.dart";
import 'dart:io';

import "../theme.dart";

class DropCityLogoMark extends StatelessWidget {
  const DropCityLogoMark({super.key, this.size = 96, this.light = false});

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: light ? Colors.white : null,
        colorBlendMode: light ? BlendMode.srcIn : null,
      ),
    );
  }
}

class CourierPrimaryButton extends StatelessWidget {
  const CourierPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon = Icons.arrow_forward,
    this.backgroundColor = dropCityTransitTeal,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData icon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: backgroundColor),
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(loading ? "Please wait..." : label),
      ),
    );
  }
}

class CourierStepBar extends StatelessWidget {
  const CourierStepBar({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final active = index < step;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 5,
            margin: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: active ? dropCityTransitTeal : dropCitySlateGrey.withOpacity(0.28),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class DashedUploadBox extends StatelessWidget {
  const DashedUploadBox({
    super.key,
    required this.label,
    this.height = 120,
    this.icon = Icons.camera_alt_outlined,
    this.onTap,
    this.hasImage = false,
    this.imagePath,
  });

  final String label;
  final double height;
  final IconData icon;
  final VoidCallback? onTap;
  final bool hasImage;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: hasImage ? dropCityActiveMint.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage ? dropCityActiveMint : dropCitySlateGrey.withOpacity(0.55),
            width: 1.4,
            style: BorderStyle.solid,
          ),
        ),
        child: Stack(
          children: [
            if (hasImage && imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(imagePath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Failed to load image",
                            style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasImage ? Icons.check_circle : icon,
                      color: hasImage ? dropCityActiveMint : dropCityTransitTeal,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasImage ? "$label uploaded" : label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: dropCitySafeSlate,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (hasImage)
              const Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: dropCitySafeSlate,
                  child: Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Old custom painter removed — using asset image `assets/images/logo.png` instead.
