import 'package:flutter_riverpod/flutter_riverpod.dart';

// Navigation index provider: 0: Timer, 1: Activities, 2: Reports, 3: Settings
final navigationProvider = StateProvider<int>((ref) => 0);
