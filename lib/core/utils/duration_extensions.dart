extension DurationFormatting on Duration {
  String toFormattedString() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString()}:$minutesStr:$secondsStr';
    }
    return '$minutesStr:$secondsStr';
  }
}

extension DoubleFormatting on double {
  String toFormattedString() {
    return Duration(milliseconds: (this * 1000).round()).toFormattedString();
  }
}
