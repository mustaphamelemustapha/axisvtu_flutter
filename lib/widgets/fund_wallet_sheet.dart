import 'package:flutter/material.dart';
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
    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: TextStyle(color: Colors.blue.shade600, fontSize: 16),
                  ),
                ),
                Text(
                  'Add Balance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.1),
                  ),
                  child: Icon(Icons.add, color: Colors.blue.shade600, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showAccounts = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _showAccounts ? Colors.blue.shade600 : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance, size: 16, color: _showAccounts ? Colors.white : Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Accounts',
                              style: TextStyle(
                                color: _showAccounts ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.bold,
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_showAccounts ? Colors.blue.shade600 : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.credit_card, size: 16, color: !_showAccounts ? Colors.white : Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Cards',
                              style: TextStyle(
                                color: !_showAccounts ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.bold,
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
          const SizedBox(height: 20),
          Expanded(
            child: _showAccounts ? _buildAccountsList(isDark, cardColor, textColor) : _buildCardsList(textColor),
          ),
        ],
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
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.campaign, color: Color(0xFFD97706)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Send money to any of the listed accounts via bank transfer, and it will reflect in your wallet.',
                  style: TextStyle(color: Color(0xFF92400E), fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.close, size: 16, color: const Color(0xFF92400E).withOpacity(0.5)),
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

  Widget _buildBankCard(Map<String, dynamic> account, bool isRecommended, bool isDark, Color cardColor, Color textColor) {
    final rawBank = (account['bank_name'] ?? 'Bank').toString().trim();
    final bankName = rawBank.toLowerCase().contains('titan') || rawBank.toLowerCase().contains('paystack')
        ? 'Paystack-Titan'
        : rawBank.toLowerCase().contains('moniepoint')
            ? 'Moniepoint MFB'
            : rawBank;
    final accountNumber = (account['account_number'] ?? '').toString();
    final accountName = (account['account_name'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.account_balance, color: textColor.withOpacity(0.7), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                bankName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Recommended',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Add money via mobile or internet banking',
            style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            _formatAccountNumber(accountNumber),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: textColor,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _copyToClipboard(accountNumber),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy_rounded, color: Colors.blue.shade600, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Copy Number',
                          style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.bold),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
