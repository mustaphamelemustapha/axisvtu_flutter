import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/wallet_service.dart';
import '../state/session.dart';

class FundWalletSheet extends StatefulWidget {
  const FundWalletSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const FundWalletSheet(),
    );
  }

  @override
  State<FundWalletSheet> createState() => _FundWalletSheetState();
}

class _FundWalletSheetState extends State<FundWalletSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _accounts = [];
  bool _showAccounts = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) {
      if (mounted) setState(() { _loading = false; _error = 'Not authenticated'; });
      return;
    }

    try {
      final res = await WalletService(token: token).getBankAccounts();
      final List raw = res['accounts'] ?? [];
      
      if (raw.isNotEmpty) {
        final accounts = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        
        accounts.sort((a, b) {
          final aName = (a['bank_name'] ?? '').toString().toLowerCase();
          final bName = (b['bank_name'] ?? '').toString().toLowerCase();
          if (aName.contains('moniepoint') && !bName.contains('moniepoint')) return -1;
          if (!aName.contains('moniepoint') && bName.contains('moniepoint')) return 1;
          return 0;
        });

        if (mounted) {
          setState(() {
            _accounts = accounts;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() { _loading = false; _error = 'No bank accounts found.'; });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Failed to load account details.'; });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account number copied!'), duration: Duration(seconds: 2)),
    );
  }

  void _shareDetails(String bank, String accNum, String accName) {
    final text = 'Please fund my account using these details:\n\nBank: $bank\nAccount Number: $accNum\nAccount Name: $accName';
    Share.share(text);
  }

  String _formatAccountNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\s+'), '');
    if (digits.isEmpty) return '';
    if (digits.length == 10) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 8)} ${digits.substring(8)}';
    }
    return digits;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0x990F172A) : const Color(0x99FFFFFF);
    final cardColor = isDark ? const Color(0x661E293B) : const Color(0x66F8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(isDark ? 0.1 : 0.5))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: textColor, size: 18),
                      ),
                    ),
                    Text(
                      'Fund Wallet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.5),
                    ),
                    const SizedBox(width: 38), // Balance out the title
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Glassy Segment Control
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: textColor.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showAccounts = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _showAccounts ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _showAccounts ? [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
                              ] : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance, size: 16, color: _showAccounts ? textColor : textColor.withOpacity(0.4)),
                                const SizedBox(width: 8),
                                Text(
                                  'Accounts',
                                  style: TextStyle(
                                    color: _showAccounts ? textColor : textColor.withOpacity(0.4),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showAccounts = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_showAccounts ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: !_showAccounts ? [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
                              ] : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.credit_card, size: 16, color: !_showAccounts ? textColor : textColor.withOpacity(0.4)),
                                const SizedBox(width: 8),
                                Text(
                                  'Cards',
                                  style: TextStyle(
                                    color: !_showAccounts ? textColor : textColor.withOpacity(0.4),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _showAccounts ? _buildAccountsList(isDark, cardColor, textColor) : _buildCardsList(textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildAccountsList(bool isDark, Color cardColor, Color textColor) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF1F5F9).withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: textColor.withOpacity(0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: textColor.withOpacity(0.6), size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Transfers to any of these accounts will automatically reflect in your wallet balance.',
                  style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(_accounts.length, (index) {
          return _buildBankCard(_accounts[index], index == 0, isDark, cardColor, textColor);
        }),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCardsList(Color textColor) {
    return Center(
      child: Text(
        'Card funding coming soon.',
        style: TextStyle(color: textColor.withOpacity(0.5)),
      ),
    );
  }

  String _formatBankDisplayName(String rawBank) {
    final b = rawBank.trim();
    final lower = b.toLowerCase();
    if (lower.contains('9psb') || lower.contains('9 payment')) {
      return '9 Payment Service Bank (9PSB)';
    }
    if (lower.contains('safehaven') || lower.contains('safe haven')) {
      return 'Safehaven Microfinance Bank';
    }
    if (lower.contains('moniepoint') || lower.contains('monnify')) {
      return 'Moniepoint Microfinance Bank';
    }
    if (lower.contains('palmpay')) {
      return 'PalmPay';
    }
    if (lower.contains('paga') || lower.contains('aspfiy') || lower.contains('aspify')) {
      return 'Paga';
    }
    if (lower.contains('titan') || lower.contains('paystack')) {
      return 'Titan Trust Bank';
    }
    if (lower.contains('wema')) {
      return 'Wema Bank';
    }
    if (lower.contains('sterling')) {
      return 'Sterling Bank';
    }
    return b;
  }

  Widget _buildBankCard(Map<String, dynamic> account, bool isRecommended, bool isDark, Color cardColor, Color textColor) {
    final rawBank = (account['bank_name'] ?? 'Bank').toString().trim();
    final bankName = _formatBankDisplayName(rawBank);
    final accountNumber = (account['account_number'] ?? '').toString();
    final accountName = (account['account_name'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: textColor.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bank Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BANK NAME',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: textColor.withOpacity(0.55),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bankName,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'AUTOMATED',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF059669),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: textColor.withOpacity(0.08), height: 1),
          const SizedBox(height: 14),

          // Account Number
          Text(
            'ACCOUNT NUMBER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textColor.withOpacity(0.55),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatAccountNumber(accountNumber),
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: textColor,
              fontFamily: 'monospace',
            ),
          ),

          // Account Name
          if (accountName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'ACCOUNT NAME',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: textColor.withOpacity(0.55),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              accountName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor.withOpacity(0.85),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Instructions for local customers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: textColor.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: textColor.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select "$bankName" in your banking app and transfer to this account number.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Copy Number (Soft Blue) | Share Details (Vibrant Green)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _copyToClipboard(accountNumber),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy_rounded, color: Color(0xFF2563EB), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Copy Number',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _shareDetails(bankName, accountNumber, accountName),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ios_share, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Share Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
