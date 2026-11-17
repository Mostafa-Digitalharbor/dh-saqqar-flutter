import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_names.dart';
import '../../shared/fig/fig.dart';
import 'onboarding_flag.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_sizes.dart';

/// First-run welcome: gradient backdrop, the "+3.28% / +12.76%" growth line,
/// the big three-line promise and the Get started pill.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.onStart});

  /// Overrides the default navigation (tests).
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: figLightStatusBar,
      child: Scaffold(
        backgroundColor: Fig.pageGrey,
        body: FigBackdrop(
          child: Stack(
            children: [
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 340,
                child: _GrowthLine(),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: box.maxHeight - 14,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.figConnectNaskGetNitDone,
                            style: Fig.t(
                              context,
                              size: box.maxHeight < 700 ? 48 : 66,
                              color: Fig.inkDeep,
                              height: 1.04,
                              letterSpacing: -1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s18),
                          Text(
                            context.tr.figSaqqarUnderstandsYourOdooBusinessData,
                            style: Fig.t(
                              context,
                              size: 14,
                              color: const Color(0xFF3D4054),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s28),
                          FigButton(
                            label: context.tr.figGetStarted,
                            height: 57,
                            fontSize: 17,
                            weight: FontWeight.w500,
                            onPressed:
                                onStart ??
                                () async {
                                  await OnboardingFlag.markSeen();
                                  if (context.mounted) {
                                    context.go(RouteNames.signUpPath);
                                  }
                                },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrowthLine extends StatelessWidget {
  const _GrowthLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final k = c.maxWidth / 375;
        Offset p(double x, double y) => Offset(x * k, y);
        Widget chip(String text, double x, double y, double w) => Positioned(
          left: x * k,
          top: y,
          child: Container(
            width: w * k,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2F5FEA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              text,
              textDirection: TextDirection.ltr,
              style: Fig.t(context, size: 12, color: Colors.white),
            ),
          ),
        );
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CurvePainter(
                  points: [
                    p(-10, 180),
                    p(30, 160),
                    p(57, 172),
                    p(100, 245),
                    p(150, 292),
                    p(190, 290),
                    p(222, 262),
                    p(253, 235),
                    p(290, 190),
                    p(328, 148),
                  ],
                  dots: [p(57, 172), p(253, 235)],
                  tip: p(328, 148),
                ),
              ),
            ),
            chip('+3.28%', 71, 119, 70),
            chip('+12.76%', 275, 238, 73),
          ],
        );
      },
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.points, required this.dots, required this.tip});

  final List<Offset> points;
  final List<Offset> dots;
  final Offset tip;

  @override
  void paint(Canvas canvas, Size size) {
    // Catmull-Rom → cubic Béziers through [points].
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, line);
    final head = Path()
      ..moveTo(tip.dx - 26, tip.dy + 4)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 3, tip.dy + 28);
    canvas.drawPath(head, line..strokeJoin = StrokeJoin.round);
    for (final d in dots) {
      canvas.drawCircle(
        d,
        14,
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
      canvas.drawCircle(d, 7.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => false;
}
