import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/purchase_auth_service.dart';
import '../services/request_id.dart';
import '../services/services_service.dart';
import '../state/session.dart';
import '../widgets/epic_purchase_summary.dart';
import '../widgets/epic_receipt_modal.dart';
import '../widgets/insufficient_funds_sheet.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../utils/balance_util.dart';
import 'cable_screen.dart';

class CableDetailsScreen extends StatefulWidget {
  final CableProvider provider;

  const CableDetailsScreen({super.key, required this.provider});

  @override
  State<CableDetailsScreen> createState() => _CableDetailsScreenState();
}

class _CableDetailsScreenState extends State<CableDetailsScreen> {
  final TextEditingController _smartcardCtrl = TextEditingController();
  
  List<Map<String, dynamic>> _packages = [];
  bool _packagesLoading = true;
  String? _packagesError;
  Map<String, dynamic>? _selectedPackage;

  bool _verifying = false;
  bool _verificationChecked = false;
  bool _verificationOk = false;
  String _verifiedCustomerName = '';
  String? _error;

  String? _activeRequestId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _smartcardCtrl.addListener(_clearVerification);
    _loadPackages();
  }

  @override
  void dispose() {
    _smartcardCtrl.removeListener(_clearVerification);
    _smartcardCtrl.dispose();
    super.dispose();
  }

  void _clearVerification() {
    if (_verificationChecked || _verificationOk) {
      setState(() {
        _verificationChecked = false;
        _verificationOk = false;
        _verifiedCustomerName = '';
        _error = null;
      });
    }
  }

  Future<void> _loadPackages() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    setState(() {
      _packagesLoading = true;
      _packagesError = null;
    });

    try {
      final data = await ServicesService(token: token).getCablePackages(provider: widget.provider.id);
      final raw = data['packages'];
      final list = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            list.add(item.map((k, v) => MapEntry(k.toString(), v)));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _packages = list;
        if (list.isNotEmpty) _selectedPackage = list.first;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _packagesError = 'Could not load packages. Tap to retry.');
    } finally {
      if (mounted) setState(() => _packagesLoading = false);
    }
  }

  Future<void> _verifySmartcard() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final smartcard = _smartcardCtrl.text.trim();
    if (smartcard.length < 5) {
      setState(() => _error = 'Enter a valid number to verify.');
      return;
    }

    setState(() {
      _verifying = true;
      _verificationChecked = false;
      _verificationOk = false;
      _verifiedCustomerName = '';
      _error = null;
    });

    try {
      final res = await ServicesService(token: token).verifyCable(
        provider: widget.provider.id,
        smartcardNumber: smartcard,
      );
      final ok = res['ok'] == true;
      setState(() {
        _verificationChecked = true;
        _verificationOk = ok;
        _verifiedCustomerName = ok ? (res['customer_name'] ?? '').toString().trim() : '';
        if (!ok) {
          _error = (res['message'] ?? 'Unable to verify.').toString();
        }
      });
    } catch (e) {
      final msg = e is ApiException ? e.message : e.toString();
      setState(() {
        _verificationChecked = true;
        _verificationOk = false;
        _error = msg.isNotEmpty ? msg : 'Unable to verify number right now.';
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  String get _smartcardLabel {
    final id = widget.provider.id;
    if (id == 'gotv') return 'Enter Decoder Number (IUC)';
    if (id == 'showmax') return 'Enter Customer ID';
    return 'Enter Smart Card Number';
  }

  double get _selectedAmount {
    final raw = _selectedPackage?['amount'];
    if (raw == null) return 0;
    return (raw is num) ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0;
  }
  
  String get _selectedPackageCode => (_selectedPackage?['code'] ?? '').toString();
  String get _selectedPackageName => (_selectedPackage?['name'] ?? '').toString();

  Color _getProviderColor(String id) {
    if (id == 'dstv') return const Color(0xFF0073C5);
    if (id == 'gotv') return const Color(0xFF00A859);
    if (id == 'startimes') return const Color(0xFFFFA500);
    if (id == 'showmax') return const Color(0xFFE50914);
    return Theme.of(context).primaryColor;
  }

  Widget _buildProviderIcon(String id) {
    if (id == 'dstv') {
      return Image.asset('assets/images/dstv.png', width: 48, height: 48, errorBuilder: (c,e,s) => const Icon(Icons.tv, color: Color(0xFF0073C5)));
    } else if (id == 'gotv') {
      return Image.asset('assets/images/gotv.png', width: 48, height: 48, errorBuilder: (c,e,s) => const Icon(Icons.tv, color: Color(0xFF00A859)));
    } else if (id == 'startimes') {
      return Image.asset('assets/images/startimes.png', width: 48, height: 48, errorBuilder: (c,e,s) => const Icon(Icons.tv, color: Color(0xFFFFA500)));
    } else if (id == 'showmax') {
      return Image.asset('assets/images/showmax.png', width: 48, height: 48, errorBuilder: (c,e,s) => const Icon(Icons.tv, color: Color(0xFFE50914)));
    }
    return const Icon(Icons.live_tv_rounded, size: 48, color: Colors.blueAccent);
  }

  void _showSummaryModal() {
    FocusScope.of(context).unfocus();

    if (_selectedPackage == null) {
      setState(() => _error = 'Please select a plan.');
      return;
    }
    if (!_verificationOk) {
      setState(() => _error = 'Please verify your number first.');
      return;
    }
    
    final amount = _selectedAmount;
    final balance = getUserBalance(context);
    if (balance < amount) {
      InsufficientFundsSheet.show(context, shortfall: amount - balance);
      return;
    }

    final smartcard = _smartcardCtrl.text.trim();
    final providerColor = _getProviderColor(widget.provider.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpicPurchaseSummary(
        title: 'Confirm Cable TV',
        subtitle: 'Review your cable subscription details',
        amount: amount.toStringAsFixed(2),
        primaryColor: providerColor,
        headerIcon: Icons.tv_rounded,
        items: [
          SummaryItem(label: 'Provider', value: widget.provider.name, icon: Icons.live_tv_rounded),
          SummaryItem(label: 'Smartcard / IUC', value: smartcard, icon: Icons.credit_card_rounded),
          if (_verifiedCustomerName.isNotEmpty)
            SummaryItem(label: 'Customer Name', value: _verifiedCustomerName, icon: Icons.person_rounded),
          SummaryItem(label: 'Package', value: _selectedPackageName, icon: Icons.subscriptions_rounded),
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

  String _resolveResultStatus(Map<String, dynamic> payload) {
    final s = (payload['status'] ?? '').toString().trim().toLowerCase();
    if (payload['success'] == true || s == 'success' || s == 'successful' || s == 'delivered' || s == 'completed' || s == 'order_completed') return 'success';
    if (s == 'pending' || s == 'processing' || s == 'queued' || s == 'order_received' || s == 'order_onhold') return 'pending';
    return 'failed';
  }

  String _resultSubtitle(String status, Map<String, dynamic> payload) {
    final msg = (payload['message'] ?? payload['detail'] ?? '').toString().trim();
    if (msg.isNotEmpty) return msg;
    if (status == 'success') return 'Cable order completed successfully.';
    if (status == 'pending') return 'Cable request received and currently processing.';
    return 'Cable order failed.';
  }

  Future<void> _submit({String authMethod = PurchaseAuthService.methodAuto}) async {
    if (_loading) return;
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final smartcard = _smartcardCtrl.text.trim();
    final packageCode = _selectedPackageCode;
    final amount = _selectedAmount;
    final phone = context.read<SessionController>().user?['phone']?.toString() ?? '08000000000';

    final authorized = await PurchaseAuthService.authorizePin(
      context: context,
      reason: 'cable subscription',
      preferredMethod: authMethod,
    );
    if (!mounted || !authorized) return;

    setState(() { _loading = true; _error = null; });
    PurchaseLoadingOverlay.show(context, title: 'Processing order');

    try {
      _activeRequestId ??= buildRequestId("cable");
      final res = await ServicesService(token: token).purchaseCable(
        provider: widget.provider.id,
        smartcardNumber: smartcard,
        phoneNumber: phone,
        packageCode: packageCode,
        amount: amount,
        customerName: _verifiedCustomerName.isNotEmpty ? _verifiedCustomerName : null,
        clientRequestId: _activeRequestId,
      );
      final status = _resolveResultStatus(res);
      if (!mounted) return;
      PurchaseLoadingOverlay.hide();
      _showResult(
        status: status,
        subtitle: _resultSubtitle(status, res),
        reference: (res['reference'] ?? '').toString(),
        amount: amount,
      );
      if (status != 'pending') _activeRequestId = null;
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      PurchaseLoadingOverlay.hide();
      _showResult(
        status: 'failed',
        subtitle: message,
        reference: 'AXIS-CABLE-${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
      );
      _activeRequestId = null;
    } finally {
      PurchaseLoadingOverlay.hide();
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showResult({
    required String status,
    required String subtitle,
    required String reference,
    required double amount,
  }) {
    if (status != 'failed') context.read<SessionController>().refreshBalance();
    final ok = status == 'success';
    final isSuccess = status.toLowerCase() != 'failed';
    final userName = context.read<SessionController>().user?['full_name'] ?? 'User';
    
    final Map<String, String> details = {
      'Date & Time': DateTime.now().toString().substring(0, 16),
      'Sender': userName,
      'Transaction Type': 'Cable Subscription',
      'Cable Provider': widget.provider.name.toUpperCase(),
      'Smartcard / IUC': _smartcardCtrl.text.trim(),
      if (_verifiedCustomerName.isNotEmpty) 'Customer Name': _verifiedCustomerName,
      'Package': _selectedPackageName.isNotEmpty ? _selectedPackageName : _selectedPackageCode,
      'Amount': '₦${amount.toStringAsFixed(2)}',
      'Reference': reference,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpicReceiptModal(
        isSuccess: ok,
        title: 'Cable Subscription',
        amount: '₦${amount.toStringAsFixed(2)}',
        primaryColor: _getProviderColor(widget.provider.id),
        details: details,
        onSave: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: EpicShareableReceipt(
                ok: ok,
                title: 'Cable Subscription',
                amount: '₦${amount.toStringAsFixed(2)}',
                details: details,
                primaryColor: _getProviderColor(widget.provider.id),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final userFullName = context.read<SessionController>().user?['full_name']?.toString() ?? 'User';
    final userPhone = context.read<SessionController>().user?['phone']?.toString() ?? 'Unknown';
    final balance = getUserBalance(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F141E) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bill Details',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    // Logo and Name
                    _buildProviderIcon(widget.provider.id),
                    const SizedBox(height: 12),
                    Text(
                      widget.provider.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Select Plan
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Plan',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2638) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                        ),
                      ),
                      child: _packagesLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                          )
                        : _packagesError != null
                          ? GestureDetector(
                              onTap: _loadPackages,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Text(_packagesError!, style: const TextStyle(color: Colors.red)),
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<Map<String, dynamic>>(
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white54 : Colors.black54),
                                hint: Text('Select Plan', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                                value: _selectedPackage,
                                dropdownColor: isDark ? const Color(0xFF1E2638) : Colors.white,
                                items: _packages.map((pkg) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: pkg,
                                    child: Text(
                                      pkg['name']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedPackage = val);
                                },
                              ),
                            ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Buy From (Wallet)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Buy from',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2638) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'M',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userFullName.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Account Number: $userPhone',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Balance: '),
                                      TextSpan(
                                        text: '₦${balance.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    
                    // Smartcard Input
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _smartcardLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _error != null ? Colors.red.withOpacity(0.5) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: TextField(
                                controller: _smartcardCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  fontSize: 15,
                                  letterSpacing: 1.2,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                decoration: InputDecoration(
                                  hintText: '8213172899',
                                  hintStyle: TextStyle(
                                    color: isDark ? Colors.white24 : Colors.black26,
                                    letterSpacing: 2,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ),
                          // Big Blue Verify Button
                          GestureDetector(
                            onTap: _verifying ? null : _verifySmartcard,
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: _verifying 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ),
                      
                    if (_verificationChecked && _verificationOk)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _verifiedCustomerName.isNotEmpty ? _verifiedCustomerName : 'Verified',
                            style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                    
                    // Amount
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tag, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 20),
                          const SizedBox(width: 16),
                          Text(
                            _selectedAmount > 0 ? _selectedAmount.toStringAsFixed(2) : '0.0',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
            
            // Continue Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _showSummaryModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
                    foregroundColor: isDark ? Colors.white : Colors.black54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
