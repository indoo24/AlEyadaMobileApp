// Al Eyada animated splash screen.
//
// Self-contained: only depends on the Flutter SDK (3.16 or newer).
//
// 1) Copy this file into lib/ (for example lib/splash/al_eyada_splash.dart).
//
// 2) Add the two Poppins font files to assets/fonts/ and register them in
//    pubspec.yaml:
//
//      flutter:
//        fonts:
//          - family: Poppins
//            fonts:
//              - asset: assets/fonts/Poppins-Regular.ttf
//              - asset: assets/fonts/Poppins-SemiBold.ttf
//                weight: 600
//
// 3) Show it as the first screen and move on when it finishes:
//
//      class SplashPage extends StatelessWidget {
//        const SplashPage({super.key});
//
//        @override
//        Widget build(BuildContext context) {
//          return AlEyadaSplash(
//            onFinished: () => Navigator.of(context).pushReplacement(
//              MaterialPageRoute(builder: (_) => const HomePage()),
//            ),
//          );
//        }
//      }
//
//      MaterialApp(home: const SplashPage());
//
// Timeline (seconds):
//   0.15 - 0.85  icon pops in
//   0.55 - 1.05  the two halves of the A slide together
//   1.00 - 1.90  heartbeat line draws left to right
//   1.90 - 2.85  double beat + ripple ring
//   2.00 - 2.82  "Al Eyada" rises letter by letter
//   2.60 - 3.20  tagline settles
// The background swirl keeps drifting for as long as the widget is on screen.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

// Brand colors sampled from the logo.
const Color _deep = Color(0xFF011A40);
const Color _navy = Color(0xFF022253);
const Color _blue = Color(0xFF03366B);
const Color _silver = Color(0xFFC3C3C5);
const Color _white = Color(0xFFFFFFFF);

const String _name = 'Al Eyada';
const String _tagline = 'Your Guide to Better Care';

/// Length of the intro sequence in seconds.
const double _totalSeconds = 3.2;

const Curve _overshoot = Cubic(0.2, 1.35, 0.4, 1.0);
const Curve _soft = Cubic(0.2, 0.8, 0.2, 1.0);
const Curve _drawCurve = Cubic(0.5, 0.0, 0.3, 1.0);

/// Progress (0..1) of a step that runs from [start] to [end] seconds.
double _step(
  double seconds,
  double start,
  double end, [
  Curve curve = Curves.linear,
]) {
  final double t = ((seconds - start) / (end - start)).clamp(0.0, 1.0).toDouble();
  return curve.transform(t);
}

class AlEyadaSplash extends StatefulWidget {
  const AlEyadaSplash({
    super.key,
    this.onFinished,
    this.hold = const Duration(milliseconds: 400),
  });

  /// Called once, after the intro has played and [hold] has passed.
  final VoidCallback? onFinished;

  /// How long the finished logo stays on screen before [onFinished] fires.
  final Duration hold;

  @override
  State<AlEyadaSplash> createState() => _AlEyadaSplashState();
}

