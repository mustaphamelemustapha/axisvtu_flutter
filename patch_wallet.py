file_path = "/Users/mustaphamelemustapha/Code/VTU/axisvtu_flutter/lib/screens/home_screen.dart"
with open(file_path, "r", encoding='utf-8') as f:
    lines = f.readlines()

# Lines to replace: 1693 to 2337 (0-indexed: 1692 to 2337)
start_idx = 1692
end_idx = 2337

new_wallet_code = r"""            // THE MASTERPIECE: Unified Wallet Card
            GestureDetector(
              onTap: () {
                FundWalletSheet.show(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.3 : 0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Total Balance',
                                  style: TextStyle(
                                    color: heroSoftText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _toggleBalanceVisibility,
                                  child: Icon(
                                    _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 16,
                                    color: heroSoftText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '₦',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: heroText,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  _hideBalance ? '••••' : NumberFormat('#,##0.00').format(balance),
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                    color: heroText,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Live reading subscript
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_upward_rounded, size: 12, color: Colors.green),
                              const SizedBox(width: 2),
                              const Text(
                                '+₦0.00', // TODO: Calculate live from today's transactions
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Action Buttons inside the card
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionPill(
                            context,
                            icon: Icons.add_rounded,
                            label: 'Fund Wallet',
                            onTap: () {
                              FundWalletSheet.show(context);
                            },
                            primary: true,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionPill(
                            context,
                            icon: Icons.send_rounded,
                            label: 'Transfer',
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen()));
                            },
                            primary: false,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1), height: 1),
                    const SizedBox(height: 16),
                    // Bank Account Details (Primary Account)
                    FutureBuilder<Map<String, dynamic>>(
                      future: _accountsFuture,
                      initialData: _cachedAccountsData,
                      builder: (context, snapshot) {
                        final data = snapshot.data;
                        final rawAccounts = (data?['accounts'] as List?) ?? [];
                        
                        if (rawAccounts.isEmpty) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                              ),
                            );
                          }
                          return GestureDetector(
                            onTap: _showAccountActivationDialog,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.account_balance_rounded, color: Colors.blue, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Generate Bank Account', style: TextStyle(color: heroText, fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('Tap to link BVN/NIN', style: TextStyle(color: heroSoftText, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                              ],
                            ),
                          );
                        }
                        
                        final accounts = List<Map<String, dynamic>>.from(
                          rawAccounts.map((item) => Map<String, dynamic>.from(item as Map))
                        );

                        // Prioritize Moniepoint, Wema, etc.
                        accounts.sort((a, b) {
                          final aName = (a['bank_name'] ?? '').toString().toLowerCase();
                          final bName = (b['bank_name'] ?? '').toString().toLowerCase();
                          if (aName.contains('moniepoint') && !bName.contains('moniepoint')) return -1;
                          if (!aName.contains('moniepoint') && bName.contains('moniepoint')) return 1;
                          return 0;
                        });

                        final activeAccount = accounts.first;
                        final bankName = (activeAccount['bank_name'] ?? 'Bank').toString().trim().toUpperCase();
                        final accountNumber = activeAccount['account_number'] ?? '';
                        String rawName = (activeAccount['account_name'] ?? "").toString().trim();
                        final prefixPattern = RegExp(r'^(?:MMTECHGLOBE|MELE DATA)(?:\s*[-\/:]\s*|\s+)?', caseSensitive=False) if hasattr(re, 'IGNORECASE') else None; # we can't use python's re inside dart string! Let's correct this.
"""

# Wait, I had python string interpolation or something above. Let me fix the dart string block!

new_wallet_code = r"""            // THE MASTERPIECE: Unified Wallet Card
            GestureDetector(
              onTap: () {
                FundWalletSheet.show(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.3 : 0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Total Balance',
                                  style: TextStyle(
                                    color: heroSoftText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _toggleBalanceVisibility,
                                  child: Icon(
                                    _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    size: 16,
                                    color: heroSoftText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '₦',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: heroText,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  _hideBalance ? '••••' : NumberFormat('#,##0.00').format(balance),
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                    color: heroText,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Live reading subscript
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_upward_rounded, size: 12, color: Colors.green),
                              const SizedBox(width: 2),
                              const Text(
                                '+₦0.00', // TODO: Calculate live from today's transactions
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Action Buttons inside the card
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionPill(
                            context,
                            icon: Icons.add_rounded,
                            label: 'Fund Wallet',
                            onTap: () {
                              FundWalletSheet.show(context);
                            },
                            primary: true,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionPill(
                            context,
                            icon: Icons.send_rounded,
                            label: 'Transfer',
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen()));
                            },
                            primary: false,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1), height: 1),
                    const SizedBox(height: 16),
                    // Bank Account Details (Primary Account)
                    FutureBuilder<Map<String, dynamic>>(
                      future: _accountsFuture,
                      initialData: _cachedAccountsData,
                      builder: (context, snapshot) {
                        final data = snapshot.data;
                        final rawAccounts = (data?['accounts'] as List?) ?? [];
                        
                        if (rawAccounts.isEmpty) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                              ),
                            );
                          }
                          return GestureDetector(
                            onTap: _showAccountActivationDialog,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.account_balance_rounded, color: Colors.blue, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Generate Bank Account', style: TextStyle(color: heroText, fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('Tap to link BVN/NIN', style: TextStyle(color: heroSoftText, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                              ],
                            ),
                          );
                        }
                        
                        final accounts = List<Map<String, dynamic>>.from(
                          rawAccounts.map((item) => Map<String, dynamic>.from(item as Map))
                        );

                        // Prioritize Moniepoint, Wema, etc.
                        accounts.sort((a, b) {
                          final aName = (a['bank_name'] ?? '').toString().toLowerCase();
                          final bName = (b['bank_name'] ?? '').toString().toLowerCase();
                          if (aName.contains('moniepoint') && !bName.contains('moniepoint')) return -1;
                          if (!aName.contains('moniepoint') && bName.contains('moniepoint')) return 1;
                          return 0;
                        });

                        final activeAccount = accounts.first;
                        final bankName = (activeAccount['bank_name'] ?? 'Bank').toString().trim().toUpperCase();
                        final accountNumber = activeAccount['account_number'] ?? '';
                        String rawName = (activeAccount['account_name'] ?? name).toString().trim();
                        final prefixPattern = RegExp(r'^(?:MMTECHGLOBE|MELE DATA)(?:\s*[-\/:]\s*|\s+)?', caseSensitive: false);
                        String cleanName = rawName.replaceFirst(prefixPattern, '').trim();
                        if (cleanName.isEmpty) cleanName = rawName;
                        final accountName = 'MMTECHGLOBE / $cleanName';

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          bankName,
                                          style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                      if (accounts.length > 1) ...[
                                        const SizedBox(width: 8),
                                        Text('+${accounts.length - 1} more', style: TextStyle(color: heroSoftText, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatAccountNumber(accountNumber),
                                    style: TextStyle(color: heroText, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    accountName,
                                    style: TextStyle(color: heroSoftText, fontSize: 11, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _copyAccountNumber(accountNumber),
                              icon: Icon(Icons.copy_rounded, size: 20, color: heroSoftText),
                              tooltip: 'Copy Account Number',
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
"""

new_lines = lines[:start_idx] + [new_wallet_code + "\n"] + lines[end_idx:]

with open(file_path, "w", encoding='utf-8') as f:
    f.writelines(new_lines)

print("File patched successfully by line index!")
