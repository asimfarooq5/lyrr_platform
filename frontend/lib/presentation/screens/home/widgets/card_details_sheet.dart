/// Card entry sheet for the checkout.
///
/// Paying by card means typing a card in. The app used to settle a card
/// payment with no card at all, which is not what a payer expects to see and
/// not what the client will look for when they try the flow.
///
/// While the gateway is in sandbox no card is charged, so the sheet offers the
/// standard test number and accepts any well-formed card — but the fields, the
/// grouping and the validation are the ones a real form has.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';

class CardDetails {
  final String number;
  final String expiry;
  final String cvc;
  final String name;

  const CardDetails({
    required this.number,
    required this.expiry,
    required this.cvc,
    required this.name,
  });

  String get last4 => number.length >= 4 ? number.substring(number.length - 4) : number;
}

/// The card the demo can always use; accepted by every sandbox gateway.
const kTestCardNumber = '4242424242424242';

Future<CardDetails?> showCardDetailsSheet(
  BuildContext context, {
  required String amountLabel,
}) {
  return showModalBottomSheet<CardDetails>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      // Lift the sheet above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _CardSheet(amountLabel: amountLabel),
    ),
  );
}

class _CardSheet extends StatefulWidget {
  const _CardSheet({required this.amountLabel});

  final String amountLabel;

  @override
  State<_CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends State<_CardSheet> {
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _cvc.dispose();
    _name.dispose();
    super.dispose();
  }

  void _useTestCard() {
    setState(() {
      _number.text = '4242 4242 4242 4242';
      _expiry.text = '12/34';
      _cvc.text = '123';
      if (_name.text.isEmpty) _name.text = 'LYRR Demo';
      _error = null;
    });
  }

  void _submit() {
    final digits = _number.text.replaceAll(RegExp(r'\D'), '');
    final expiry = _expiry.text.trim();
    final cvc = _cvc.text.trim();

    String? problem;
    if (digits.length < 15 || digits.length > 19) {
      problem = 'Enter the 16 digits on the front of the card.';
    } else if (!RegExp(r'^\d{2}\s*/\s*\d{2}$').hasMatch(expiry)) {
      problem = 'Enter the expiry as MM/YY.';
    } else if (cvc.length < 3) {
      problem = 'Enter the 3-digit code from the back of the card.';
    } else if (_name.text.trim().length < 2) {
      problem = "Enter the name on the card.";
    }

    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    Navigator.pop(context, CardDetails(
      number: digits,
      expiry: expiry,
      cvc: cvc,
      name: _name.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.credit_card, color: AppColors.primary),
                const SizedBox(width: 10),
                Text('Card details',
                    style: theme.textTheme.displaySmall?.copyWith(fontSize: 18)),
                const Spacer(),
                TextButton(
                  onPressed: _useTestCard,
                  child: const Text('Use test card'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'You will be charged ${widget.amountLabel}.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 18),

            _field(
              controller: _number,
              label: 'Card number',
              hint: '1234 1234 1234 1234',
              icon: Icons.credit_card,
              keyboard: TextInputType.number,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                _CardNumberFormatter(),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _expiry,
                    label: 'Expiry',
                    hint: 'MM/YY',
                    icon: Icons.calendar_today_outlined,
                    keyboard: TextInputType.number,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ExpiryFormatter(),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _cvc,
                    label: 'CVC',
                    hint: '123',
                    icon: Icons.lock_outline,
                    keyboard: TextInputType.number,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _field(
              controller: _name,
              label: 'Name on card',
              hint: 'As printed on the card',
              icon: Icons.person_outline,
              keyboard: TextInputType.name,
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error)),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text('Pay ${widget.amountLabel}'),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Sandbox — no card is charged.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType keyboard,
    List<TextInputFormatter>? formatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          inputFormatters: formatters,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

/// Groups digits as 1234 5678 9012 3456 while typing.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 19 ? digits.substring(0, 19) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(limited[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Inserts the slash as the month is completed.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = limited.length >= 3
        ? '${limited.substring(0, 2)}/${limited.substring(2)}'
        : limited;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