class _AlEyadaSplashState extends State<AlEyadaSplash>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _drift;
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) _finish();
      });
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      // "Remove animations" is on in the system settings: show the final logo.
      _intro.value = 1.0;
      _finish();
    } else {
      _intro.forward();
      _drift.repeat(reverse: true);
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    Future<void>.delayed(widget.hold, () {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$_name. $_tagline',
      child: ExcludeSemantics(
        // The logo is Latin text: keep it left-to-right in an Arabic app.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: _navy,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Everything scales from the screen width, capped for tablets.
                final double w = math.min(constraints.maxWidth, 420.0);
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ClipRect(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: _SwirlPainter(_drift)),
                      ),
                    ),
                    Center(
                      child: AnimatedBuilder(
                        animation: _intro,
                        builder: (BuildContext context, Widget? child) {
                          return _Lockup(
                            seconds: _intro.value * _totalSeconds,
                            unit: w,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon, name and tagline stacked and centered.
class _Lockup extends StatelessWidget {
  const _Lockup({required this.seconds, required this.unit});

  final double seconds;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final double markWidth = unit * 0.42;
    final double nameSize = unit * 0.15;
    final double taglineSize = unit * 0.045;
    final double taglineT = _step(seconds, 2.6, 3.2, Curves.easeOut);

    final TextStyle nameStyle = TextStyle(
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w600,
      fontSize: nameSize,
      height: 1.1,
      letterSpacing: -0.01 * nameSize,
      color: _silver,
      decoration: TextDecoration.none,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: markWidth,
          height: markWidth * 900 / 910,
          child: CustomPaint(painter: _MarkPainter(seconds)),
        ),
        SizedBox(height: unit * 0.045),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < _name.length; i++)
              _RisingLetter(
                letter: _name[i],
                style: nameStyle,
                t: _step(seconds, 2.0 + i * 0.045, 2.5 + i * 0.045, _soft),
              ),
          ],
        ),
        SizedBox(height: unit * 0.012),
        Opacity(
          opacity: taglineT,
          child: Text(
            _tagline,
            maxLines: 1,
            softWrap: false,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w400,
              fontSize: taglineSize,
              letterSpacing: lerpDouble(0.32, 0.02, taglineT)! * taglineSize,
              color: _white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _RisingLetter extends StatelessWidget {
  const _RisingLetter({
    required this.letter,
    required this.style,
    required this.t,
  });

  final String letter;
  final TextStyle style;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: t.clamp(0.0, 1.0).toDouble(),
      child: Transform.translate(
        offset: Offset(0, (1 - t) * 0.45 * (style.fontSize ?? 0)),
        child: Text(letter, style: style, textScaler: TextScaler.noScaling),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The icon. Drawn in the logo's own 910 x 900 coordinate space (origin 42,45).
// ---------------------------------------------------------------------------

Path _poly(List<double> p, {bool close = false}) {
  final Path path = Path()..moveTo(p[0], p[1]);
  for (int i = 2; i < p.length; i += 2) {
    path.lineTo(p[i], p[i + 1]);
  }
  if (close) path.close();
  return path;
}

final RRect _tile = RRect.fromRectAndRadius(
  const Rect.fromLTWH(42, 45, 910, 900),
  const Radius.circular(150),
);

final Path _aTop = Path()
  ..moveTo(262, 522)
  ..lineTo(435, 150)
  ..cubicTo(448, 122, 470, 116, 492, 116)
  ..cubicTo(514, 116, 537, 122, 550, 150)
  ..lineTo(722, 522)
  ..lineTo(579, 522)
  ..lineTo(490, 330)
  ..lineTo(401, 522)
  ..close();

final Path _aBase = _poly(
  <double>[237, 578, 748, 578, 862, 825, 725, 825, 655, 675, 335, 675, 265, 825, 122, 825],
  close: true,
);

final Path _ecg = _poly(
  <double>[138, 550, 385, 550, 412, 605, 487, 402, 521, 712, 598, 482, 628, 550, 852, 550],
);

// Silver outline that separates the pulse from the navy A behind it.
final Path _ecgHalo = _poly(
  <double>[372, 550, 385, 550, 412, 605, 487, 402, 521, 712, 598, 482, 628, 550, 641, 550],
);

final Animatable<double> _beat = TweenSequence<double>(<TweenSequenceItem<double>>[
  TweenSequenceItem<double>(
    tween: Tween<double>(begin: 1.0, end: 1.075).chain(CurveTween(curve: Curves.easeInOut)),
    weight: 18,
  ),
  TweenSequenceItem<double>(
    tween: Tween<double>(begin: 1.075, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
    weight: 20,
  ),
  TweenSequenceItem<double>(
    tween: Tween<double>(begin: 1.0, end: 1.045).chain(CurveTween(curve: Curves.easeInOut)),
    weight: 18,
  ),
  TweenSequenceItem<double>(
    tween: Tween<double>(begin: 1.045, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
    weight: 22,
  ),
  TweenSequenceItem<double>(
    tween: ConstantTween<double>(1.0),
    weight: 22,
  ),
]);

void _scaleAbout(Canvas canvas, Offset center, double scale) {
  canvas
    ..translate(center.dx, center.dy)
    ..scale(scale, scale)
    ..translate(-center.dx, -center.dy);
}

/// The first [t] (0..1) of [source], measured along its length.
Path _trim(Path source, double t) {
  final Path out = Path();
  for (final metric in source.computeMetrics()) {
    out.addPath(metric.extractPath(0, metric.length * t), Offset.zero);
  }
  return out;
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.seconds);

  final double seconds;

  static const Offset _center = Offset(497, 495);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 910, size.width / 910);
    canvas.translate(-42, -45);

    // Double beat: the whole mark pulses twice.
    _scaleAbout(canvas, _center, _beat.transform(_step(seconds, 1.9, 2.6)));

    // Ripple ring, behind the tile.
    final double ripple = _step(seconds, 1.95, 2.85, Curves.easeOut);
    if (ripple > 0 && ripple < 1) {
      canvas.save();
      _scaleAbout(canvas, _center, 1 + 0.6 * ripple);
      canvas.drawRRect(
        _tile.deflate(9.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 19.5
          ..color = Color.fromRGBO(195, 195, 197, 0.55 * (1 - ripple)),
      );
      canvas.restore();
    }

    // Tile pops in, carrying everything drawn on it.
    if (seconds > 0.15) {
      final double pop = _step(seconds, 0.15, 0.85, _overshoot);
      final double alpha = pop.clamp(0.0, 1.0).toDouble();
      _scaleAbout(canvas, _center, 0.55 + 0.45 * pop);
      final bool fading = alpha < 1;
      if (fading) {
        canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      }

      canvas.drawRRect(_tile, Paint()..color = _silver);

      // The two halves of the A slide together.
      final double a = _step(seconds, 0.55, 1.05, _soft);
      if (a > 0) {
        final Paint navy = Paint()..color = Color.fromRGBO(2, 34, 83, a);
        canvas
          ..save()
          ..translate(0, -46 * (1 - a))
          ..drawPath(_aTop, navy)
          ..restore()
          ..save()
          ..translate(0, 46 * (1 - a))
          ..drawPath(_aBase, navy)
          ..restore();
      }

      // The heartbeat line draws itself.
      final double draw = _step(seconds, 1.0, 1.9, _drawCurve);
      if (draw > 0) {
        canvas.drawPath(
          _trim(_ecgHalo, draw),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 48
            ..strokeJoin = StrokeJoin.round
            ..color = _silver,
        );
        canvas.drawPath(
          _trim(_ecg, draw),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 21
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = _white,
        );
      }

      if (fading) canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.seconds != seconds;
}

// ---------------------------------------------------------------------------
// Background: soft blurred bands that drift slowly, like the logo artwork.
// ---------------------------------------------------------------------------

class _Blob {
  const _Blob(this.top, this.right, this.bottom, this.left, this.degrees, this.color, this.opacity);

  /// Insets as fractions of the (oversized) swirl box.
  final double top, right, bottom, left;
  final double degrees;
  final Color color;
  final double opacity;
}

const List<_Blob> _blobs = <_Blob>[
  _Blob(0.04, 0.30, 0.52, -0.08, -24, _deep, 1.0),
  _Blob(0.34, -0.06, 0.30, 0.22, -18, _blue, 0.85),
  _Blob(0.60, 0.26, 0.02, -0.04, 14, _deep, 1.0),
  _Blob(0.78, -0.10, -0.08, 0.40, -8, _blue, 0.9),
];

class _SwirlPainter extends CustomPainter {
  _SwirlPainter(this.drift) : super(repaint: drift);

  final Animation<double> drift;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = Curves.easeInOut.transform(drift.value);
    // The swirl is 60% larger than the screen so its edges never show.
    final Rect box = Rect.fromLTWH(
      -0.3 * size.width,
      -0.3 * size.height,
      1.6 * size.width,
      1.6 * size.height,
    );
    final MaskFilter blur = MaskFilter.blur(BlurStyle.normal, size.width * 0.1);

    canvas.save();
    canvas.translate(
      box.center.dx + lerpDouble(-0.03, 0.03, t)! * box.width,
      box.center.dy + lerpDouble(-0.02, 0.02, t)! * box.height,
    );
    canvas.rotate(lerpDouble(-3, 3, t)! * math.pi / 180);
    canvas.translate(-box.center.dx, -box.center.dy);

    for (final _Blob b in _blobs) {
      final Rect r = Rect.fromLTRB(
        box.left + b.left * box.width,
        box.top + b.top * box.height,
        box.right - b.right * box.width,
        box.bottom - b.bottom * box.height,
      );
      canvas
        ..save()
        ..translate(r.center.dx, r.center.dy)
        ..rotate(b.degrees * math.pi / 180)
        ..drawOval(
          Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height),
          Paint()
            ..maskFilter = blur
            ..color = b.color.withAlpha((b.opacity * 255).round()),
        )
        ..restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SwirlPainter oldDelegate) => oldDelegate.drift != drift;
}
