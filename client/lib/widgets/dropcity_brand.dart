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
      child: CustomPaint(
        painter: _DropCityLogoPainter(light: light),
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

class _DropCityLogoPainter extends CustomPainter {
  const _DropCityLogoPainter({required this.light});

  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final spinePaint = Paint()
      ..color = light ? dropCityCloudWhite : dropCitySafeSlate
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;
    final ribbonPaint = Paint()
      ..color = dropCityTransitTeal
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final pinPaint = Paint()..color = dropCityAlertAmber;
    final centerX = size.width / 2;

    canvas.drawLine(
      Offset(centerX, size.height * 0.18),
      Offset(centerX, size.height * 0.82),
      spinePaint,
    );

    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.20)
      ..cubicTo(
        size.width * 0.84,
        size.height * 0.20,
        size.width * 0.18,
        size.height * 0.80,
        size.width * 0.72,
        size.height * 0.80,
      );
    canvas.drawPath(path, ribbonPaint);

    final pinCenter = Offset(centerX, size.height * 0.50);
    canvas.drawCircle(pinCenter, size.width * 0.13, pinPaint);
    canvas.drawCircle(pinCenter, size.width * 0.045, Paint()..color = Colors.white);
    final tipPath = Path()
      ..moveTo(centerX, size.height * 0.72)
      ..lineTo(size.width * 0.42, size.height * 0.58)
      ..lineTo(size.width * 0.58, size.height * 0.58)
      ..close();
    canvas.drawPath(tipPath, pinPaint);
  }

  @override
  bool shouldRepaint(covariant _DropCityLogoPainter oldDelegate) {
    return oldDelegate.light != light;
  }
}


