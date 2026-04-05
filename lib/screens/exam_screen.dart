import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/services_service.dart';
import '../state/session.dart';
import '../widgets/primary_button.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../widgets/purchase_result_sheet.dart';
import '../widgets/service_shell.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  final _phoneCtrl = TextEditingController();
  String _exam = 'waec';
  int _quantity = 1;
  List<String> _examTypes = const ['waec', 'neco', 'jamb'];
  bool _loading = false;
  bool _saveBeneficiary = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;
    try {
      final data = await ServicesService(token: token).getCatalog();
      final raw = data['exam_types'];
      if (raw is List && raw.isNotEmpty) {
        final items = raw
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList();
        if (!mounted) return;
        setState(() {
          _examTypes = items;
          if (!_examTypes.contains(_exam)) {
            _exam = _examTypes.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final phoneRaw = _phoneCtrl.text.trim();
    final phone = phoneRaw.isEmpty
        ? ''
        : phoneRaw.replaceAll(RegExp(r'\D'), '');

    if (_quantity < 1 || _quantity > 10) {
      setState(() => _error = 'Quantity must be between 1 and 10.');
      return;
    }
    if (phone.isNotEmpty && (phone.length < 10 || phone.length > 15)) {
      setState(() => _error = 'Enter a valid phone number or leave it empty.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    PurchaseLoadingOverlay.show(context, title: 'Buying exam pin');

    try {
      final res = await ServicesService(
        token: token,
      ).purchaseExam(exam: _exam, quantity: _quantity, phoneNumber: phone);
      if (!mounted) return;
      PurchaseLoadingOverlay.hide();
      final pins = ((res['pins'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      _showResult(
        status: (res['status'] ?? 'success').toString(),
        subtitle: 'Exam pin request has been submitted successfully.',
        reference: (res['reference'] ?? '').toString(),
        fields: [
          ReceiptField(label: 'Exam', value: _exam.toUpperCase()),
          ReceiptField(label: 'Quantity', value: _quantity.toString()),
          ReceiptField(label: 'Phone', value: phone.isEmpty ? '—' : phone),
          ReceiptField(
            label: 'Pins',
            value: pins.isEmpty ? '—' : pins.join(', '),
          ),
        ],
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      PurchaseLoadingOverlay.hide();
      _showResult(
        status: 'failed',
        subtitle: message,
        reference: 'AXIS-EXAM-ATTEMPT-${DateTime.now().millisecondsSinceEpoch}',
        fields: [
          ReceiptField(label: 'Exam', value: _exam.toUpperCase()),
          ReceiptField(label: 'Quantity', value: _quantity.toString()),
          ReceiptField(label: 'Phone', value: phone.isEmpty ? '—' : phone),
          ReceiptField(label: 'Failure', value: message),
        ],
      );
    } finally {
      PurchaseLoadingOverlay.hide();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showResult({
    required String status,
    required String subtitle,
    required String reference,
    required List<ReceiptField> fields,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PurchaseResultSheet(
        status: status,
        title: status.toLowerCase() == 'failed'
            ? 'Exam Purchase Failed'
            : 'Exam Purchase Successful',
        subtitle: subtitle,
        fields: [
          ReceiptField(label: 'Time', value: _formatDate(DateTime.now())),
          ...fields,
          ReceiptField(label: 'Reference', value: reference),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ServiceShell(
      title: 'Exam Pins',
      subtitle: 'Buy WAEC, NECO and JAMB pins with premium checkout.',
      icon: Icons.school_rounded,
      child: Column(
        children: [
          ServiceSectionCard(
            title: 'Exam Type',
            subtitle: 'Choose the exam service you want.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _examTypes
                  .map(
                    (exam) => ServiceChoiceChip(
                      label: exam.toUpperCase(),
                      selected: _exam == exam,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _exam = exam);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          ServiceSectionCard(
            title: 'Quantity',
            subtitle: 'You can buy 1 to 10 pins at once.',
            child: Row(
              children: [
                _CounterBtn(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (_quantity > 1) _quantity--;
                    });
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_quantity',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                _CounterBtn(
                  icon: Icons.add_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (_quantity < 10) _quantity++;
                    });
                  },
                ),
              ],
            ),
          ),
          ServiceSectionCard(
            title: 'Phone (Optional)',
            subtitle: 'Some providers require recipient number.',
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number (optional)',
                hintText: '08123456789',
                prefixIcon: Icon(Icons.call_outlined),
              ),
            ),
          ),
          ServiceSectionCard(
            title: 'Checkout',
            subtitle: 'Review request before purchase.',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    const Color(0xFF0FB5AE).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_exam.toUpperCase()} • Qty $_quantity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _phoneCtrl.text.trim().isEmpty
                        ? 'Phone: optional'
                        : 'Phone: ${_phoneCtrl.text.trim()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          ServiceSectionCard(
            title: 'Beneficiary',
            subtitle: 'Save this profile for quick repeat purchase.',
            child: Row(
              children: [
                const Icon(Icons.bookmark_added_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Auto-save exam profile',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Switch(
                  value: _saveBeneficiary,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _saveBeneficiary = v);
                  },
                ),
              ],
            ),
          ),
          if (_error != null)
            ServiceSectionCard(
              title: 'Validation',
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          PrimaryButton(
            label: 'Buy Exam Pin',
            icon: Icons.school_rounded,
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  const _CounterBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Icon(icon),
      ),
    );
  }
}
