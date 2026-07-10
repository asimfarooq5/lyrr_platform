extension DurationFormatting on Duration {
  /// Formats the duration as hh:mm:ss or mm:ss
  String toFormattedString() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hoursStr = hours.toString();
      return '$hoursStr:$minutesStr:$secondsStr';
    } else {
      return '$minutesStr:$secondsStr';
    }
  }
}

extension DoubleFormatting on double {
  /// Formats seconds as hh:mm:ss or mm:ss
  String toFormattedString() {
    return Duration(milliseconds: (this * 1000).round()).toFormattedString();
  }
}
