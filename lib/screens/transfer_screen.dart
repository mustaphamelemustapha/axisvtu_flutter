import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../config/brand_config.dart';
import '../services/wallet_service.dart';
import '../services/purchase_auth_service.dart';
import '../state/session.dart';
import '../utils/balance_util.dart';
import '../widgets/bvn_nin_activation_dialog.dart';
import '../widgets/pin_entry_sheet.dart';
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
  // Tab 0 = To Bank Account (Paystack, Mele Data only)
  // Tab 1 = To User Wallet (P2P)
  int _selectedTab = 0;

  // P2P Wallet Transfer Controllers
  final _p2pFormKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _p2pAmountController = TextEditingController();
  bool _isVerifyingP2P = false;
  String? _verifiedP2PName;
  String? _p2pVerifyError;
  Timer? _p2pDebounce;

  // Bank Withdrawal Controllers
  final _bankFormKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _bankAmountController = TextEditingController();
  final _narrationController = TextEditingController();

  List<dynamic> _banks = [];
  bool _loadingBanks = false;
  Map<String, dynamic>? _selectedBank;
  bool _isResolvingBank = false;
  String? _resolvedAccountName;
  String? _bankResolveError;
  Timer? _bankDebounce;

  bool _submitting = false;

  WalletService get _walletService =>
      WalletService(token: context.read<SessionController>().token ?? '');

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(_onP2PIdentifierChanged);
    _accountNumberController.addListener(_onAccountNumberChanged);

    final isMeleData = BrandConfig.current.brand == AppBrand.meleData;
    _selectedTab = isMeleData ? 0 : 1;

    if (isMeleData) {
      _loadBanks();
    }
  }

  @override
  void dispose() {
    _identifierController.removeListener(_onP2PIdentifierChanged);
    _accountNumberController.removeListener(_onAccountNumberChanged);
    _identifierController.dispose();
    _p2pAmountController.dispose();
    _accountNumberController.dispose();
    _bankAmountController.dispose();
    _narrationController.dispose();
    _p2pDebounce?.cancel();
    _bankDebounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BANK WITHDRAWAL LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _loadBanks() async {
    setState(() => _loadingBanks = true);
    try {
      final list = await _walletService.getBanks();
      if (mounted) {
        setState(() {
          _banks = list;
          _loadingBanks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  void _onAccountNumberChanged() {
    if (_bankDebounce?.isActive ?? false) _bankDebounce?.cancel();

    final text = _accountNumberController.text.replaceAll(RegExp(r'\D'), '').trim();
    if (text.length != 10 || _selectedBank == null) {
      setState(() {
        _resolvedAccountName = null;
        _bankResolveError = null;
      });
      return;
    }

    _bankDebounce = Timer(const Duration(milliseconds: 450), () {
      _resolveBankAccount(text, _selectedBank!['code']?.toString() ?? '');
    });
  }

  Future<void> _resolveBankAccount(String accountNumber, String bankCode) async {
    setState(() {
      _isResolvingBank = true;
      _bankResolveError = null;
      _resolvedAccountName = null;
    });

    try {
      final res = await _walletService.resolveBankAccount(accountNumber, bankCode);
      if (mounted) {
        setState(() {
          _resolvedAccountName = res['account_name'];
          _isResolvingBank = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resolvedAccountName = null;
          _bankResolveError = e.toString().replaceAll('Exception: ', '');
          _isResolvingBank = false;
        });
      }
    }
  }

  void _openBankSelectorSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _BankSelectorModal(
          banks: _banks,
          selectedBank: _selectedBank,
          onSelect: (bank) {
            setState(() {
              _selectedBank = bank;
              _resolvedAccountName = null;
              _bankResolveError = null;
            });
            final acc = _accountNumberController.text.replaceAll(RegExp(r'\D'), '').trim();
            if (acc.length == 10) {
              _resolveBankAccount(acc, bank['code']?.toString() ?? '');
            }
          },
        );
      },
    );
  }

  void _showBankWithdrawalSummary() {
    if (!_bankFormKey.currentState!.validate()) return;
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination bank.')),
      );
      return;
    }
    if (_resolvedAccountName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for account name verification.')),
      );
      return;
    }

    final amountStr = _bankAmountController.text.trim();
    final amount = double.tryParse(amountStr) ?? 0.0;
    if (amount < 100.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum withdrawal amount is ₦100.00')),
      );
      return;
    }
    if (amount > 100000.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum withdrawal amount per transaction is ₦100,000.00')),
      );
      return;
    }

    // Fee structure: <= 5000 -> 25, > 5000 -> 50
    final fee = amount <= 5000.0 ? 25.0 : 50.0;
    final totalDebit = amount + fee;
    final currentBalance = getUserBalance(context);

    if (totalDebit > currentBalance) {
      InsufficientFundsSheet.show(context, shortfall: totalDebit - currentBalance);
      return;
    }

    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final bankName = _selectedBank!['name']?.toString() ?? 'Bank';
    final accNum = _accountNumberController.text.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpicPurchaseSummary(
        title: 'Confirm Bank Withdrawal',
        subtitle: 'Review transfer destination & fee',
        amount: currency.format(amount),
        primaryColor: const Color(0xFF0B4FD2),
        headerIcon: Icons.account_balance_rounded,
        items: [
          SummaryItem(label: 'Beneficiary', value: _resolvedAccountName!, icon: Icons.person_rounded),
          SummaryItem(label: 'Destination Bank', value: bankName, icon: Icons.account_balance_rounded),
          SummaryItem(label: 'Account Number', value: accNum, icon: Icons.tag_rounded),
          SummaryItem(label: 'Transfer Fee', value: currency.format(fee), icon: Icons.receipt_long_rounded),
          SummaryItem(label: 'Total Debit', value: currency.format(totalDebit), icon: Icons.wallet_rounded),
        ],
        onProceedPin: () {
          Navigator.pop(context);
          if (mounted) _executeBankWithdrawal();
        },
        onProceedBiometric: () {
          Navigator.pop(context);
          if (mounted) _executeBankWithdrawal();
        },
      ),
    );
  }

  Future<void> _executeBankWithdrawal() async {
    if (_submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final pin = await PinEntrySheet.show(
      context,
      title: 'Authorize Withdrawal',
      subtitle: 'Enter your 4-digit PIN to withdraw funds',
      confirmLabel: 'Confirm & Withdraw',
      pinLength: 4,
    );
    if (pin == null || pin.isEmpty || !mounted) return;

    setState(() => _submitting = true);
    PurchaseLoadingOverlay.show(context, title: 'Processing bank withdrawal');

    final amount = double.tryParse(_bankAmountController.text.trim()) ?? 0.0;
    final accNum = _accountNumberController.text.trim();
    final bankCode = _selectedBank!['code']?.toString() ?? '';
    final bankName = _selectedBank!['name']?.toString() ?? '';
    final narration = _narrationController.text.trim();

    try {
      final res = await _walletService.withdrawToBank(
        accountNumber: accNum,
        bankCode: bankCode,
        bankName: bankName,
        accountName: _resolvedAccountName!,
        amount: amount,
        pin: pin,
        narration: narration.isNotEmpty ? narration : null,
      );

      if (!mounted) return;
      PurchaseLoadingOverlay.hide();
      context.read<SessionController>().refreshBalance();

      final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EpicReceiptModal(
          isSuccess: true,
          title: 'Withdrawal Initiated',
          amount: currency.format(amount),
          primaryColor: const Color(0xFF10B981),
          details: {
            'Beneficiary': _resolvedAccountName!,
            'Bank': bankName,
            'Account Number': accNum,
            'Reference': res['reference'] ?? 'TRF_SUCCESS',
            'Transfer Fee': currency.format(res['fee'] ?? 25.0),
            'Total Debited': currency.format(res['total_debited'] ?? (amount + 25.0)),
            'Message': res['message'] ?? 'Funds are en route to your bank account.',
          },
          onSave: () {},
        ),
      );

      _accountNumberController.clear();
      _bankAmountController.clear();
      _narrationController.clear();
      setState(() {
        _resolvedAccountName = null;
        _selectedBank = null;
      });
    } catch (e) {
      if (!mounted) return;
      PurchaseLoadingOverlay.hide();

      final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EpicReceiptModal(
          isSuccess: false,
          title: 'Withdrawal Failed',
          amount: currency.format(amount),
          primaryColor: Theme.of(context).colorScheme.error,
          details: {
            'Destination': '$bankName - $accNum',
            'Beneficiary': _resolvedAccountName ?? '—',
            'Reason': e.toString().replaceAll('Exception: ', ''),
          },
          onSave: () {},
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
      PurchaseLoadingOverlay.hide();
    }
  }

  // ---------------------------------------------------------------------------
  // P2P WALLET TRANSFER LOGIC
  // ---------------------------------------------------------------------------
  void _onP2PIdentifierChanged() {
    if (_p2pDebounce?.isActive ?? false) _p2pDebounce?.cancel();

    final text = _identifierController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _verifiedP2PName = null;
        _p2pVerifyError = null;
      });
      return;
    }

    _p2pDebounce = Timer(const Duration(milliseconds: 700), () {
      _verifyP2PRecipient(text);
    });
  }

  Future<void> _verifyP2PRecipient(String identifier) async {
    setState(() {
      _isVerifyingP2P = true;
      _p2pVerifyError = null;
    });

    try {
      final res = await _walletService.verifyTransferRecipient(identifier);
      if (mounted) {
        setState(() {
          _verifiedP2PName = res['full_name'];
          _isVerifyingP2P = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifiedP2PName = null;
          _p2pVerifyError = e.toString().replaceAll('Exception: ', '');
          _isVerifyingP2P = false;
        });
      }
    }
  }

  void _showP2PSummary() {
    if (!_p2pFormKey.currentState!.validate()) return;
    if (_verifiedP2PName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for recipient verification.')),
      );
      return;
    }

    final amountStr = _p2pAmountController.text.trim();
    final amount = double.tryParse(amountStr) ?? 0.0;
    final currentBalance = getUserBalance(context);

    if (amount > currentBalance) {
      InsufficientFundsSheet.show(context, shortfall: amount - currentBalance);
      return;
    }

    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpicPurchaseSummary(
        title: 'Confirm Wallet Transfer',
        subtitle: 'Review transfer details',
        amount: currency.format(amount),
        primaryColor: const Color(0xFF14B8A6),
        headerIcon: Icons.send_rounded,
        items: [
          SummaryItem(label: 'Recipient', value: _verifiedP2PName!, icon: Icons.person_rounded),
          SummaryItem(label: 'Transfer Type', value: 'Instant Wallet to Wallet', icon: Icons.sync_alt_rounded),
          SummaryItem(label: 'Fee', value: '₦0.00 (Free)', icon: Icons.verified_rounded),
        ],
        onProceedPin: () {
          Navigator.pop(context);
          if (mounted) _executeP2PTransfer(PurchaseAuthService.methodPin);
        },
        onProceedBiometric: () {
          Navigator.pop(context);
          if (mounted) _executeP2PTransfer(PurchaseAuthService.methodBiometric);
        },
      ),
    );
  }

  Future<void> _executeP2PTransfer(String authMethod) async {
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

    final amount = _p2pAmountController.text.trim();
    final identifier = _identifierController.text.trim();

    try {
      final res = await _walletService.performTransfer(identifier, amount);
      if (!mounted) return;

      PurchaseLoadingOverlay.hide();
      context.read<SessionController>().refreshBalance();

      final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EpicReceiptModal(
          isSuccess: true,
          title: 'Transfer Successful',
          amount: currency.format(double.tryParse(amount) ?? 0),
          primaryColor: const Color(0xFF14B8A6),
          details: {
            'Recipient': _verifiedP2PName ?? identifier,
            'Method': 'Wallet to Wallet',
            'Reference': res['reference'] ?? 'TRF_SUCCESS',
            'Message': res['message'] ?? 'Funds have been credited instantly.',
          },
          onSave: () {},
        ),
      );

      _identifierController.clear();
      _p2pAmountController.clear();
      setState(() => _verifiedP2PName = null);
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
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
      PurchaseLoadingOverlay.hide();
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD METHOD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMeleData = BrandConfig.current.brand == AppBrand.meleData;

    final session = context.watch<SessionController>();
    final user = session.user ?? {};
    final isKycVerified = user['kyc_verified'] == true ||
        user['has_bvn'] == true ||
        user['has_nin'] == true ||
        (user['bvn_hash'] != null && user['bvn_hash'].toString().isNotEmpty) ||
        (user['nin_hash'] != null && user['nin_hash'].toString().isNotEmpty);

    final primaryThemeColor = theme.colorScheme.primary;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          centerTitle: true,
          title: Text(
            isMeleData ? 'Transfer & Withdraw' : 'Wallet Transfer',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current Balance Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Available Wallet Balance',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer<SessionController>(
                      builder: (context, state, child) {
                        return Text(
                          NumberFormat.currency(symbol: '₦', decimalDigits: 2).format(getUserBalance(context)),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: primaryThemeColor,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ).animate().fade().slideY(begin: 0.08, end: 0),

              const SizedBox(height: 20),

              // Segmented Tab Switcher (On Mele Data: Bank vs Wallet)
              if (isMeleData) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 0),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTab == 0
                                  ? theme.colorScheme.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _selectedTab == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.account_balance_rounded,
                                    size: 16,
                                    color: _selectedTab == 0
                                        ? primaryThemeColor
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'To Bank Account',
                                    style: TextStyle(
                                      fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w600,
                                      color: _selectedTab == 0
                                          ? primaryThemeColor
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 1),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTab == 1
                                  ? theme.colorScheme.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _selectedTab == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 16,
                                    color: _selectedTab == 1
                                        ? primaryThemeColor
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'To User Wallet',
                                    style: TextStyle(
                                      fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w600,
                                      color: _selectedTab == 1
                                          ? primaryThemeColor
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ---------------------------------------------------------------
              // TAB 0: TO BANK ACCOUNT (WITH KYC GATING)
              // ---------------------------------------------------------------
              if (isMeleData && _selectedTab == 0) ...[
                if (!isKycVerified)
                  _buildKycGatedCard(theme, isDark, session)
                else
                  _buildBankWithdrawalForm(theme, isDark),
              ] else ...[
                // ---------------------------------------------------------------
                // TAB 1: TO USER WALLET (P2P)
                // ---------------------------------------------------------------
                _buildP2PForm(theme, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KYC GATED CARD
  // ---------------------------------------------------------------------------
  Widget _buildKycGatedCard(ThemeData theme, bool isDark, SessionController session) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Color(0xFFF59E0B),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Account Verification Required',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Account verification is required before making a withdrawal. Link your NIN or BVN to activate withdrawal and virtual account services.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black26 : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Instant automatic approval upon 11-digit verification.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Go back / switch tab
                    setState(() => _selectedTab = 1);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    BvnNinActivationDialog.show(
                      context,
                      onActivated: () {
                        session.syncProfileIfNeeded();
                        setState(() {});
                      },
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Verify Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade().scale();
  }

  // ---------------------------------------------------------------------------
  // BANK WITHDRAWAL FORM
  // ---------------------------------------------------------------------------
  Widget _buildBankWithdrawalForm(ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;
    final amountVal = double.tryParse(_bankAmountController.text.trim()) ?? 0.0;
    final fee = amountVal > 0 ? (amountVal <= 5000.0 ? 25.0 : 50.0) : 0.0;
    final totalDebit = amountVal > 0 ? amountVal + fee : 0.0;

    return Form(
      key: _bankFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select Bank',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Bank Selector Box
          InkWell(
            onTap: _openBankSelectorSheet,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedBank != null
                      ? primary.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_rounded, color: primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedBank != null
                          ? _selectedBank!['name']?.toString() ?? ''
                          : (_loadingBanks ? 'Loading banks...' : 'Choose destination bank'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: _selectedBank != null ? FontWeight.bold : FontWeight.normal,
                        color: _selectedBank != null
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Account Number',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 10-Digit Account Number Input
          TextFormField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            decoration: InputDecoration(
              counterText: '',
              hintText: '10-digit NUBAN number',
              prefixIcon: Icon(Icons.pin_rounded, color: primary),
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _isResolvingBank
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _resolvedAccountName != null
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                      : null,
            ),
            validator: (v) {
              if (v == null || v.trim().length != 10) return 'Enter 10-digit account number';
              return null;
            },
          ),

          // Verified Beneficiary Banner
          if (_resolvedAccountName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VERIFIED ACCOUNT NAME',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _resolvedAccountName!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fade().scale(),
          ],

          if (_bankResolveError != null) ...[
            const SizedBox(height: 10),
            Text(
              _bankResolveError!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ).animate().fade(),
          ],

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Withdrawal Amount',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Min ₦100 • Max ₦100k',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          TextFormField(
            controller: _bankAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: '₦ ',
              prefixStyle: TextStyle(color: primary, fontSize: 22, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter an amount';
              final amt = double.tryParse(v);
              if (amt == null || amt < 100) return 'Minimum withdrawal is ₦100.00';
              if (amt > 100000) return 'Maximum withdrawal is ₦100,000.00';
              return null;
            },
          ),

          const SizedBox(height: 10),

          // Quick Amount Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final preset in [1000, 2000, 5000, 10000, 20000, 50000])
                  Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      label: Text('+₦${NumberFormat('#,##0').format(preset)}'),
                      onPressed: () {
                        _bankAmountController.text = preset.toString();
                        setState(() {});
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                ActionChip(
                  label: const Text('Max', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final bal = getUserBalance(context);
                    final maxPossible = (bal - 50.0).clamp(0.0, 100000.0);
                    _bankAmountController.text = maxPossible.toInt().toString();
                    setState(() {});
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: primary.withValues(alpha: 0.12),
                  labelStyle: TextStyle(color: primary),
                ),
              ],
            ),
          ),

          // Fee Breakdown Card
          if (amountVal > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transfer Fee (${amountVal <= 5000 ? '≤ ₦5k' : '> ₦5k'}):',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      Text(
                        '₦${fee.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Wallet Deduction:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₦${NumberFormat('#,##0.00').format(totalDebit)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: totalDebit > getUserBalance(context)
                              ? theme.colorScheme.error
                              : primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _showBankWithdrawalSummary,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: const Text(
              'Withdraw to Bank',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // P2P FORM
  // ---------------------------------------------------------------------------
  Widget _buildP2PForm(ThemeData theme, bool isDark) {
    final primary = const Color(0xFF14B8A6);

    return Form(
      key: _p2pFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recipient Identifier',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          TextFormField(
            controller: _identifierController,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Username, Phone, or Email',
              prefixIcon: Icon(Icons.person_search_rounded, color: primary),
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _isVerifyingP2P
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _verifiedP2PName != null
                      ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
                      : null,
            ),
            validator: (v) => v == null || v.isEmpty ? 'Please enter a recipient' : null,
          ),

          if (_verifiedP2PName != null) ...[
            const SizedBox(height: 10),
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
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _verifiedP2PName!,
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ).animate().fade().scale(),
          ],

          if (_p2pVerifyError != null) ...[
            const SizedBox(height: 10),
            Text(
              _p2pVerifyError!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ).animate().fade(),
          ],

          const SizedBox(height: 20),

          Text(
            'Amount',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          TextFormField(
            controller: _p2pAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: '₦ ',
              prefixStyle: TextStyle(color: primary, fontSize: 22, fontWeight: FontWeight.bold),
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
          ),

          const SizedBox(height: 36),

          ElevatedButton(
            onPressed: _showP2PSummary,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: const Text(
              'Transfer Instantly',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SEARCHABLE BANK SELECTOR MODAL BOTTOM SHEET
// -----------------------------------------------------------------------------
class _BankSelectorModal extends StatefulWidget {
  const _BankSelectorModal({
    required this.banks,
    required this.selectedBank,
    required this.onSelect,
  });

  final List<dynamic> banks;
  final Map<String, dynamic>? selectedBank;
  final ValueChanged<Map<String, dynamic>> onSelect;

  @override
  State<_BankSelectorModal> createState() => _BankSelectorModalState();
}

class _BankSelectorModalState extends State<_BankSelectorModal> {
  final _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = widget.banks.where((b) {
      if (b is! Map) return false;
      final name = (b['name'] ?? '').toString().toLowerCase();
      final code = (b['code'] ?? '').toString();
      final q = _filter.toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Destination Bank',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search Field
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search bank name or code...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) => setState(() => _filter = val.trim()),
          ),

          const SizedBox(height: 14),

          // Bank List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching banks found.',
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final bank = filtered[index] as Map<String, dynamic>;
                      final isSelected = widget.selectedBank?['code']?.toString() == bank['code']?.toString();
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.account_balance, color: theme.colorScheme.primary, size: 18),
                        ),
                        title: Text(
                          bank['name']?.toString() ?? '',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                            : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: () {
                          widget.onSelect(bank);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
