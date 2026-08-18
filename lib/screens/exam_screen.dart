import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/purchase_auth_service.dart';
import '../services/request_id.dart';
import '../services/services_service.dart';
import '../state/session.dart';
import '../widgets/service_shell.dart';
import '../widgets/epic_purchase_summary.dart';
import '../widgets/epic_receipt_modal.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../widgets/purchase_result_sheet.dart';
import '../widgets/primary_button.dart';
import '../widgets/sticky_checkout_bar.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart' as native_contact;
import 'package:permission_handler/permission_handler.dart';
import '../widgets/elite_phone_input.dart';
import '../services/permission_service.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  static const _saveBeneficiaryKey = 'axis_exam_save_beneficiary_v1';
  static const _beneficiariesKey = 'axis_exam_beneficiaries_v1';
  static const Map<String, List<String>> _networkPrefixes = {
    'mtn': [
      '07025',
      '07026',
      '0803',
      '0806',
      '0703',
      '0706',
      '0810',
      '0813',
      '0814',
      '0816',
      '0903',
      '0906',
      '0913',
      '0916',
      '0704',
    ],
    'airtel': [
      '0802',
      '0808',
      '0708',
      '0812',
      '0701',
      '0902',
      '0907',
      '0901',
      '0912',
    ],
    'glo': ['0805', '0807', '0705', '0815', '0811', '0905', '0915'],
    '9mobile': ['0809', '0817', '0818', '0908', '0909'],
  };

  final _phoneCtrl = TextEditingController();
  String _detectedNetwork = '';
  String _exam = 'waec';
  int _quantity = 1;
  List<String> _examTypes = const ['waec', 'neco', 'jamb'];
  bool _loading = false;
  bool _loadingPackages = false;
  List<Map<String, dynamic>> _packages = [];
  String? _selectedPackage;
  String? _activeRequestId;
  bool _saveBeneficiary = true;
  List<Map<String, dynamic>> _beneficiaries = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_onPhoneChanged);
    _loadCatalog();
    _loadPreferences();
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_onPhoneChanged);
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
          _invalidateRequestId();
          _examTypes = items;
          if (!_examTypes.contains(_exam)) {
            _exam = _examTypes.first;
          }
        });
        _fetchPackages();
      }
    } catch (_) {}
  }

  Future<void> _fetchPackages() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;
    setState(() {
      _loadingPackages = true;
      _packages = [];
      _selectedPackage = null;
    });
    try {
      final res = await ServicesService(token: token).getExamPackages(exam: _exam);
      final raw = res['packages'];
      if (raw is List) {
        final list = raw.map((e) => e as Map<String, dynamic>).toList();
        if (mounted) {
          setState(() {
            _packages = list;
            if (_packages.isNotEmpty) {
              final resultPkg = _packages.firstWhere(
                (p) => (p['name']?.toString().toLowerCase().contains('result') ?? false),
                orElse: () => _packages.first,
              );
              _selectedPackage = resultPkg['code']?.toString();
            }
            _loadingPackages = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _packages = [];
          _selectedPackage = null;
          _loadingPackages = false;
        });
      }
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_saveBeneficiaryKey) ?? _saveBeneficiary;
    final raw = prefs.getString(_beneficiariesKey);
    final list = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            list.add(item.map((k, v) => MapEntry(k.toString(), v)));
          }
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _saveBeneficiary = enabled;
      _beneficiaries = list;
    });
  }

  void _invalidateRequestId() {
    _activeRequestId = null;
  }

  String _normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('234')) {
      digits = '0${digits.substring(3)}';
    }
    if (digits.length == 10 && !digits.startsWith('0')) {
      digits = '0$digits';
    }
    return digits;
  }

  String? _detectNetwork(String normalizedPhone) {
    if (normalizedPhone.length < 4) return null;
    final prefixes = <MapEntry<String, String>>[];
    _networkPrefixes.forEach((network, items) {
      for (final prefix in items) {
        prefixes.add(MapEntry(prefix, network));
      }
    });
    prefixes.sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in prefixes) {
      if (normalizedPhone.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  void _onPhoneChanged() {
    _invalidateRequestId();
    final normalized = _normalizePhone(_phoneCtrl.text);
    final detected = _detectNetwork(normalized) ?? '';
    if (detected != _detectedNetwork) {
      setState(() {
        _detectedNetwork = detected;
      });
    }
  }

  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();

  Future<void> _pickContact() async {
    try {
      final granted = await PermissionService.requestContactPermission(context);
      if (!granted) return;

      final native_contact.Contact? contact = await _contactPicker.selectContact();
      if (contact != null && contact.phoneNumbers != null && contact.phoneNumbers!.isNotEmpty) {
        String phone = contact.phoneNumbers!.first.replaceAll(RegExp(r'\D'), '');
        // Strip 234 prefix if present
        if (phone.startsWith('234') && phone.length > 10) {
          phone = '0${phone.substring(3)}';
        }
        _phoneCtrl.text = phone;
        _onPhoneChanged();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking contact: $e')),
      );
    }
  }

  Future<void> _savePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_saveBeneficiaryKey, value);
  }

  Future<void> _saveBeneficiaryFromInput() async {
    if (!_saveBeneficiary) return;
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final entry = <String, dynamic>{
      'exam': _exam,
      'quantity': _quantity,
      'phone_number': phone,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final identity = '${_exam.toLowerCase()}|$phone|$_quantity';
    final next = <Map<String, dynamic>>[
      entry,
      ..._beneficiaries.where((item) {
        final key =
            '${(item['exam'] ?? '').toString().toLowerCase()}|${(item['phone_number'] ?? '').toString()}|${(item['quantity'] ?? '').toString()}';
        return key != identity;
      }),
    ].take(10).toList();
    setState(() => _beneficiaries = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_beneficiariesKey, jsonEncode(next));
  }

  void _applyBeneficiary(Map<String, dynamic> item) {
    final exam = (item['exam'] ?? _exam).toString().toLowerCase();
    final quantity = int.tryParse((item['quantity'] ?? _quantity).toString());
    final phone = (item['phone_number'] ?? '').toString().trim();
    HapticFeedback.mediumImpact();
    setState(() {
      if (_examTypes.contains(exam)) {
        if (_exam != exam) {
          _exam = exam;
          _fetchPackages();
        }
      }
      if (quantity != null && quantity >= 1 && quantity <= 10) {
        _quantity = quantity;
      }
      _phoneCtrl.text = phone;
    });
  }

  Future<void> _submit({
    String authMethod = PurchaseAuthService.methodAuto,
  }) async {
    if (_loading) return;
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

    final authorized = await PurchaseAuthService.authorizePin(
      context: context,
      reason: 'exam pin order',
      preferredMethod: authMethod,
    );
    if (!mounted || !authorized) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    PurchaseLoadingOverlay.show(context, title: 'Processing order');

    try {
      _activeRequestId ??= buildRequestId("exam");
      final res = await ServicesService(token: token).purchaseExam(
        exam: _exam,
        examType: _selectedPackage,
        quantity: _quantity,
        phoneNumber: phone,
        clientRequestId: _activeRequestId,
      );
      final status = _resolveResultStatus(res);
      if (!mounted) return;
      if (status != 'failed') {
        await _saveBeneficiaryFromInput();
      }
      PurchaseLoadingOverlay.hide();
      final pins = ((res['pins'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      _showResult(
        status: status,
        subtitle: _resultSubtitle(status, res),
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
      if (status != 'pending') {
        _activeRequestId = null;
      }
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
      _activeRequestId = null;
    } finally {
      PurchaseLoadingOverlay.hide();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Color _getExamColor(String exam) {
    switch (exam.toLowerCase()) {
      case 'waec': return const Color(0xFF003399);
      case 'neco': return const Color(0xFF009933);
      case 'nabteb': return const Color(0xFFFF9900);
      default: return Theme.of(context).primaryColor;
    }
  }

  void _showAuthChoiceSheet() {
    final phone = _phoneCtrl.text.trim();
    
    // Calculate total amount based on the exam if possible, or show 'N/A'
    // Since exam_screen doesn't explicitly have the price logic here (it fetches dynamically),
    // we'll just show the quantity or fetch price if available.
    // Wait, the original code had `amount: 'Quantity: $_quantity'`.
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => EpicPurchaseSummary(
        title: 'Confirm Exam PIN',
        subtitle: 'Please review your exam PIN request below',
        amount: (_selectedPackage != null && _packages.isNotEmpty)
            ? '₦${((_packages.firstWhere((p) => p['code'].toString() == _selectedPackage, orElse: () => {'amount': 0.0})['amount'] ?? 0.0) * _quantity).toStringAsFixed(2)}'
            : '$_quantity PIN(s)',
        primaryColor: _getExamColor(_exam),
        headerIcon: Icons.school_rounded,
        items: [
          SummaryItem(label: 'Exam Board', value: _exam.toUpperCase(), icon: Icons.assignment_rounded),
          if (_selectedPackage != null && _packages.isNotEmpty)
            SummaryItem(
              label: 'Package',
              value: _packages.firstWhere((p) => p['code'].toString() == _selectedPackage, orElse: () => {'name': _selectedPackage})['name'].toString(),
              icon: Icons.confirmation_num_rounded,
            ),
          SummaryItem(label: 'Quantity', value: '$_quantity', icon: Icons.numbers_rounded),
          if (phone.isNotEmpty) SummaryItem(label: 'Phone Number', value: phone, icon: Icons.phone_android_rounded),
        ],
        onProceedPin: () {
          Navigator.pop(context);
          _submit(authMethod: PurchaseAuthService.methodPin);
        },
        onProceedBiometric: () {
          Navigator.pop(context);
          _submit(authMethod: PurchaseAuthService.methodBiometric);
        },
      ),
    );
  }

  void _showResult({
    required String status,
    required String subtitle,
    required String reference,
    required List<ReceiptField> fields,
  }) {
    if (status != 'failed') {
      context.read<SessionController>().refreshBalance();
    }
    final ok = status == 'success';
    final isSuccess = status.toLowerCase() != 'failed';
    final userName = context.read<SessionController>().user?['full_name'] ?? 'User';

    final Map<String, String> details = {
      'Date & Time': DateTime.now().toString().substring(0, 16),
      'Sender': userName,
      'Provider': 'MELE DATA',
      'Transaction Type': 'Exam PIN Purchase',
      'Exam Board': _exam.toUpperCase(),
      if (_selectedPackage != null && _packages.isNotEmpty)
        'Package': _packages.firstWhere((p) => p['code'].toString() == _selectedPackage, orElse: () => {'name': _selectedPackage})['name'].toString(),
      'Quantity': '$_quantity',
      'Reference': reference,
    };
    
    if (_phoneCtrl.text.trim().isNotEmpty) {
      details['Phone Number'] = _phoneCtrl.text.trim();
    }

    // Extract PINs if any from fields to put it in details
    for (final field in fields) {
      if (field.label.toLowerCase() == 'pins' && field.value.isNotEmpty && field.value != '—') {
        details['PIN(s)'] = field.value;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpicReceiptModal(
        isSuccess: ok,
        title: 'Exam PIN Purchase',
        amount: '$_quantity PIN(s)',
        primaryColor: _getExamColor(_exam),
        details: details,
        onSave: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: EpicShareableReceipt(
                ok: ok,
                title: 'Exam PIN Purchase',
                amount: '$_quantity PIN(s)',
                details: details,
                primaryColor: _getExamColor(_exam),
              ),
            ),
          );
        },
      ),
    ).then((_) {
      if (isSuccess && mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    });
  }

  String _resolveResultStatus(Map<String, dynamic> payload) {
    final statusRaw = (payload['status'] ?? '').toString().trim().toLowerCase();
    final ok =
        payload['success'] == true ||
        statusRaw == 'success' ||
        statusRaw == 'successful' ||
        statusRaw == 'delivered' ||
        statusRaw == 'completed' ||
        statusRaw == 'order_completed';
    if (ok) return 'success';
    final pending =
        statusRaw == 'pending' ||
        statusRaw == 'processing' ||
        statusRaw == 'queued' ||
        statusRaw == 'order_received' ||
        statusRaw == 'order_onhold';
    if (pending) return 'pending';
    return 'failed';
  }

  String _statusTitle({
    required String status,
    required String success,
    required String pending,
    required String failed,
  }) {
    final normalized = status.toLowerCase();
    if (normalized == 'success') return success;
    if (normalized == 'pending') return pending;
    return failed;
  }

  String _resultSubtitle(String status, Map<String, dynamic> payload) {
    final message = (payload['message'] ?? payload['detail'] ?? '')
        .toString()
        .trim();
    if (message.isNotEmpty) return message;
    if (status == 'success') return 'Exam order completed successfully.';
    if (status == 'pending') {
      return 'Exam request received and currently processing.';
    }
    return 'Exam order failed.';
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
      footer: StickyCheckoutBar(
        title: _exam.toUpperCase(),
        subtitle: 'Qty: $_quantity',
        amount: (_selectedPackage != null && _packages.isNotEmpty)
            ? '₦${((_packages.firstWhere((p) => p['code'].toString() == _selectedPackage, orElse: () => {'amount': 0.0})['amount'] ?? 0.0) * _quantity).toStringAsFixed(2)}'
            : '$_quantity Pins',
        active: !_loading && _packages.isNotEmpty,
        loading: _loading || _loadingPackages,
        onBuy: _showAuthChoiceSheet,
        actionLabel: 'Confirm Order',
        icon: Icons.school_rounded,
      ),
      child: Column(
        children: [
          ServiceSectionCard(
            title: 'Exam Type',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _examTypes.map((exam) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ServiceChoiceChip(
                      label: exam.toUpperCase(),
                      selected: _exam == exam,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _invalidateRequestId();
                        if (_exam != exam) {
                          setState(() => _exam = exam);
                          _fetchPackages();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (_loadingPackages)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_packages.isNotEmpty) ...[
            ServiceSectionCard(
              title: 'Service type',
              child: DropdownButtonFormField<String>(
                value: _selectedPackage,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                dropdownColor: Theme.of(context).cardColor,
                icon: const Icon(Icons.chevron_right_rounded),
                items: _packages.map((pkg) {
                  return DropdownMenuItem<String>(
                    value: pkg['code'].toString(),
                    child: Text(pkg['name']?.toString() ?? pkg['code'].toString()),
                  );
                }).toList(),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  _invalidateRequestId();
                  setState(() => _selectedPackage = val);
                },
              ),
            ),
            ServiceSectionCard(
              title: 'Amount',
              child: TextFormField(
                initialValue: _selectedPackage != null
                    ? '₦${(_packages.firstWhere((p) => p['code'].toString() == _selectedPackage)['amount'] ?? 0.0)}'
                    : '',
                key: ValueKey(_selectedPackage),
                readOnly: true,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ],
          ServiceSectionCard(
            title: 'Quantity',
            child: Row(
              children: [
                _CounterBtn(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _invalidateRequestId();
                    setState(() {
                      if (_quantity > 1) _quantity--;
                    });
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                _CounterBtn(
                  icon: Icons.add_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _invalidateRequestId();
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
            child: ElitePhoneInput(
              controller: _phoneCtrl,
              network: _detectedNetwork,
              onChanged: (v) => _onPhoneChanged(),
              onContactTap: _pickContact,
            ),
          ),
          if (_error != null)
            ServiceSectionCard(
              title: 'Validation',
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DualAuthSheet extends StatelessWidget {
  const _DualAuthSheet({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onPin,
    required this.onBiometric,
    required this.phone,
  });

  final String title;
  final String subtitle;
  final String amount;
  final String phone;
  final VoidCallback onPin;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Phone: $phone', style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 6),
          Text(
            amount,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPin,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Use PIN'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onBiometric,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Use Biometric'),
                ),
              ),
            ],
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
