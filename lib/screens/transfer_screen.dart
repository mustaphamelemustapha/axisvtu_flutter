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
import '../services/dashboard_snapshot_cache.dart';
import '../state/session.dart';
import '../utils/balance_util.dart';
import '../widgets/bvn_nin_activation_dialog.dart';
import '../widgets/pin_entry_sheet.dart';
import '../widgets/epic_purchase_summary.dart';
import '../widgets/glass_card.dart';
import '../widgets/insufficient_funds_sheet.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../widgets/epic_receipt_modal.dart';
import '../widgets/bank_standard_receipt_modal.dart';

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
  bool _hasVerifiedVirtualAccounts = false;

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
      _checkKycAndAccounts();
    }
  }

  void _checkKycAndAccounts() {
    try {
      final session = context.read<SessionController>();
      final identity = DashboardSnapshotCache.identityFromUser(session.user);
      if (identity != null) {
        final snap = DashboardSnapshotCache.loadSync(identity);
        final accs = (snap?['accounts']?['accounts'] as List?) ?? [];
        if (_accountsProveKyc(accs)) {
          setState(() => _hasVerifiedVirtualAccounts = true);
          session.updateUserField('kyc_verified', true);
          return;
        }
      }

      _walletService.getBankAccounts().then((res) {
        final accs = (res['accounts'] as List?) ?? [];
        if (_accountsProveKyc(accs) && mounted) {
          setState(() => _hasVerifiedVirtualAccounts = true);
          session.updateUserField('kyc_verified', true);
        }
      }).catchError((_) {});
    } catch (_) {}
  }

  bool _accountsProveKyc(List accs) {
    for (final a in accs) {
      final name = (a['bank_name'] ?? '').toString().toLowerCase();
      if (name.contains('moniepoint') ||
          name.contains('palmpay') ||
          name.contains('monnify') ||
          name.contains('safehaven')) {
        return true;
      }
    }
    return false;
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

  static const List<Map<String, dynamic>> _defaultBanks = [
    {'name': 'Access Bank', 'code': '044', 'slug': 'access-bank'},
    {'name': 'Guaranty Trust Bank (GTBank)', 'code': '058', 'slug': 'guaranty-trust-bank'},
    {'name': 'Zenith Bank', 'code': '057', 'slug': 'zenith-bank'},
    {'name': 'United Bank for Africa (UBA)', 'code': '033', 'slug': 'united-bank-for-africa'},
    {'name': 'First Bank of Nigeria', 'code': '011', 'slug': 'first-bank-of-nigeria'},
    {'name': 'OPay (Paycom)', 'code': '999992', 'slug': 'paycom'},
    {'name': 'PalmPay', 'code': '999991', 'slug': 'palmpay'},
    {'name': 'Moniepoint MFB', 'code': '50515', 'slug': 'moniepoint-mfb-ng'},
    {'name': 'Kuda Bank', 'code': '50211', 'slug': 'kuda-bank'},
    {'name': 'Fidelity Bank', 'code': '070', 'slug': 'fidelity-bank'},
    {'name': 'Stanbic IBTC Bank', 'code': '221', 'slug': 'stanbic-ibtc-bank'},
    {'name': 'Sterling Bank', 'code': '232', 'slug': 'sterling-bank'},
    {'name': 'Union Bank of Nigeria', 'code': '032', 'slug': 'union-bank-of-nigeria'},
    {'name': 'Wema Bank (ALAT)', 'code': '035', 'slug': 'wema-bank'},
    {'name': 'First City Monument Bank (FCMB)', 'code': '214', 'slug': 'first-city-monument-bank'},
    {'name': 'Polaris Bank', 'code': '076', 'slug': 'polaris-bank'},
    {'name': 'Keystone Bank', 'code': '082', 'slug': 'keystone-bank'},
    {'name': 'Jaiz Bank', 'code': '301', 'slug': 'jaiz-bank'},
    {'name': 'TAJ Bank', 'code': '302', 'slug': 'taj-bank'},
    {'name': 'VFD Microfinance Bank', 'code': '566', 'slug': 'vfd'},
    {'name': 'FairMoney Microfinance Bank', 'code': '51318', 'slug': 'fairmoney-mfb'},
    {'name': 'Rubies MFB', 'code': '125', 'slug': 'rubies-mfb'},
    {'name': 'Carbon', 'code': '565', 'slug': 'carbon'},
    {'name': 'Titan Trust Bank', 'code': '102', 'slug': 'titan-bank'},
    {'name': 'Providus Bank', 'code': '101', 'slug': 'providus-bank'},
  ];

  // ---------------------------------------------------------------------------
  // BANK WITHDRAWAL LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _loadBanks() async {
    setState(() {
      _banks = List.from(_defaultBanks);
      _loadingBanks = true;
    });
    try {
      final list = await _walletService.getBanks();
      if (mounted && list.isNotEmpty) {
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
      final code = _selectedBank?['code']?.toString() ?? '';
      if (code.isNotEmpty) {
        _resolveBankAccount(text, code);
      }
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
    final bankName = _selectedBank?['name']?.toString() ?? 'Bank';
    final accNum = _accountNumberController.text.trim();
    final beneficiary = _resolvedAccountName ?? 'Account Holder';

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
          SummaryItem(label: 'Beneficiary', value: beneficiary, icon: Icons.person_rounded),
          SummaryItem(label: 'Destination Bank', value: bankName, icon: Icons.account_balance_rounded),
          SummaryItem(label: 'Account Number', value: accNum, icon: Icons.tag_rounded),
          if (_narrationController.text.trim().isNotEmpty)
            SummaryItem(label: 'Description', value: _narrationController.text.trim(), icon: Icons.notes_rounded),
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

    final double amount = double.tryParse(_bankAmountController.text.trim()) ?? 0.0;
    final String accNum = _accountNumberController.text.trim();
    final String bankCode = _selectedBank?['code']?.toString() ?? '';
    final String bankName = _selectedBank?['name']?.toString() ?? 'Bank';
    final String beneficiary = _resolvedAccountName ?? 'Account Holder';
    final String narration = _narrationController.text.trim();

    try {
      final res = await _walletService.withdrawToBank(
        accountNumber: accNum,
        bankCode: bankCode,
        bankName: bankName,
        accountName: beneficiary,
        amount: amount,
        pin: pin,
        narration: narration.isNotEmpty ? narration : null,
      );

      if (!mounted) return;
      PurchaseLoadingOverlay.hide();
      context.read<SessionController>().refreshBalance();

      final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
      final double feeNum = double.tryParse(res['fee']?.toString() ?? '') ?? (amount <= 5000.0 ? 25.0 : 50.0);
      final double totalDebitedNum = double.tryParse(res['total_debited']?.toString() ?? '') ?? (amount + feeNum);
      final String refStr = res['reference']?.toString() ?? 'TRF_SUCCESS';
      final String msgStr = res['message']?.toString() ?? 'Funds are en route to your bank account.';

      final userName = context.read<SessionController>().user?['full_name']?.toString() ?? 'MELE DATA Customer';
      final String? sessionId = res['session_id']?.toString();
      final String? provRef = res['provider_reference']?.toString();
      DateTime? txTime;
      if (res['created_at'] != null) {
        txTime = DateTime.tryParse(res['created_at'].toString())?.toLocal();
      }

      // Clear input fields safely
      _accountNumberController.clear();
      _bankAmountController.clear();
      _narrationController.clear();
      setState(() {
        _resolvedAccountName = null;
        _selectedBank = null;
      });

      // Show Bank-Standard Receipt Modal
      BankStandardReceiptModal.show(
        context,
        isSuccess: true,
        amount: currency.format(amount),
        fee: currency.format(feeNum),
        totalDebited: currency.format(totalDebitedNum),
        beneficiaryName: beneficiary,
        destinationBank: bankName,
        accountNumber: accNum,
        senderName: userName,
        narration: narration.isNotEmpty ? narration : 'Transfer to $beneficiary',
        reference: refStr,
        providerReference: provRef,
        sessionId: sessionId,
        timestamp: txTime ?? DateTime.now(),
        message: msgStr,
      );
    } catch (e) {
      if (!mounted) return;
      PurchaseLoadingOverlay.hide();

      final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
      final double feeNum = amount <= 5000.0 ? 25.0 : 50.0;
      final double totalDebitedNum = amount + feeNum;

      BankStandardReceiptModal.show(
        context,
        isSuccess: false,
        amount: currency.format(amount),
        fee: currency.format(feeNum),
        totalDebited: currency.format(totalDebitedNum),
        beneficiaryName: beneficiary,
        destinationBank: bankName,
        accountNumber: accNum,
        reference: 'FAIL_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        message: e.toString().replaceAll('Exception: ', '').replaceAll('ApiException: ', ''),
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
        (user['nin_hash'] != null && user['nin_hash'].toString().isNotEmpty) ||
        _hasVerifiedVirtualAccounts;

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
                        setState(() {
                          _hasVerifiedVirtualAccounts = true;
                        });
                        session.updateUserField('kyc_verified', true);
                        session.syncProfileIfNeeded();
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
                      _selectedBank?['name']?.toString() ??
                          (_loadingBanks ? 'Loading banks...' : 'Choose destination bank'),
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
              hintText: 'Account Number',
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

          // Verified Beneficiary Banner (OPay / Moniepoint Style)
          if (_resolvedAccountName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACCOUNT HOLDER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _resolvedAccountName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fade().scale(begin: const Offset(0.97, 0.97)),
          ],

          if (_bankResolveError != null) ...[
            const SizedBox(height: 10),
            Text(
              _bankResolveError!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ).animate().fade(),
          ],

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Withdrawal Amount',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Min ₦100 • Max ₦100,000',
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              prefixText: '₦ ',
              prefixStyle: TextStyle(color: primary, fontSize: 24, fontWeight: FontWeight.w900),
              hintText: '0.00',
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

          const SizedBox(height: 20),

          Text(
            'Description (Optional)',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          TextFormField(
            controller: _narrationController,
            maxLength: 50,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'What is this transfer for? (Optional)',
              hintStyle: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              prefixIcon: Icon(Icons.notes_rounded, color: primary),
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
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
// SEARCHABLE BANK SELECTOR MODAL BOTTOM SHEET (OPay / Moniepoint style)
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

  static const List<Map<String, String>> _popularBanks = [
    {'name': 'OPay (Paycom)', 'code': '999992', 'abbr': 'OP', 'color': '0xFF00B875'},
    {'name': 'PalmPay', 'code': '999991', 'abbr': 'PL', 'color': '0xFF4F46E5'},
    {'name': 'Moniepoint MFB', 'code': '50515', 'abbr': 'MP', 'color': '0xFF0284C7'},
    {'name': 'Kuda Bank', 'code': '50211', 'abbr': 'KU', 'color': '0xFF7C3AED'},
    {'name': 'Guaranty Trust Bank', 'code': '058', 'abbr': 'GT', 'color': '0xFFEA580C'},
    {'name': 'Zenith Bank', 'code': '057', 'abbr': 'ZN', 'color': '0xFFDC2626'},
    {'name': 'Access Bank', 'code': '044', 'abbr': 'AC', 'color': '0xFFF59E0B'},
    {'name': 'United Bank for Africa', 'code': '033', 'abbr': 'UB', 'color': '0xFFB91C1C'},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _getBankColor(String name) {
    final colors = [
      const Color(0xFF0284C7),
      const Color(0xFF00B875),
      const Color(0xFF4F46E5),
      const Color(0xFFEA580C),
      const Color(0xFFDC2626),
      const Color(0xFF7C3AED),
      const Color(0xFF0D9488),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final filtered = widget.banks.where((b) {
      if (b is! Map) return false;
      final name = (b['name'] ?? '').toString().toLowerCase();
      final code = (b['code'] ?? '').toString();
      final q = _filter.toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Bank',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose destination bank or fintech',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search bank name or code...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                prefixIcon: Icon(Icons.search_rounded, size: 22, color: primary),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (val) => setState(() => _filter = val.trim()),
            ),
          ),

          // Popular Banks Horizontal Carousel (when search is empty)
          if (_filter.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Text(
                'POPULAR BANKS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _popularBanks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, idx) {
                  final pop = _popularBanks[idx];
                  final popColor = Color(int.parse(pop['color']!));
                  final isSelected = widget.selectedBank?['code']?.toString() == pop['code'];

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      final found = widget.banks.firstWhere(
                        (b) => b is Map && b['code']?.toString() == pop['code'],
                        orElse: () => {'name': pop['name'], 'code': pop['code']},
                      );
                      widget.onSelect(Map<String, dynamic>.from(found as Map));
                      Navigator.pop(context);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: popColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? popColor : popColor.withValues(alpha: 0.35),
                              width: isSelected ? 2.5 : 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              pop['abbr']!,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: popColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 64,
                          child: Text(
                            pop['name']!.split(' ')[0],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? primary : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 18),
          ],

          // All Banks List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text(
                          'No matching banks found',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, index) {
                      final bank = filtered[index] as Map<String, dynamic>;
                      final bName = bank['name']?.toString() ?? '';
                      final bCode = bank['code']?.toString() ?? '';
                      final isSelected = widget.selectedBank?['code']?.toString() == bCode;
                      final bColor = _getBankColor(bName);
                      final initials = _getInitials(bName);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: bColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: bColor.withValues(alpha: 0.25)),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: TextStyle(
                                color: bColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          bName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 14.5,
                            color: isSelected ? primary : theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: bCode.isNotEmpty
                            ? Text(
                                'Bank Code: $bCode',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 14),
                              )
                            : Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onTap: () {
                          HapticFeedback.selectionClick();
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
