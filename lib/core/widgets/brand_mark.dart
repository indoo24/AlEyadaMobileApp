import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A placeholder brand mark, drawn from the design tokens.
///
/// The project ships no logo asset — `Frontend/public` holds only the Next.js
/// starter SVGs — so this is built from the palette rather than lifted from a
/// screenshot of the live site. It is technically valid for a launcher icon and
/// a splash, and it is deliberately simple: final store artwork is a design
/// deliverable, not something to improvise here. See the README.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AlEyada',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [AppColors.primary, AppColors.primaryHover],
          ),
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        // A medical cross, with the aperture that reads as the "ع" counter at
        // small sizes. Vector, so it scales to any launcher density.
        child: Center(
          child: SizedBox(
            width: size * 0.5,
            height: size * 0.5,
            child: CustomPaint(painter: _CrossPainter()),
          ),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final arm = size.width * 0.34;
    final r = Radius.circular(size.width * 0.1);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH((size.width - arm) / 2, 0, arm, size.height), r),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, (size.height - arm) / 2, size.width, arm), r),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
