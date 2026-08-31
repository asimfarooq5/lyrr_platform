/// Payment History Screen
/// 
/// Shows the user's complete payment history (FRS §10)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/payment_model.dart';
import '../../theme/app_theme.dart';

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  List<PaymentModel> _payments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(paymentsRepositoryProvider);
      final payments = await repo.getPaymentHistory();
      setState(() {
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load payment history';
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String status) => switch (status) {
    'completed' => AppColors.success,
    'failed' || 'cancelled' || 'expired' => AppColors.error,
    _ => AppColors.accent,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _payments.isEmpty
                  ? const Center(child: Text('No payments yet'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _payments.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final p = _payments[index];
                          final date = p.createdAt != null
                              ? DateFormat('dd MMM yyyy, HH:mm').format(p.createdAt!)
                              : '';
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _statusColor(p.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                p.isCompleted
                                    ? Icons.check_circle
                                    : Icons.schedule,
                                color: _statusColor(p.status),
                              ),
                            ),
                            title: Text(
                              p.description ?? p.itemType ?? 'Payment',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${p.methodLabel} · $date\n${p.reference}',
                              maxLines: 2,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${p.amount.toStringAsFixed(p.amount % 1 == 0 ? 0 : 2)} ${p.currency}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(p.status)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    p.statusLabel,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _statusColor(p.status)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
