import "package:flutter/material.dart";

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
      child: CustomPaint(painter: _LogoPainter(light: light)),
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
  });

  final String label;
  final double height;
  final IconData icon;
  final VoidCallback? onTap;
  final bool hasImage;

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

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.light});

  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final spinePaint = Paint()
      ..color = light ? dropCityCloudWhite : dropCitySafeSlate
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;
    final ribbonPaint = Paint()
      ..color = dropCityTransitTeal
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(centerX, size.height * 0.18),
      Offset(centerX, size.height * 0.82),
      spinePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.28, size.height * 0.20)
        ..cubicTo(
          size.width * 0.84,
          size.height * 0.20,
          size.width * 0.18,
          size.height * 0.80,
          size.width * 0.72,
          size.height * 0.80,
        ),
      ribbonPaint,
    );

    final pinPaint = Paint()..color = dropCityAlertAmber;
    final pinCenter = Offset(centerX, size.height * 0.50);
    canvas.drawCircle(pinCenter, size.width * 0.13, pinPaint);
    canvas.drawCircle(pinCenter, size.width * 0.045, Paint()..color = Colors.white);
    canvas.drawPath(
      Path()
        ..moveTo(centerX, size.height * 0.72)
        ..lineTo(size.width * 0.42, size.height * 0.58)
        ..lineTo(size.width * 0.58, size.height * 0.58)
        ..close(),
      pinPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => oldDelegate.light != light;
}
