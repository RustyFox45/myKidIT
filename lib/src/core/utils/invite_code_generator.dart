import 'dart:math';
import 'package:intl/intl.dart';

/// Utilities for generating household pairing codes and formatting dates.
class AppFormatters {
  const AppFormatters._();

  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _random = Random();

  /// Generates a readable 6-character alphanumeric pairing code (e.g. `K7M4P9`).
  static String generateInviteCode({int length = 6}) {
    return List.generate(
      length,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
  }

  static String formatTimeWindow(DateTime start, DateTime end) {
    final dayFmt = DateFormat('EEE, MMM d');
    final timeFmt = DateFormat('h:mm a');
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;

    if (sameDay) {
      return '${dayFmt.format(start)} • ${timeFmt.format(start)} – ${timeFmt.format(end)}';
    }
    return '${dayFmt.format(start)} ${timeFmt.format(start)} – ${dayFmt.format(end)} ${timeFmt.format(end)}';
  }

  static String formatShortDateTime(DateTime dateTime) {
    return DateFormat('MMM d, h:mm a').format(dateTime);
  }
}

