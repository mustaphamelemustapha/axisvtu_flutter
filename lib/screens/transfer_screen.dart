import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../services/wallet_service.dart';
import '../services/purchase_auth_service.dart';
import '../state/session.dart';
import '../utils/balance_util.dart';
import '../widgets/epic_purchase_summary.dart';
import '../widgets/glass_card.dart';
import '../widgets/insufficient_funds_sheet.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../widgets/epic_receipt_modal.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _amountController = TextEditingController();
  WalletService get _walletService => WalletService(token: context.read<SessionController>().token ?? '');

  bool _isVerifying = false;
  String? _verifiedName;
  
  String? _verifyError;
  Timer? _debounce;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(_onIdentifierChanged);
  }

  @override
  void dispose() {
    _identifierController.removeListener(_onIdentifierChanged);
    _identifierController.dispose();
    _amountController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onIdentifierChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    final text = _identifierController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _verifiedName = null;
        
        _verifyError = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 800), () {
      _verifyRecipient(text);
    });
  }

  Future<void> _verifyRecipient(String identifier) async {
    setState(() {
      _isVerifying = true;
      _verifyError = null;
    });

    try {
      final res = await _walletService.verifyTransferRecipient(identifier);
      setState(() {
        _verifiedName = res['full_name'];
        
      });
    } catch (e) {
      setState(() {
        _verifiedName = null;
        
        _verifyError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _showPurchaseSummary() {
    if (!_formKey.currentState!.validate()) return;
    if (_verifiedName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for recipient verification.')),
      );
      return;
    }

    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr) ?? 0.0;
    final currentBalance = getUserBalance(context);

    if (amount > currentBalance) {
      InsufficientFundsSheet.show(context, shortfall: amount - currentBalance);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpicPurchaseSummary(
        title: 'Confirm Transfer',
        subtitle: 'Review transfer details',
        amount: '₦$amountStr',
        primaryColor: const Color(0xFF14B8A6),
        headerIcon: Icons.send_rounded,
        items: [
          SummaryItem(label: 'Recipient', value: _verifiedName!, icon: Icons.person),
          
          SummaryItem(label: 'Amount', value: '₦$amountStr', icon: Icons.account_balance_wallet),
        ],
        onProceedPin: () {
          Navigator.pop(context);
          if (mounted) _executeTransfer(PurchaseAuthService.methodPin);
        },
        onProceedBiometric: () {
          Navigator.pop(context);
          if (mounted) _executeTransfer(PurchaseAuthService.methodBiometric);
        },
      ),
    );
  }

  Future<void> _executeTransfer(String authMethod) async {
    if (_submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final authorized = await PurchaseAuthService.authorizePin(
      context: context,
      reason: 'wallet transfer',
      preferredMethod: authMethod,
    );
    if (!mounted || !authorized) return;

    setState(() => _submitting = true);
    PurchaseLoadingOverlay.show(context, title: 'Processing transfer');

    final amount = _amountController.text.trim();
    final identifier = _identifierController.text.trim();

    try {
      
      final res = await _walletService.performTransfer(identifier, amount);
      if (!mounted) return;
      
      PurchaseLoadingOverlay.hide();
      context.read<SessionController>().refreshBalance();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EpicReceiptModal(
        isSuccess: true,
        title: 'Transfer Successful',
        amount: '₦$amount',
        primaryColor: const Color(0xFF14B8A6),
        details: {
          'Recipient': _verifiedName ?? identifier,
          'Method': 'Wallet Transfer',
          'Reference': res['reference'] ?? 'TRF_SUCCESS',
          'Message': res['message'] ?? 'Funds have been transferred.',
        },
        onSave: () {},
      ));
      
      _identifierController.clear();
      _amountController.clear();
      setState(() {
        _verifiedName = null;
        
      });

    } catch (e) {
      if (!mounted) return;
      PurchaseLoadingOverlay.hide();
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EpicReceiptModal(
        isSuccess: false,
        title: 'Transfer Failed',
        amount: '₦$amount',
        primaryColor: Theme.of(context).colorScheme.error,
        details: {
          'Recipient': identifier,
          'Error': e.toString().replaceAll('Exception: ', ''),
        },
        onSave: () {},
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
      PurchaseLoadingOverlay.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF14B8A6);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Transfer',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Current Balance Card
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Wallet Balance',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                        ),
                      ),
                      const SizedBox(height: 8),
                      Consumer<SessionController>(
                        builder: (context, state, child) {
                          return Text(
                            NumberFormat.currency(symbol: '₦').format(getUserBalance(context)),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: primary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ).animate().fade().slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 32),

                // Recipient Input
                Text(
                  'Send To',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ).animate().fade(delay: 100.ms),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _identifierController,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Username, Phone, or Email',
                    prefixIcon: Icon(Icons.person_search, color: primary),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _isVerifying 
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _verifiedName != null
                            ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
                            : null,
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Please enter a recipient' : null,
                ).animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0),

                if (_verifiedName != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _verifiedName!,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade().scale(),
                ],

                if (_verifyError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _verifyError!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                  ).animate().fade(),
                ],

                const SizedBox(height: 24),

                // Amount Input
                Text(
                  'Amount',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ).animate().fade(delay: 300.ms),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '₦ ',
                    prefixStyle: TextStyle(color: primary, fontSize: 24, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter an amount';
                    final amt = double.tryParse(v);
                    if (amt == null || amt <= 0) return 'Invalid amount';
                    return null;
                  },
                ).animate().fade(delay: 400.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: 48),

                // Submit Button
                ElevatedButton(
                  onPressed: _showPurchaseSummary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: primary.withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    'Transfer Now',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ).animate().fade(delay: 500.ms).slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
