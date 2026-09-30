import re

def update_home_screen():
    file_path = "/Users/mustaphamelemustapha/Code/VTU/axisvtu_flutter/lib/screens/home_screen.dart"
    with open(file_path, "r", encoding='utf-8') as f:
        content = f.read()

    # 1. Update Hero Balance Text and Moniepoint Chip
    content = content.replace(
        "style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: isDark ? Colors.white : const Color(0xFF0F172A)),",
        "style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0A0F1D), letterSpacing: -1.2),"
    )
    content = content.replace(
        "style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),",
        "style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),"
    )

    # 1.b Moniepoint Chip Height & Border/Color
    # Look for the Moniepoint specific chip builder part in home_screen.dart
    old_chip = r"""                            return GestureDetector(
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
                                    ),"""
    new_chip = r"""                            return GestureDetector(
                              onTap: () => FundWalletSheet.show(context),
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      bankName == 'Moniepoint' ? 'Moniepoint MFB' : bankName,
                                      style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    const Spacer(),
                                    Text(
                                      accountNumber,
                                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.6),
                                    ),"""
    content = content.replace(old_chip, new_chip)

    # 2. Fix Services Circle Icons (Make them bolder & tactile)
    # We update _buildTopServiceItem definition
    old_svc_def = r"""  Widget _buildTopServiceItem(
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
                BoxShadow(
                  color: const Color(0x08000000),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 26),"""
    new_svc_def = r"""  Widget _buildTopServiceItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
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
              color: isDark ? const Color(0xFF334155) : bgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x08000000),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 28),"""
    content = content.replace(old_svc_def, new_svc_def)

    # And we update the calls in Services Grid
    old_svc_calls = r"""                      children: [
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
                      ],"""
    new_svc_calls = r"""                      children: [
                        _buildTopServiceItem(
                          context,
                          label: 'Data',
                          icon: Icons.wifi,
                          iconColor: const Color(0xFF1D61F2),
                          bgColor: const Color(0xFFEFF6FF),
                          onTap: () => _openScreen(const DataScreen()),
                        ),
                        _buildTopServiceItem(
                          context,
                          label: 'Airtime',
                          icon: Icons.sim_card_rounded,
                          iconColor: const Color(0xFF16A34A),
                          bgColor: const Color(0xFFF0FDF4),
                          onTap: () => _openScreen(const AirtimeScreen()),
                        ),
                        _buildTopServiceItem(
                          context,
                          label: 'Electricity',
                          icon: Icons.bolt_rounded,
                          iconColor: const Color(0xFFEA580C),
                          bgColor: const Color(0xFFFFF7ED),
                          onTap: () => _openScreen(const ElectricityScreen()),
                        ),
                        _buildTopServiceItem(
                          context,
                          label: 'Cable TV',
                          icon: Icons.tv_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          bgColor: const Color(0xFFF5F3FF),
                          onTap: () => _openScreen(const CableScreen()),
                        ),
                      ],"""
    content = content.replace(old_svc_calls, new_svc_calls)

    # 4. Share Link Action update + import Share
    if "import 'package:share_plus/share_plus.dart';" not in content:
        content = content.replace("import 'package:flutter/services.dart';", "import 'package:flutter/services.dart';\nimport 'package:share_plus/share_plus.dart';")
    
    old_share = r"""                    ElevatedButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: 'https://meledata.ng/register?ref=$referralCode'));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Referral link copied!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },"""
    new_share = r"""                    ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final referralLink = "https://meledata.ng/register?ref=$referralCode";
                        final shareMessage = "Hey! Buy cheap data, airtime, and utility top-ups instantly on MELE DATA. Register using my link: $referralLink";
                        
                        try {
                          await Share.share(
                            shareMessage,
                            subject: "Join MELE DATA",
                          );
                        } catch (e) {
                          await Clipboard.setData(ClipboardData(text: referralLink));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Referral link copied to clipboard!"),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },"""
    content = content.replace(old_share, new_share)

    with open(file_path, "w", encoding='utf-8') as f:
        f.write(content)


def update_shell_screen():
    file_path = "/Users/mustaphamelemustapha/Code/VTU/axisvtu_flutter/lib/screens/shell_screen.dart"
    with open(file_path, "r", encoding='utf-8') as f:
        content = f.read()

    # 3. Floating Pill Bottom Navigation Bar
    old_nav = r"""      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                    _buildNavItem(1, Icons.grid_view_rounded, Icons.grid_view_outlined, 'Services'),
                    _buildNavItem(2, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'History'),
                    _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),"""
    new_nav = r"""      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x0C000000),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                _buildNavItem(1, Icons.grid_view_rounded, Icons.grid_view_outlined, 'Services'),
                _buildNavItem(2, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'History'),
                _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),"""
    content = content.replace(old_nav, new_nav)

    with open(file_path, "w", encoding='utf-8') as f:
        f.write(content)


if __name__ == "__main__":
    update_home_screen()
    update_shell_screen()
    print("Micro-tweaks applied!")
