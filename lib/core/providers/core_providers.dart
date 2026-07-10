import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Theme mode provider (persisted to Hive later)
final themeModeProvider = StateProvider<String>((ref) => 'dark');

// Connectivity
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.valueOrNull?.contains(ConnectivityResult.wifi) == true ||
      connectivity.valueOrNull?.contains(ConnectivityResult.mobile) == true;
});
