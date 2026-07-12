import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';

// ----------------------------------------------------
// 1. GRADIENT PROGRESS RING
// ----------------------------------------------------
class GradientProgressRing extends StatefulWidget {
  final double progress; // Value between 0.0 and 1.0+
  final Color baseColor;
  final List<Color> gradientColors;
  final String centerText;
  final double size;

  const GradientProgressRing({
    super.key,
    required this.progress,
    required this.baseColor,
    required this.gradientColors,
    required this.centerText,
    this.size = 120,
  });

  @override
  State<GradientProgressRing> createState() => _GradientProgressRingState();
}

class _GradientProgressRingState extends State<GradientProgressRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant GradientProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(begin: _animation.value, end: widget.progress).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _ProgressRingPainter(
                  progress: _animation.value,
                  baseColor: widget.baseColor,
                  gradientColors: widget.gradientColors,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.centerText,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: widget.size * 0.16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${(widget.progress * 100).round()}%',
                    style: TextStyle(
                      color: widget.gradientColors.first,
                      fontSize: widget.size * 0.12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final List<Color> gradientColors;

  _ProgressRingPainter({
    required this.progress,
    required this.baseColor,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const strokeWidth = 10.0;

    // 1. Base Ring
    final basePaint = Paint()
      ..color = baseColor.withOpacity(0.08)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, basePaint);

    // 2. Glow ring (placed behind the main progress arc)
    final sweepAngle = 2 * pi * min(progress, 1.0);
    if (sweepAngle > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      
      final glowPaint = Paint()
        ..shader = SweepGradient(
          colors: gradientColors,
          startAngle: -pi / 2,
          endAngle: sweepAngle - pi / 2,
        ).createShader(rect)
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.save();
      // Rotate sweep gradient origin to start at the top (-90 degrees)
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-pi / 2);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawArc(rect, 0, sweepAngle, false, glowPaint);
      canvas.restore();

      // 3. Foreground Progress Arc
      final progressPaint = Paint()
        ..shader = SweepGradient(
          colors: gradientColors,
          startAngle: 0.0,
          endAngle: sweepAngle,
        ).createShader(rect)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-pi / 2);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawArc(rect, 0, sweepAngle, false, progressPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.gradientColors != gradientColors;
  }
}

// ----------------------------------------------------
// 2. WEEKLY BAR CHART
// ----------------------------------------------------
class WeeklyBarChart extends StatefulWidget {
  final Map<int, int> timeByDay; // 1 = Monday, 7 = Sunday -> value in minutes
  final Color barColor;

  const WeeklyBarChart({
    super.key,
    required this.timeByDay,
    required this.barColor,
  });

  @override
  State<WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<WeeklyBarChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 200),
          painter: _BarChartPainter(
            timeByDay: widget.timeByDay,
            scale: _scaleAnimation.value,
            barColor: widget.barColor,
          ),
        );
      },
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final Map<int, int> timeByDay;
  final double scale;
  final Color barColor;

  _BarChartPainter({
    required this.timeByDay,
    required this.scale,
    required this.barColor,
  });

  static const List<String> weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = timeByDay.values.isEmpty ? 0 : timeByDay.values.reduce(max);
    // Enforce a minimum scale divisor so we don't divide by zero
    final limit = maxVal > 0 ? maxVal : 60; 
    
    final chartHeight = size.height - 30; // Leave space for labels
    final barWidth = (size.width / 7) * 0.45;
    final spacing = (size.width - (barWidth * 7)) / 8;

    // Draw horizontal dashed grid lines
    final linePaint = Paint()
      ..color = AppTheme.border.withOpacity(0.4)
      ..strokeWidth = 1;
    
    // Draw 3 horizontal helper gridlines
    for (int i = 1; i <= 3; i++) {
      final y = chartHeight * (i / 4);
      canvas.drawLine(Offset(spacing, y), Offset(size.width - spacing, y), linePaint);
    }

    for (int i = 0; i < 7; i++) {
      final weekdayKey = i + 1; // 1 to 7
      final minutes = timeByDay[weekdayKey] ?? 0;
      final relativeHeight = (minutes / limit) * chartHeight * scale;

      // Draw Bar
      final x = spacing + (i * (barWidth + spacing));
      final y = chartHeight - relativeHeight;

      if (minutes > 0) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, relativeHeight),
          const Radius.circular(8),
        );

        final paint = Paint()
          ..shader = LinearGradient(
            colors: [barColor.withOpacity(0.5), barColor],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ).createShader(Rect.fromLTWH(x, y, barWidth, relativeHeight));

        canvas.drawRRect(rect, paint);
      } else {
        // Draw small dot placeholder
        final dotPaint = Paint()
          ..color = AppTheme.border.withOpacity(0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x + (barWidth / 2), chartHeight - 4), 3, dotPaint);
      }

      // Draw Labels
      final textPainter = TextPainter(
        text: TextSpan(
          text: weekdays[i],
          style: TextStyle(
            color: minutes > 0 ? AppTheme.textPrimary : AppTheme.textMuted,
            fontWeight: minutes > 0 ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(x + (barWidth / 2) - (textPainter.width / 2), chartHeight + 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.scale != scale || oldDelegate.timeByDay != timeByDay;
  }
}

// ----------------------------------------------------
// 3. ACTIVITY DONUT CHART
// ----------------------------------------------------
class ActivityDonutChart extends StatelessWidget {
  final Map<String, int> durationByActivity; // activityId -> minutes
  final Map<String, Activity> activitiesMap; // activityId -> Activity

  const ActivityDonutChart({
    super.key,
    required this.durationByActivity,
    required this.activitiesMap,
  });

  @override
  Widget build(BuildContext context) {
    final totalMins = durationByActivity.values.fold(0, (a, b) => a + b);

    if (totalMins == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No logged time for chart distribution',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final slices = <_DonutSlice>[];
    durationByActivity.forEach((activityId, minutes) {
      final act = activitiesMap[activityId];
      if (act != null) {
        slices.add(
          _DonutSlice(
            color: Color(act.color),
            minutes: minutes,
            percentage: minutes / totalMins,
            label: act.name,
          ),
        );
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(120, 120),
              painter: _DonutPainter(slices: slices),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: slices.map((s) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.label,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${s.minutes}m (${(s.percentage * 100).round()}%)',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DonutSlice {
  final Color color;
  final int minutes;
  final double percentage;
  final String label;

  _DonutSlice({
    required this.color,
    required this.minutes,
    required this.percentage,
    required this.label,
  });
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSlice> slices;

  _DonutPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 16.0;

    final rect = Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2));
    double startAngle = -pi / 2;

    for (final slice in slices) {
      final sweepAngle = 2 * pi * slice.percentage;

      final paint = Paint()
        ..color = slice.color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}
