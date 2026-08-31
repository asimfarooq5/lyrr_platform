/// Payment Models - subscriptions, checkout, payment history
/// 
/// Maps to backend /payments endpoints (FRS §10)

class SubscriptionPlanModel {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final String interval; // monthly, annual
  final bool isActive;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.currency = 'XAF',
    required this.interval,
    this.isActive = true,
  });

  String get intervalLabel =>
      interval == 'annual' ? 'year' : 'month';

  String get priceLabel =>
      '${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} $currency';

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlanModel(
        id: (json['id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        description: json['description'] as String?,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        currency: (json['currency'] ?? 'XAF') as String,
        interval: (json['interval'] ?? 'monthly') as String,
        isActive: (json['is_active'] ?? true) as bool,
      );
}

class PaymentMethodModel {
  final String id;
  final String name;
  final bool requiresPhone;

  PaymentMethodModel({
    required this.id,
    required this.name,
    this.requiresPhone = false,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) =>
      PaymentMethodModel(
        id: (json['id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        requiresPhone: (json['requires_phone'] ?? false) as bool,
      );
}

class PaymentModel {
  final String id;
  final double amount;
  final String currency;
  final String method; // card, orange_money, mtn_momo
  final String status; // pending, awaiting_confirmation, completed, failed...
  final String reference;
  final String? description;
  final String? itemType; // book, subscription
  final String? bookId;
  final String? planId;
  final String? gatewayReference;
  final DateTime? createdAt;
  final DateTime? completedAt;

  PaymentModel({
    required this.id,
    required this.amount,
    this.currency = 'XAF',
    required this.method,
    required this.status,
    required this.reference,
    this.description,
    this.itemType,
    this.bookId,
    this.planId,
    this.gatewayReference,
    this.createdAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending' || status == 'awaiting_confirmation';

  String get statusLabel => switch (status) {
    'completed' => 'Completed',
    'pending' => 'Pending',
    'awaiting_confirmation' => 'Awaiting confirmation',
    'failed' => 'Failed',
    'cancelled' => 'Cancelled',
    'expired' => 'Expired',
    'refunded' => 'Refunded',
    _ => status,
  };

  String get methodLabel => switch (method) {
    'card' => 'Card',
    'orange_money' => 'Orange Money',
    'mtn_momo' => 'MTN MoMo',
    _ => method,
  };

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
    id: (json['id'] ?? '') as String,
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    currency: (json['currency'] ?? 'XAF') as String,
    method: (json['method'] ?? '') as String,
    status: (json['status'] ?? 'pending') as String,
    reference: (json['reference'] ?? '') as String,
    description: json['description'] as String?,
    itemType: json['item_type'] as String?,
    bookId: json['book_id'] as String?,
    planId: json['plan_id'] as String?,
    gatewayReference: json['gateway_reference'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.parse((json['created_at'] as String).replaceAll('+00:00', 'Z'))
        : null,
    completedAt: json['completed_at'] != null
        ? DateTime.parse((json['completed_at'] as String).replaceAll('+00:00', 'Z'))
        : null,
  );
}
