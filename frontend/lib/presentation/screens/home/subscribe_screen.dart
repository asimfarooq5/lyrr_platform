/// Subscribe Screen
/// 
/// Choose a plan, pick a payment method (Card / Orange Money / MTN MoMo),
/// and complete the checkout (FRS §10)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/payment_model.dart';
import '../../theme/app_theme.dart';

class SubscribeScreen extends ConsumerStatefulWidget {
  const SubscribeScreen({super.key});

  @override
  ConsumerState<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends ConsumerState<SubscribeScreen> {
  List<SubscriptionPlanModel> _plans = [];
  List<PaymentMethodModel> _methods = [];
  SubscriptionPlanModel? _selectedPlan;
  PaymentMethodModel? _selectedMethod;
  final _phoneController = TextEditingController();
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(paymentsRepositoryProvider);
      final plans = await repo.getSubscriptionPlans();
      final methods = await repo.getPaymentMethods();
      setState(() {
        _plans = plans;
        _methods = methods;
        _selectedPlan = plans.isNotEmpty ? plans.first : null;
        _selectedMethod = methods.isNotEmpty ? methods.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load plans. Is the backend running?';
        _isLoading = false;
      });
    }
  }

  Future<void> _subscribe() async {
    if (_selectedPlan == null) {
      _showMessage('Please select a plan');
      return;
    }
    if (_selectedMethod == null) {
      _showMessage('Please select a payment method');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final repo = ref.read(paymentsRepositoryProvider);
      final method = _selectedMethod!;
      final phone = method.requiresPhone
          ? _phoneController.text.trim()
          : null;

      if (method.requiresPhone && (phone == null || phone.isEmpty)) {
        setState(() => _isProcessing = false);
        _showMessage('Enter your mobile money phone number');
        return;
      }

      final payment = await repo.checkout(
        method: method.id,
        itemType: 'subscription',
        planId: _selectedPlan!.id,
        phone: phone,
      );

      // Mobile money needs confirmation; card settles automatically.
      if (payment.isPending) {
        final confirmed = await _confirmDialog(payment);
        if (confirmed == true) {
          final result = await repo.confirmPayment(payment.id);
          _showMessage(
            result.isCompleted
                ? 'Subscription activated! Welcome to LYRR Premium.'
                : 'Payment status: ${result.statusLabel}',
            success: result.isCompleted,
          );
        }
      } else {
        _showMessage('Subscription activated! Welcome to LYRR Premium.',
            success: true);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<bool?> _confirmDialog(PaymentModel payment) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm payment'),
        content: Text(
          '${payment.methodLabel} payment of ${payment.amount.toStringAsFixed(0)} '
          '${payment.currency} is awaiting your approval.\n\n'
          'In production you would approve it on your phone. '
          'Confirm to complete (sandbox mode).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppColors.success : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('LYRR Premium')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _plans.isEmpty
              ? _buildError(theme)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unlimited reading & listening',
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        'Subscribe to access the entire library with synchronized '
                        'audio on every book.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),

                      // Plans
                      Text('Choose a plan', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      ..._plans.map(_buildPlanCard),
                      const SizedBox(height: 24),

                      // Payment method
                      Text('Payment method', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      ..._methods.map(_buildMethodTile),
                      const SizedBox(height: 16),

                      // Phone (mobile money only)
                      if (_selectedMethod?.requiresPhone == true) ...[
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile money number',
                            hintText: '+2376XXXXXXXX',
                            prefixIcon: Icon(Icons.phone_android),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_error!,
                              style: const TextStyle(color: AppColors.error)),
                        ),
                        const SizedBox(height: 16),
                      ],

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _subscribe,
                          child: _isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Subscribe'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Not now'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error ?? 'Failed to load plans',
                textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlanModel plan) {
    final selected = _selectedPlan?.id == plan.id;
    final isAnnual = plan.interval == 'annual';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: () => setState(() => _selectedPlan = plan),
        contentPadding: const EdgeInsets.all(16),
        title: Text(plan.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(plan.description ?? ''),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(plan.priceLabel,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text('/${plan.intervalLabel}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        leading: Icon(
          isAnnual ? Icons.workspace_premium : Icons.star,
          color: isAnnual ? AppColors.secondary : AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildMethodTile(PaymentMethodModel method) {
    final selected = _selectedMethod?.id == method.id;
    final IconData icon = switch (method.id) {
      'card' => Icons.credit_card,
      'orange_money' => Icons.phone_iphone,
      'mtn_momo' => Icons.phone_android,
      _ => Icons.payment,
    };

    return RadioListTile<PaymentMethodModel>(
      value: method,
      groupValue: _selectedMethod,
      onChanged: (m) => setState(() => _selectedMethod = m),
      title: Text(method.name),
      secondary: Icon(icon, color: AppColors.primary),
    );
  }
}
