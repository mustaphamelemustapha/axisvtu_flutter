import os
import re

filepath = '/Users/mustaphamelemustapha/Code/VTU/axisvtu_flutter/lib/widgets/fund_wallet_sheet.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Add dart:ui import if not present
if "import 'dart:ui';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'dart:ui';")

# Replace build method
build_pattern = r"  @override\n  Widget build\(BuildContext context\) \{.*?(?=  Widget _buildAccountsList)"
build_replacement = """  @override
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
"""

content = re.sub(build_pattern, build_replacement, content, flags=re.DOTALL)

# Refactor the info banner in _buildAccountsList
banner_pattern = r"        Container\(\n          padding: const EdgeInsets.all\(16\),\n          decoration: BoxDecoration\(\n            color: const Color\(0xFFFEF3C7\),\n            borderRadius: BorderRadius.circular\(16\),\n          \),\n          child: Row\(.*?const SizedBox\(width: 8\),\n              Icon\(Icons.close, size: 16, color: const Color\(0xFF92400E\)\.withOpacity\(0\.5\)\),\n            \],\n          \),\n        \),"
banner_replacement = """        Container(
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
        ),"""

content = re.sub(banner_pattern, banner_replacement, content, flags=re.DOTALL)

# Refactor the bank card in _buildBankCard
card_pattern = r"    return Container\(\n      margin: const EdgeInsets.only\(bottom: 16\),\n      padding: const EdgeInsets.all\(20\),\n      decoration: BoxDecoration\(\n        color: cardColor,\n        borderRadius: BorderRadius.circular\(20\),\n        boxShadow: \[\n          BoxShadow\(\n            color: Colors.black.withOpacity\(0.03\),\n            blurRadius: 10,\n            offset: const Offset\(0, 4\),\n          \),\n        \],\n      \),\n      child: Column\(.*?\]\),\n    \);"
card_replacement = """    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(isDark ? 0.05 : 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
                  ]
                ),
                child: Icon(Icons.account_balance_outlined, color: textColor.withOpacity(0.7), size: 18),
              ),
              const SizedBox(width: 14),
              Text(
                bankName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const Spacer(),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Recommended',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Account Number',
            style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _formatAccountNumber(accountNumber),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Name',
                    style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    accountName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _copyToClipboard(accountNumber),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.copy_rounded, size: 18, color: textColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _shareDetails(bankName, accountNumber, accountName),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.share_rounded, size: 18, color: textColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );"""

content = re.sub(card_pattern, card_replacement, content, flags=re.DOTALL)

with open(filepath, 'w') as f:
    f.write(content)

print("Fund wallet sheet refactored successfully.")
