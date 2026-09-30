import re

file_path = "/Users/mustaphamelemustapha/Code/VTU/axisvtu_flutter/lib/screens/home_screen.dart"

with open(file_path, "r", encoding='utf-8') as f:
    content = f.read()

# I will replace the main UI chunk starting at `return Container(` down to the end of the services container `if (_activeCampaigns.any((c) => !c.isClaimed)) ...[` or the `Container(` for Services.
# Let's locate `return Container(`
start_marker = "    return Container("
end_marker = "            if (referralCode.isNotEmpty) ...["

start_idx = content.find(start_marker)
if start_idx == -1:
    print("Start marker not found")
    exit(1)

end_idx = content.find(end_marker, start_idx)
if end_idx == -1:
    print("End marker not found")
    exit(1)

new_ui = r"""    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA),
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: _refresh,
              displacement: 18,
              edgeOffset: 10,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                children: [
                  // Minimalist Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: profileImageUrl != null && profileImageUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(profileImageUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            child: profileImageUrl != null && profileImageUrl.isNotEmpty ? null : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${name.split(" ").first}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'MELE DATA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(Icons.notifications_outlined, size: 22, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              onPressed: _openNotificationsCenter,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ThemeToggleButton(size: 44),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Hero Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x08000000),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Account Balance',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _toggleBalanceVisibility,
                              child: Icon(
                                _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final rawBalance = NumberFormat('0.00').format(balance);
                            final parts = rawBalance.split('.');
                            final whole = parts[0];
                            final decimal = parts.length > 1 ? '.${parts[1]}' : '.00';
                            
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '₦',
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 4),
                                if (_hideBalance)
                                  Text(
                                    '••••••',
                                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  )
                                else ...[
                                  Text(
                                    NumberFormat('#,##0').format(int.tryParse(whole) ?? 0),
                                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    decimal,
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ],
                            );
                          }
                        ),
                        const SizedBox(height: 20),
                        
                        // Virtual Account Chip
                        FutureBuilder<Map<String, dynamic>>(
                          future: _accountsFuture,
                          initialData: _cachedAccountsData,
                          builder: (context, snapshot) {
                            final rawAccounts = (snapshot.data?['accounts'] as List?) ?? [];
                            if (rawAccounts.isEmpty) {
                              return GestureDetector(
                                onTap: _showAccountActivationDialog,
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.account_balance, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 8),
                                      const Text('Tap to link BVN/NIN', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 14)),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            final accounts = List<Map<String, dynamic>>.from(rawAccounts.map((i) => Map<String, dynamic>.from(i as Map)));
                            accounts.sort((a, b) {
                              final aName = (a['bank_name'] ?? '').toString().toLowerCase();
                              final bName = (b['bank_name'] ?? '').toString().toLowerCase();
                              if (aName.contains('moniepoint') && !bName.contains('moniepoint')) return -1;
                              if (!aName.contains('moniepoint') && bName.contains('moniepoint')) return 1;
                              return 0;
                            });

                            final activeAccount = accounts.first;
                            final bankName = (activeAccount['bank_name'] ?? 'Bank').toString().trim();
                            final accountNumber = activeAccount['account_number'] ?? '';

                            return GestureDetector(
                              onTap: () => FundWalletSheet.show(context),
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      bankName,
                                      style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    const Spacer(),
                                    Text(
                                      accountNumber,
                                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _copyAccountNumber(accountNumber),
                                      child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),
                        // Quick Action Buttons Row
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => FundWalletSheet.show(context),
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1D61F2),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '+ Balance',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen())),
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1D61F2).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.send_rounded, size: 14, color: Color(0xFF1D61F2)),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Transfer',
                                        style: TextStyle(color: Color(0xFF1D61F2), fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // Can route to scan/pay if implemented, or just a placeholder.
                                },
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.qr_code_scanner_rounded, size: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Pay',
                                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13),
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
                  ),

                  const SizedBox(height: 24),

                  if (_activeCampaigns.any((c) => !c.isClaimed)) ...[
                    ..._activeCampaigns.where((c) => !c.isClaimed).map((c) => _buildCampaignProgressCard(c)).toList(),
                    const SizedBox(height: 12),
                  ],

                  // Top Services Row Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x04000000),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTopServiceItem(
                          context,
                          label: 'Data',
                          icon: Icons.wifi_rounded,
                          bgColor: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                          iconColor: const Color(0xFF2563EB),
                          onTap: () => _openScreen(const DataScreen()),
                        ),
                        _buildTopServiceItem(
                          context,
                          label: 'Airtime',
                          icon: Icons.phone_iphone_rounded,
                          bgColor: isDark ? const Color(0xFF16A34A).withValues(alpha: 0.15) : const Color(0xFFF0FDF4),
                          iconColor: const Color(0xFF16A34A),
                          onTap: () => _openScreen(const AirtimeScreen()),
                        ),
                        _buildTopServiceItem(
                          context,
                          label: 'Electricity',
                          icon: Icons.bolt_rounded,
                          bgColor: isDark ? const Color(0xFFD97706).withValues(alpha: 0.15) : const Color(0xFFFFFBEB),
                          iconColor: const Color(0xFFD97706),
                          onTap: () => _openScreen(const ElectricityScreen()),
                        ),
                        _buildTopServiceItem(
                          context,
                          label: 'Cable TV',
                          icon: Icons.live_tv_rounded,
                          bgColor: isDark ? const Color(0xFF9333EA).withValues(alpha: 0.15) : const Color(0xFFFAF5FF),
                          iconColor: const Color(0xFF9333EA),
                          onTap: () => _openScreen(const CableScreen()),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Secondary Services Row Card (Exam Pins, Referrals, etc.)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x04000000),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(width: 16),
                        _buildTopServiceItem(
                          context,
                          label: 'Exam Pins',
                          icon: Icons.school_rounded,
                          bgColor: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.15) : const Color(0xFFFEF2F2),
                          iconColor: const Color(0xFFDC2626),
                          onTap: () => _openScreen(const ExamScreen()),
                        ),
                        const SizedBox(width: 32),
                        _buildTopServiceItem(
                          context,
                          label: 'Referrals',
                          icon: Icons.card_giftcard_rounded,
                          bgColor: isDark ? const Color(0xFFDB2777).withValues(alpha: 0.15) : const Color(0xFFFDF2F8),
                          iconColor: const Color(0xFFDB2777),
                          onTap: () => _openScreen(const ReferralScreen()),
                        ),
                      ],
                    ),
                  ),

"""

new_content = content[:start_idx] + new_ui + content[end_idx:]

service_item_code = """
  Widget _buildTopServiceItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: bgColor,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
"""

# Let's place `_buildTopServiceItem` method inside the `_HomeScreenState` class.
# Let's just insert it before `Widget build(BuildContext context)` which is right before `new_ui`.

build_marker = "  Widget build(BuildContext context) {"
build_idx = new_content.find(build_marker)
if build_idx != -1:
    new_content = new_content[:build_idx] + service_item_code + "\n" + new_content[build_idx:]
else:
    print("Could not find build method")

with open(file_path, "w", encoding='utf-8') as f:
    f.write(new_content)

print("Patch v3 applied!")
