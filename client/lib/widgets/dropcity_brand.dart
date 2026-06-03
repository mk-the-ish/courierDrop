import "package:flutter/material.dart";

import "../theme.dart";

class DropCityLogoMark extends StatelessWidget {
  const DropCityLogoMark({
    super.key,
    this.size = 96,
    this.light = true,
  });

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        "assets/images/logo.png",
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class DropCityWordmark extends StatelessWidget {
  const DropCityWordmark({
    super.key,
    this.logoSize = 72,
    this.textColor = dropCitySafeSlate,
    this.subtitle = false,
  });

  final double logoSize;
  final Color textColor;
  final bool subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropCityLogoMark(size: logoSize, light: textColor == dropCityCloudWhite),
        const SizedBox(height: 12),
        Text(
          "DropCity",
          style: TextStyle(
            color: textColor,
            fontSize: logoSize > 80 ? 32 : 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        if (subtitle) ...[
          const SizedBox(height: 4),
          const Text(
            "Peer-to-Peer Logistics",
            style: TextStyle(
              color: dropCitySlateGrey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class DropCityPrimaryButton extends StatelessWidget {
  const DropCityPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon ?? Icons.arrow_forward),
        label: Text(loading ? "Please wait..." : label),
      ),
    );
  }
}

class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.activeIndex,
    required this.count,
  });

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? dropCityTransitTeal : dropCitySlateGrey.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}


