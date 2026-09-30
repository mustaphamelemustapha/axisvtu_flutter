import re

file_path = "/Users/mustaphamelemustapha/Code/VTU/axisvtu_flutter/lib/screens/home_screen.dart"

with open(file_path, "r", encoding='utf-8') as f:
    content = f.read()

# Fix ThemeToggleButton
theme_btn_str = """                          Container(
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
                          ),"""

new_theme_btn_str = """                          ThemeToggleButton(size: 44),"""

content = content.replace(theme_btn_str, new_theme_btn_str)

# Append _ServiceItem
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

if "class _ServiceItem" not in content:
    content += service_item_code

with open(file_path, "w", encoding='utf-8') as f:
    f.write(content)

print("Patch applied!")
