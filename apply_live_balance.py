import re

def add_live_balance_feature():
    file_path = "/Users/mustaphamelemustapha/Code/VTU/axisvtu_flutter/lib/screens/home_screen.dart"
    with open(file_path, "r", encoding='utf-8') as f:
        content = f.read()

    # 1. State Variables
    old_state = r"""  bool _dismissedUpdateBanner = false;
  String _dismissedVersionStr = '';

  void _startRefreshTimer() {"""
    new_state = r"""  bool _dismissedUpdateBanner = false;
  String _dismissedVersionStr = '';
  
  double? _previousBalance;
  double _balanceDiff = 0.0;
  bool _showBalanceDiff = false;
  Timer? _balanceDiffTimer;

  void _startRefreshTimer() {"""
    content = content.replace(old_state, new_state)

    # 2. Extract Balance Logic
    old_extract = r"""    final balance = _cachedWalletData != null
        ? _extractBalance(_cachedWalletData)
        : _extractBalance(user);

    final services = <_HomeService>["""
    new_extract = r"""    final currentBalance = _cachedWalletData != null
        ? _extractBalance(_cachedWalletData)
        : _extractBalance(user);

    if (_previousBalance != null && _previousBalance != currentBalance) {
      final diff = currentBalance - _previousBalance!;
      if (diff.abs() > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _balanceDiff = diff;
            _showBalanceDiff = true;
          });
          _balanceDiffTimer?.cancel();
          _balanceDiffTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showBalanceDiff = false);
          });
        });
      }
    }
    _previousBalance = currentBalance;
    final balance = currentBalance;

    final services = <_HomeService>["""
    content = content.replace(old_extract, new_extract)

    # 3. UI Indicator
    old_ui = r"""                                  Text(
                                    decimal,
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ],"""
    new_ui = r"""                                  Text(
                                    decimal,
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),
                                  ),
                                  if (_showBalanceDiff) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _balanceDiff > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _balanceDiff > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                            size: 12,
                                            color: _balanceDiff > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${_balanceDiff > 0 ? '+' : '-'}₦${NumberFormat('#,##0').format(_balanceDiff.abs())}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: _balanceDiff > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],"""
    content = content.replace(old_ui, new_ui)

    with open(file_path, "w", encoding='utf-8') as f:
        f.write(content)

if __name__ == "__main__":
    add_live_balance_feature()
    print("Live balance added!")
