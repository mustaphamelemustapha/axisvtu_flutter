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
      builder: (context) => const FundWalletSheet(),
    );
  }

  @override
  State<FundWalletSheet> createState() => _FundWalletSheetState();
}

class _FundWalletSheetState extends State<FundWalletSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _account;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
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
        
        // Prioritize Moniepoint if available, otherwise first
        accounts.sort((a, b) {
          final aName = (a['bank_name'] ?? '').toString().toLowerCase();
          final bName = (b['bank_name'] ?? '').toString().toLowerCase();
          if (aName.contains('moniepoint') && !bName.contains('moniepoint')) return -1;
          if (!aName.contains('moniepoint') && bName.contains('moniepoint')) return 1;
          return 0;
        });

        if (mounted) {
          setState(() {
            _account = accounts.first;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Add money',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share bank details to add money to this account',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              )
            else ...[
              _buildAccountCard(isDark),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      color: isDark ? const Color(0xFF2A344A) : const Color(0xFFF3F4F6),
                      textColor: isDark ? Colors.blue.shade400 : Colors.blue.shade700,
                      onTap: () => _copyToClipboard((_account?['account_number'] ?? '').toString()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildButton(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      color: Colors.blue.shade600,
                      textColor: Colors.white,
                      onTap: () {
                        final bank = (_account?['bank_name'] ?? 'Bank').toString().toUpperCase();
                        final accNum = (_account?['account_number'] ?? '').toString();
                        final name = (_account?['account_name'] ?? '').toString().toUpperCase();
                        _shareDetails(bank, accNum, name);
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(bool isDark) {
    final rawBank = (_account?['bank_name'] ?? 'Bank').toString().trim();
    final bankName = rawBank.toLowerCase().contains('titan') || rawBank.toLowerCase().contains('paystack')
        ? 'PAYSTACK TITAN'
        : rawBank.toLowerCase().contains('moniepoint')
            ? 'MONIEPOINT MFB'
            : rawBank.toLowerCase().contains('wema')
                ? 'WEMA BANK'
                : rawBank.toLowerCase().contains('sterling')
                    ? 'STERLING BANK'
                    : rawBank.toUpperCase();
                    
    final accountNumber = (_account?['account_number'] ?? '').toString();
    
    // Format account holder name nicely
    final name = context.read<SessionController>().user?['full_name']?.toString() ?? 'User';
    String rawName = (_account?['account_name'] ?? name).toString().trim();
    final prefixPattern = RegExp(
      r'^(?:MMTECHGLOBE|MELE DATA)(?:\s*[-\/:]\s*|\s+)?',
      caseSensitive: false,
    );
    String cleanName = rawName.replaceFirst(prefixPattern, '').trim();
    if (cleanName.isEmpty) cleanName = rawName;
    final accountName = 'MMTECHGLOBE / $cleanName'.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A344A) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            bankName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            accountNumber,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            accountName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
