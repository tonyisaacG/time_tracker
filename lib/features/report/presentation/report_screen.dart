import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/db/database.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import '../application/report_service.dart';
import '../domain/report_models.dart';
import 'widgets/custom_charts.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  PeriodType _selectedPeriod = PeriodType.weekly;

  String _getPeriodLabel(DateTime date, PeriodType type) {
    if (type == PeriodType.daily) {
      return DateFormat('EEEE, MMMM d, y').format(date);
    } else if (type == PeriodType.weekly) {
      final daysToSubtract = date.weekday - 1;
      final monday = date.subtract(Duration(days: daysToSubtract));
      final sunday = monday.add(const Duration(days: 6));
      return '${DateFormat('MMM d').format(monday)} - ${DateFormat('MMM d, y').format(sunday)}';
    } else {
      return DateFormat('MMMM yyyy').format(date);
    }
  }

  void _adjustDate(int amount) {
    final currentDate = ref.read(reportDateProvider);
    DateTime newDate;
    if (_selectedPeriod == PeriodType.daily) {
      newDate = currentDate.add(Duration(days: amount));
    } else if (_selectedPeriod == PeriodType.weekly) {
      newDate = currentDate.add(Duration(days: amount * 7));
    } else {
      // Shifting calendar month
      newDate = DateTime(currentDate.year, currentDate.month + amount, 1);
    }
    ref.read(reportDateProvider.notifier).state = newDate;
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(reportDateProvider);
    final allActivities = ref.watch(allActivitiesProvider).valueOrNull ?? [];
    final Map<String, Activity> activitiesMap = {
      for (final a in allActivities) a.id: a,
    };

    AsyncValue<ReportData> reportAsync;
    if (_selectedPeriod == PeriodType.daily) {
      reportAsync = ref.watch(dailyReportProvider);
    } else if (_selectedPeriod == PeriodType.weekly) {
      reportAsync = ref.watch(weeklyReportProvider);
    } else {
      reportAsync = ref.watch(monthlyReportProvider);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Reports'),
            floating: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPeriodTab(PeriodType.daily, 'Day'),
                    const SizedBox(width: 8),
                    _buildPeriodTab(PeriodType.weekly, 'Week'),
                    const SizedBox(width: 8),
                    _buildPeriodTab(PeriodType.monthly, 'Month'),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  // Period Navigation Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimary),
                        onPressed: () => _adjustDate(-1),
                      ),
                      Text(
                        _getPeriodLabel(date, _selectedPeriod),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimary),
                        onPressed: () => _adjustDate(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  reportAsync.when(
                    data: (report) {
                      final durationByActivity = <String, int>{
                        for (final item in report.items) item.activity.id: item.totalMinutes,
                      };

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary metrics cards
                          _buildOverallSummaryCard(report),
                          const SizedBox(height: 16),
                          _buildTimeAccountabilityCard(report),
                          const SizedBox(height: 16),

                          // Weekly trend chart (Only show for Weekly periods)
                          if (_selectedPeriod == PeriodType.weekly) ...[
                            _buildSectionHeader('Weekly Trend'),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 12),
                                    WeeklyBarChart(
                                      timeByDay: report.timeBySubPeriod,
                                      barColor: AppTheme.primary,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Distribution chart
                          if (report.totalMinutes > 0) ...[
                            _buildSectionHeader('Category Distribution'),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: ActivityDonutChart(
                                  durationByActivity: durationByActivity,
                                  activitiesMap: activitiesMap,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Goals Progress section (Only relevant if we have goals listed)
                          if (report.items.isNotEmpty) ...[
                            _buildSectionHeader('Activity Breakdown'),
                            Column(
                              children: report.items.map((item) {
                                return _buildActivityProgressTile(item);
                              }).toList(),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(64.0),
                        child: CircularProgressIndicator(color: AppTheme.primaryGlow),
                      ),
                    ),
                    error: (err, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text('Error: $err', style: const TextStyle(color: Color(0xffef4444))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAccountabilityCard(ReportData report) {
    int totalPeriodMinutes;
    if (_selectedPeriod == PeriodType.daily) {
      totalPeriodMinutes = 24 * 60;
    } else if (_selectedPeriod == PeriodType.weekly) {
      totalPeriodMinutes = 7 * 24 * 60;
    } else {
      final date = ref.watch(reportDateProvider);
      final days = DateTime(date.year, date.month + 1, 0).day;
      totalPeriodMinutes = days * 24 * 60;
    }

    final trackedMinutes = report.totalMinutes;
    final untrackedMinutes = totalPeriodMinutes - trackedMinutes > 0
        ? totalPeriodMinutes - trackedMinutes
        : 0;

    final trackedHrs = (trackedMinutes / 60.0).toStringAsFixed(1);
    final untrackedHrs = (untrackedMinutes / 60.0).toStringAsFixed(1);

    final double trackedPercent = totalPeriodMinutes > 0
        ? (trackedMinutes / totalPeriodMinutes) * 100
        : 0.0;
    final double untrackedPercent = 100.0 - trackedPercent;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: AppTheme.primaryGlow, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'TIME ACCOUNTABILITY',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tracked Time',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${trackedHrs}h (${trackedPercent.toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGlow,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Untracked / Wasted',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${untrackedHrs}h (${untrackedPercent.toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xfff59e0b),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (trackedMinutes > 0)
                      Expanded(
                        flex: trackedMinutes,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primaryGlow],
                            ),
                          ),
                        ),
                      ),
                    if (untrackedMinutes > 0)
                      Expanded(
                        flex: untrackedMinutes,
                        child: Container(
                          color: const Color(0xfff59e0b).withOpacity(0.3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trackedPercent < 15.0
                        ? 'Tip: You have a lot of untracked hours. Try using the quick start timer on the dashboard to log your sessions as they happen!'
                        : 'Great job! Keep logging your day to eliminate hidden time leaks and stay focused.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTab(PeriodType type, String label) {
    final isSelected = _selectedPeriod == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : AppTheme.border),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildOverallSummaryCard(ReportData report) {
    final hrs = (report.totalMinutes / 60.0).toStringAsFixed(1);
    final min = report.totalMinutes.toString();

    // Calculate overall weekly goals percentage if weekly
    double overallProgress = 0.0;
    int totalGoalMins = 0;
    int actualGoalMins = 0;

    if (_selectedPeriod == PeriodType.weekly) {
      for (final item in report.items) {
        final goal = item.activity.weeklyGoalMinutes;
        if (goal != null && goal > 0) {
          totalGoalMins += goal;
          actualGoalMins += item.totalMinutes > goal ? goal : item.totalMinutes;
        }
      }
      if (totalGoalMins > 0) {
        overallProgress = actualGoalMins / totalGoalMins;
      }
    }

    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [AppTheme.surface, AppTheme.surface.withBlue(45)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL TIME INVESTED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    textBaseline: TextBaseline.alphabetic,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    children: [
                      Text(
                        hrs,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'hours',
                        style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Equivalent to $min total minutes',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (_selectedPeriod == PeriodType.weekly && totalGoalMins > 0)
              GradientProgressRing(
                progress: overallProgress,
                baseColor: AppTheme.border,
                gradientColors: const [AppTheme.primaryGlow, AppTheme.primary],
                centerText: 'Goals',
                size: 90,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityProgressTile(ActivityReportItem item) {
    final activityColor = Color(item.activity.color);
    final iconData = AppTheme.activityIcons[item.activity.icon] ?? Icons.category_rounded;
    final double ratio = item.activity.weeklyGoalMinutes != null && item.activity.weeklyGoalMinutes! > 0
        ? (item.totalMinutes / item.activity.weeklyGoalMinutes!)
        : 0.0;
    final progressVal = ratio > 1.0 ? 1.0 : ratio;
    final percentString = (item.completionPercentage).toStringAsFixed(0);
    final hoursTracked = (item.totalMinutes / 60.0).toStringAsFixed(1);

    final isLimit = item.activity.isLimit;
    final hasGoal = item.activity.weeklyGoalMinutes != null && item.activity.weeklyGoalMinutes! > 0;

    String subLabelText = '';
    String statusText = '';
    Color statusColor = activityColor;
    Color barColor = activityColor;

    if (hasGoal) {
      final goalHours = (item.activity.weeklyGoalMinutes! / 60.0).toStringAsFixed(1);
      if (isLimit) {
        subLabelText = 'Weekly Limit: ${goalHours}h';
        final isExceeded = item.totalMinutes > item.activity.weeklyGoalMinutes!;
        if (isExceeded) {
          final overMins = item.totalMinutes - item.activity.weeklyGoalMinutes!;
          statusText = 'Limit Broken (+${(overMins / 60.0).toStringAsFixed(1)}h)';
          statusColor = const Color(0xffef4444); // Red/Coral
          barColor = const Color(0xffef4444);
        } else {
          statusText = '$percentString% Used';
          statusColor = const Color(0xff10b981); // Green/Emerald
          barColor = const Color(0xff10b981);
        }
      } else {
        subLabelText = 'Weekly Target: ${goalHours}h';
        statusText = '$percentString% Met';
        statusColor = activityColor;
        barColor = activityColor;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: activityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: activityColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.activity.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                Text(
                  '${hoursTracked}h total',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
              ],
            ),
            if (hasGoal) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    subLabelText,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressVal,
                  minHeight: 8,
                  backgroundColor: AppTheme.background,
                  color: barColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}



