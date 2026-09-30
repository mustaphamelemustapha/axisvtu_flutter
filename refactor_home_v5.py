import re

file_path = "/Users/mustaphamelemustapha/Code/VTU/axisvtu_flutter/lib/screens/home_screen.dart"

with open(file_path, "r", encoding='utf-8') as f:
    content = f.read()

# 1. Hero Balance Card & Services (Replace from '// Hero Balance Card (Amigo Lite Polish)' to '// Top Services Row Card')
# Wait, my previous script left:
# // Hero Balance Card (Amigo Lite Polish)
# Container(...)
# const SizedBox(height: 24),
# if (_activeCampaigns.any(...))
# // Top Services Row Card
# Container(...)

start_marker_hero = "                  // Hero Balance Card (Amigo Lite Polish)"
end_marker_hero = "                  if (_activeCampaigns.any((c) => !c.isClaimed)) ...["

start_idx_hero = content.find(start_marker_hero)
if start_idx_hero == -1:
    print("Start marker hero not found")
    exit(1)
end_idx_hero = content.find(end_marker_hero, start_idx_hero)
if end_idx_hero == -1:
    print("End marker hero not found")
    exit(1)

new_hero = r"""                  // Hero Balance Card (Amigo Lite Polish)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x06000000),
                          blurRadius: 20,
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
                                  height: 46,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F4F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.account_balance, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 8),
                                      const Text('Tap to link BVN/NIN', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13)),
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
                                height: 46,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F4F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      bankName,
                                      style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13),
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
                                    color: const Color(0xFF1E64F8),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add, color: Colors.white, size: 18),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Balance',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    ],
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
                                    color: isDark ? const Color(0xFF1E64F8).withValues(alpha: 0.15) : const Color(0xFFEEF4FF),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.send_rounded, size: 16, color: Color(0xFF1E64F8)),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Transfer',
                                        style: TextStyle(color: Color(0xFF1E64F8), fontWeight: FontWeight.w700, fontSize: 13),
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
                                  // Feature placeholder
                                },
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F5F9),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.payment_rounded, size: 16, color: isDark ? Colors.white : const Color(0xFF0F172A)),
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
                  
"""
content = content[:start_idx_hero] + new_hero + content[end_idx_hero:]


# 2. Services Grid 
# Replace from '// Top Services Row Card' to 'if (referralCode.isNotEmpty) ...['
start_marker_services = "                  // Top Services Row Card"
end_marker_services = "            if (referralCode.isNotEmpty) ...["

start_idx_srv = content.find(start_marker_services)
end_idx_srv = content.find(end_marker_services, start_idx_srv)

new_services = r"""                  // Top Services Row Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
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
                          iconColor: const Color(0xFF2563EB),
                          onTap: () => _openScreen(const DataScreen()),
                        ),
                        _buildTopServiceItem(
                          context,
                          label: 'Airtime',
                          icon: Icons.sim_card_rounded,
                          iconColor: const Color(0xFF16A34A),
                          onTap: () => _openScreen(const AirtimeScreen()),
                        ),
                        _buildTopServiceItem(
                          context,
                          label: 'Electricity',
                          icon: Icons.bolt_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          onTap: () => _openScreen(const ElectricityScreen()),
                        ),
                        _buildTopServiceItem(
                          context,
                          label: 'Cable TV',
                          icon: Icons.tv_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          onTap: () => _openScreen(const CableScreen()),
                        ),
                      ],
                    ),
                  ),

"""
content = content[:start_idx_srv] + new_services + content[end_idx_srv:]

# 3. Fix `_buildTopServiceItem` method to match new tactile icon buttons.
# We will use regex to replace the entire method.

service_item_pattern = re.compile(
    r"  Widget _buildTopServiceItem\(.*?\).*?return GestureDetector\(.*?\}\n    \);\n  \}",
    re.DOTALL
)

new_service_item_code = """  Widget _buildTopServiceItem(
    BuildContext context, {
    required String label,
    required IconData icon,
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
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0x08000000), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }"""

content = service_item_pattern.sub(new_service_item_code, content)

# 4. Referral Banner
# Find `if (referralCode.isNotEmpty) ...[` down to `            ],` followed by `            const SizedBox(height: 24),`
ref_pattern = re.compile(r"            if \(referralCode\.isNotEmpty\) \.\.\.\[.*?            \],\n", re.DOTALL)

new_referral = r"""            if (referralCode.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0x06000000), blurRadius: 15, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.group_add_rounded, size: 16, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Invite friends & earn bonus',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: 'https://meledata.ng/register?ref=$referralCode'));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Referral link copied!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Share Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
"""
content = ref_pattern.sub(new_referral, content)

with open(file_path, "w", encoding='utf-8') as f:
    f.write(content)

print("Patch v5 applied!")
