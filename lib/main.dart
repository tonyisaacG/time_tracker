import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_time/core/theme/app_theme.dart';
import 'package:tracker_time/core/utils/device_id.dart';
import 'package:tracker_time/core/providers/navigation_provider.dart';
import 'package:tracker_time/features/session/presentation/timer_dashboard.dart';
import 'package:tracker_time/features/activity/presentation/activity_manage_screen.dart';
import 'package:tracker_time/features/report/presentation/report_screen.dart';
import 'package:tracker_time/features/settings/presentation/settings_screen.dart';
import 'package:tracker_time/features/activity/application/activity_providers.dart';
import 'package:tracker_time/core/db/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Eagerly initialize device ID on launch
  await DeviceIdUtil.getOrCreateDeviceId();

  final container = ProviderContainer();
  // Check and insert preset activities
  await _prepopulatePresetActivities(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TimeInvestmentTrackerApp(),
    ),
  );
}

Future<void> _prepopulatePresetActivities(ProviderContainer container) async {
  final repo = container.read(activityRepositoryProvider);

  // Ensure Unassigned Free Session activity always exists
  try {
    final freeSessionAct = await repo.getActivityById('preset-free-session');
    if (freeSessionAct == null) {
      await repo.insertActivity(
        Activity(
          id: 'preset-free-session',
          name: 'جلسة حرة (Unassigned)',
          color: const Color(0xff6b7280).value,
          icon: 'star',
          weeklyGoalMinutes: null,
          isLimit: false,
          enforceLimit: false,
          isWeeklyFocus: false,
          isArchived: false,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
  } catch (_) {}

  final current = await repo.watchActiveActivities().first;
  if (current.isEmpty) {
    final presets = [
      Activity(
        id: 'preset-reading',
        name: 'القراءة',
        color: const Color(0xff8b5cf6).value,
        icon: 'reading_deep',
        weeklyGoalMinutes: 180, // 3 hours
        isLimit: false,
        enforceLimit: false,
        isWeeklyFocus: true,
        isArchived: false,
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Activity(
        id: 'preset-programming',
        name: 'البرمجة',
        color: const Color(0xff3b82f6).value,
        icon: 'programming_computer',
        weeklyGoalMinutes: 600, // 10 hours
        isLimit: false,
        enforceLimit: false,
        isWeeklyFocus: true,
        isArchived: false,
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Activity(
        id: 'preset-english',
        name: 'الإنجليزية',
        color: const Color(0xff10b981).value,
        icon: 'language',
        weeklyGoalMinutes: 300, // 5 hours
        isLimit: false,
        enforceLimit: false,
        isWeeklyFocus: true,
        isArchived: false,
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Activity(
        id: 'preset-exercise',
        name: 'الرياضة',
        color: const Color(0xff06b6d4).value,
        icon: 'exercise',
        weeklyGoalMinutes: 180, // 3 hours
        isLimit: false,
        enforceLimit: false,
        isWeeklyFocus: true,
        isArchived: false,
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Activity(
        id: 'preset-social',
        name: 'مواقع التواصل',
        color: const Color(0xffef4444).value,
        icon: 'mobile_phone',
        weeklyGoalMinutes: 180, // 3 hours limit
        isLimit: true,
        enforceLimit: false,
        isWeeklyFocus: true,
        isArchived: false,
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Activity(
        id: 'preset-rest',
        name: 'راحة واسترخاء',
        color: const Color(0xfff59e0b).value,
        icon: 'sitting_relax',
        weeklyGoalMinutes: null,
        isLimit: false,
        enforceLimit: false,
        isWeeklyFocus: false,
        isArchived: false,
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final act in presets) {
      await repo.insertActivity(act);
    }
  }
}

class TimeInvestmentTrackerApp extends StatelessWidget {
  const TimeInvestmentTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Investment Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Premium Dark Theme by default
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  static const List<Widget> _screens = [
    TimerDashboard(),
    ActivityManageScreen(),
    ReportScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationProvider);
    // Determine screen size for responsiveness
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 640;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop) ...[
            NavigationRail(
              extended: width >= 900,
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                ref.read(navigationProvider.notifier).state = index;
              },
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Hero(
                  tag: 'logo',
                  child: Icon(
                    Icons.hourglass_empty_rounded,
                    color: AppTheme.primaryGlow,
                    size: width >= 900 ? 32 : 28,
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.timer_outlined),
                  selectedIcon: Icon(Icons.timer_rounded),
                  label: Text('Timer'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category_rounded),
                  label: Text('Activities'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: Text('Reports'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1, color: AppTheme.border),
          ],
          Expanded(
            child: _screens[currentIndex],
          ),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                ref.read(navigationProvider.notifier).state = index;
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.timer_outlined),
                  selectedIcon: Icon(Icons.timer_rounded),
                  label: 'Timer',
                ),
                NavigationDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category_rounded),
                  label: 'Activities',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: 'Reports',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            )
          : null,
    );
  }
}
