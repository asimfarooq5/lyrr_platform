/// Sync Screen
///
/// Shows cloud sync status and lets the user trigger a manual sync.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/services/sync_service.dart';
import '../../theme/app_theme.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _isSyncing = false;

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    final service = ref.read(syncServiceProvider);
    await service.sync();
    if (mounted) setState(() => _isSyncing = false);
  }

  String _statusLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle: return 'Up to date';
      case SyncStatus.syncing: return 'Syncing…';
      case SyncStatus.error: return 'Sync failed — will retry automatically';
      case SyncStatus.offline: return 'Offline — will sync when connected';
    }
  }

  IconData _statusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle: return Icons.cloud_done_outlined;
      case SyncStatus.syncing: return Icons.cloud_sync_outlined;
      case SyncStatus.error: return Icons.cloud_off_outlined;
      case SyncStatus.offline: return Icons.wifi_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(syncStatusProvider);
    final status = statusAsync.value ?? SyncStatus.idle;

    return Scaffold(
      appBar: AppBar(title: const Text('Sync')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(_statusIcon(status), size: 32, color: AppColors.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cloud Sync', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(_statusLabel(status), style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bookmarks, notes, and reading progress sync automatically every '
            'few minutes and whenever you make a change. Use this to sync '
            'right now.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSyncing ? null : _syncNow,
            icon: _isSyncing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            label: Text(_isSyncing ? 'Syncing…' : 'Sync Now'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          ),
        ],
      ),
    );
  }
}
