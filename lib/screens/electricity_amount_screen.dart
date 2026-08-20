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
import '../widgets/purchase_result_sheet.dart';
import '../utils/balance_util.dart';
import 'electricity_screen.dart';

class ElectricityAmountScreen extends StatefulWidget {
  final ElectricityProvider provider;
  final String meterNumber;
  final String customerName;

  const ElectricityAmountScreen({
    super.key,
    required this.provider,
    required this.meterNumber,
    required this.customerName,
  });

  @override
  State<ElectricityAmountScreen> createState() => _ElectricityAmountScreenState();
}

class _ElectricityAmountScreenState extends State<ElectricityAmountScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  bool _loading = false;
  String? _activeRequestId;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onPresetSelected(String amount) {
    setState(() {
      _amountCtrl.text = amount;
    });
  }

  String _resultSubtitle(String status, Map<String, dynamic> res) {
    if (status == 'success') return 'Your electricity token purchase was successful.';
    if (status == 'pending') return 'Order submitted. Pending confirmation.';
    return res['message']?.toString() ?? 'Transaction failed';
  }

  String _resolveResultStatus(Map<String, dynamic> res) {
    final status = res['status']?.toString().toLowerCase() ?? 'failed';
    if (status == 'success' || status == 'completed' || status == 'delivered') return 'success';
    if (status == 'pending' || status == 'processing') return 'pending';
    return 'failed';
  }

  bool _isUncertainPurchaseError(String message) {
    final text = message.toLowerCase();
    return text.contains('timed out') ||
        text.contains('timeout') ||
        text.contains('unable to reach server') ||
        text.contains('failed to fetch') ||
        text.contains('network error') ||
        text.contains('connection');
  }

  Future<void> _submit({
    String authMethod = PurchaseAuthService.methodAuto,
  }) async {
    if (_loading) return;
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final amountText = _amountCtrl.text.replaceAll(',', '').trim();
    final amount = double.tryParse(amountText) ?? 0;
    
    // We implicitly pass session phone for the purchase since there's no phone field on screenshot
    final userPhone = context.read<SessionController>().user?['phone']?.toString() ?? '08000000000';

    final authorized = await PurchaseAuthService.authorizePin(
      context: context,
      reason: 'electricity purchase',
      preferredMethod: authMethod,
    );
    if (!mounted || !authorized) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    PurchaseLoadingOverlay.show(context, title: 'Processing order');

    try {
      _activeRequestId ??= buildRequestId("electricity");
      final res = await ServicesService(token: token).purchaseElectricity(
        disco: widget.provider.discoId,
        meterType: widget.provider.type,
        meterNumber: widget.meterNumber,
        phoneNumber: userPhone,
        amount: amount,
        clientRequestId: _activeRequestId,
      );
      final status = _resolveResultStatus(res);
      if (!mounted) return;
      PurchaseLoadingOverlay.hide();
      
      final tokenStr = (res['token'] ?? '').toString();
      
      _showResult(
        status: status,
        subtitle: _resultSubtitle(status, res),
        token: tokenStr,
        fields: [
          ReceiptField(label: 'Provider', value: widget.provider.name),
          ReceiptField(label: 'Meter', value: widget.meterNumber),
          ReceiptField(label: 'Name', value: widget.customerName),
          ReceiptField(label: 'Amount', value: '₦${amount.toStringAsFixed(2)}'),
        ],
      );
      if (status != 'pending') {
        _activeRequestId = null;
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      PurchaseLoadingOverlay.hide();
      if (_isUncertainPurchaseError(message)) {
        _showResult(
          status: 'pending',
          subtitle: 'Order submitted. Provider confirmation is delayed.',
          token: '',
          fields: [
            ReceiptField(label: 'Provider', value: widget.provider.name),
            ReceiptField(label: 'Meter', value: widget.meterNumber),
            ReceiptField(label: 'Amount', value: '₦${amount.toStringAsFixed(2)}'),
          ],
        );
      } else {
        _showResult(
          status: 'failed',
          subtitle: message,
          token: '',
          fields: [
            ReceiptField(label: 'Provider', value: widget.provider.name),
            ReceiptField(label: 'Meter', value: widget.meterNumber),
            ReceiptField(label: 'Name', value: widget.customerName),
            ReceiptField(label: 'Amount', value: '₦${amount.toStringAsFixed(2)}'),
            ReceiptField(label: 'Failure', value: message),
          ],
        );
        _activeRequestId = null;
      }
    } finally {
      PurchaseLoadingOverlay.hide();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showSummaryModal() {
    final amountText = _amountCtrl.text.replaceAll(',', '').trim();
    final amount = double.tryParse(amountText) ?? 0;
    
    if (amount < 500) {
      setState(() => _error = 'Minimum electricity amount is ₦500.');
      return;
    }

    final balance = getUserBalance(context);
    if (balance < amount) {
      InsufficientFundsSheet.show(context, shortfall: amount - balance);
      return;
    }

    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpicPurchaseSummary(
        title: 'Confirm Electricity',
        subtitle: 'Please review your electricity purchase details below',
        amount: '₦${amount.toStringAsFixed(2)}',
        primaryColor: Theme.of(context).primaryColor,
        headerIcon: Icons.electrical_services,
        items: [
          SummaryItem(label: 'Provider', value: widget.provider.name, icon: Icons.business),
          SummaryItem(label: 'Meter Number', value: widget.meterNumber, icon: Icons.speed),
          SummaryItem(label: 'Customer', value: widget.customerName, icon: Icons.person),
          SummaryItem(label: 'Amount', value: '₦${amount.toStringAsFixed(2)}', icon: Icons.attach_money),
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
    required String token,
    required List<ReceiptField> fields,
  }) {
    if (status != 'failed') {
      context.read<SessionController>().refreshBalance();
    }
    final ok = status == 'success';
    final userName = context.read<SessionController>().user?['full_name'] ?? 'User';
    final amountText = _amountCtrl.text.replaceAll(',', '').trim();
    final amount = double.tryParse(amountText) ?? 0;
    final isSuccess = status.toLowerCase() != 'failed';
    
    final Map<String, String> details = {
      'Date & Time': DateTime.now().toString().substring(0, 16),
      'Sender': userName,
      'Transaction Type': 'Electricity Token',
      'Provider': widget.provider.name,
      'Meter Number': widget.meterNumber,
      'Customer Name': widget.customerName,
      'Amount': '₦${amount.toStringAsFixed(2)}',
    };
    
    if (token.isNotEmpty) {
      details['Token'] = token;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpicReceiptModal(
        isSuccess: ok,
        title: 'Electricity Token',
        amount: '₦${amount.toStringAsFixed(2)}',
        primaryColor: Theme.of(context).primaryColor,
        details: details,
        onSave: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: EpicShareableReceipt(
                ok: ok,
                title: 'Electricity Token',
                amount: '₦${amount.toStringAsFixed(2)}',
                details: details,
                primaryColor: Theme.of(context).primaryColor,
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
    
    // Fallback if full_name is null
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
          'Add amount',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Customer Info Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Icon(Icons.electrical_services, size: 16, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.meterNumber} • ${widget.customerName.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 48),
              
              // Massive Amount Display with TextField
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₦',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IntrinsicWidth(
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _showSummaryModal(),
                      onChanged: (_) {
                        setState(() { _error = null; });
                      },
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
              
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              
              const SizedBox(height: 48),
              
              // Preset Grid (No Cashbacks)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 2.2,
                  children: [
                    _PresetCard(amount: '1,000', isDark: isDark, onTap: () => _onPresetSelected('1000')),
                    _PresetCard(amount: '2,000', isDark: isDark, onTap: () => _onPresetSelected('2000')),
                    _PresetCard(amount: '5,000', isDark: isDark, onTap: () => _onPresetSelected('5000')),
                    _PresetCard(amount: '7,000', isDark: isDark, onTap: () => _onPresetSelected('7000')),
                    _PresetCard(amount: '10,000', isDark: isDark, onTap: () => _onPresetSelected('10000')),
                    _PresetCard(amount: '15,000', isDark: isDark, onTap: () => _onPresetSelected('15000')),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Wallet Info Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2638) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    ),
                    boxShadow: isDark ? [] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'ME',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
                              '$userFullName • $userPhone',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₦${balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 15,
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
              ),
              
              const SizedBox(height: 32),
              
              // Continue Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _showSummaryModal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
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
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final String amount;
  final bool isDark;
  final VoidCallback onTap;

  const _PresetCard({
    required this.amount,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2638) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Center(
          child: Text(
            '₦$amount',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
