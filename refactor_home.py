import re

file_path = "/Users/mustaphamelemustapha/Code/VTU/axisvtu_flutter/lib/screens/home_screen.dart"

with open(file_path, "r", encoding='utf-8') as f:
    content = f.read()

# I will replace ConcentricCirclesBg down to the end of the services Grid.
start_marker = "    return ConcentricCirclesBg("
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
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6F9),
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: _refresh,
              displacement: 18,
              edgeOffset: 10,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
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
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 22, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              onPressed: () {
                                context.read<ThemeController>().toggle();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Hero Wallet Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
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
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(
                              'Account Balance',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₦',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _hideBalance ? '••••••' : NumberFormat('#,##0.00').format(balance),
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Dedicated Account Number Chip
                        FutureBuilder<Map<String, dynamic>>(
                          future: _accountsFuture,
                          initialData: _cachedAccountsData,
                          builder: (context, snapshot) {
                            final rawAccounts = (snapshot.data?['accounts'] as List?) ?? [];
                            if (rawAccounts.isEmpty) {
                              return GestureDetector(
                                onTap: _showAccountActivationDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.account_balance, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 8),
                                      const Text('Tap to link BVN/NIN', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 13)),
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
                            final bankName = (activeAccount['bank_name'] ?? 'Bank').toString().trim().toUpperCase();
                            final accountNumber = activeAccount['account_number'] ?? '';

                            return GestureDetector(
                              onTap: () => FundWalletSheet.show(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$bankName  •  $accountNumber',
                                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 12),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () => _copyAccountNumber(accountNumber),
                                      child: Icon(Icons.copy_rounded, size: 16, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),
                        // Quick Actions
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => FundWalletSheet.show(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('+ Add Money', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen()));
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFEEF4FF),
                                  foregroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Transfer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (_activeCampaigns.any((c) => !c.isClaimed)) ...[
                    ..._activeCampaigns.where((c) => !c.isClaimed).map((c) => _buildCampaignProgressCard(c)).toList(),
                    const SizedBox(height: 12),
                  ],

                  // Services Grid wrapped in Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Services',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: services.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: compact ? 3 : 4,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 24,
                            childAspectRatio: 0.8,
                          ),
                          itemBuilder: (context, index) {
                            final item = services[index];
                            return _ServiceItem(item: item);
                          },
                        ),
                      ],
                    ),
                  ),

"""

new_content = content[:start_idx] + new_ui + content[end_idx:]

# Also, let's append _ServiceItem class at the end of the file
service_item_code = """

class _ServiceItem extends StatelessWidget {
  final _HomeService item;
  const _ServiceItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = item.accent;
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
"""

if "_ServiceItem" not in new_content:
    new_content += service_item_code

with open(file_path, "w", encoding='utf-8') as f:
    f.write(new_content)

print("home_screen.dart patched successfully!")
