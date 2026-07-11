/// Smooths edge flickering in audio word sync by adding 
/// a small hysteresis window around word boundaries.
class TimestampSmoother {
  final Duration hysteresis;
  String? _lastId;
  DateTime? _lastSwitchTime;

  TimestampSmoother({this.hysteresis = const Duration(milliseconds: 60)});

  String? smooth(String? newId) {
    final now = DateTime.now();
    if (_lastId == null || newId == _lastId) {
      _lastId = newId;
      _lastSwitchTime = now;
      return newId;
    }
    if (_lastSwitchTime != null) {
      final elapsed = now.difference(_lastSwitchTime!);
      if (elapsed < hysteresis) return _lastId;
    }
    _lastId = newId;
    _lastSwitchTime = now;
    return newId;
  }

  void reset() {
    _lastId = null;
    _lastSwitchTime = null;
  }
}
