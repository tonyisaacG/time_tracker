import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import 'package:tracker_time/features/report/application/report_service.dart';
import 'package:tracker_time/features/report/domain/report_models.dart';

class ActivityInsightsCard extends ConsumerWidget {
  final DateTime reportDate;
  final PeriodType periodType;

  const ActivityInsightsCard({
    super.key,
    required this.reportDate,
    required this.periodType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activeActivitiesProvider);

    final AsyncValue<ReportData> currentReportAsync;
    switch (periodType) {
      case PeriodType.daily:
        currentReportAsync = ref.watch(dailyReportProvider);
        break;
      case PeriodType.weekly:
        currentReportAsync = ref.watch(weeklyReportProvider);
        break;
      case PeriodType.monthly:
        currentReportAsync = ref.watch(monthlyReportProvider);
        break;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_rounded, color: AppTheme.primaryGlow, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'ACTIVITY INSIGHTS & TRENDS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            activitiesAsync.when(
              data: (activities) {
                if (activities.isEmpty) {
                  return const Text('No active activities registered', style: TextStyle(fontSize: 12, color: AppTheme.textMuted));
                }

                final currentReport = currentReportAsync.valueOrNull;

                final currentMap = <String, int>{
                  if (currentReport != null)
                    for (final item in currentReport.items) item.activity.id: item.totalMinutes
                };

                return Column(
                  children: activities.map((act) {
                    final currMins = currentMap[act.id] ?? 0;
                    final currHours = currMins / 60.0;

                    final actColor = Color(act.color);
                    final iconData = AppTheme.activityIcons[act.icon] ?? Icons.category_rounded;

                    // Goal target (weekly target goal or estimated)
                    final targetMins = act.weeklyGoalMinutes ?? 600; // default 10h if not set
                    final targetHours = targetMins / 60.0;
                    final progress = (currHours / targetHours).clamp(0.0, 1.0);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(iconData, color: actColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  act.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: actColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${(progress * 100).toStringAsFixed(0)}% Target',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: actColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${currHours.toStringAsFixed(1)} / ${targetHours.toStringAsFixed(0)}h Goal',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: actColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: actColor.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(actColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGlow)),
              error: (err, _) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
