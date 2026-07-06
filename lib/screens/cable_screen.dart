import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/services_service.dart';
import '../state/session.dart';
import 'cable_details_screen.dart';
import '../widgets/mele_data_loader.dart';


class CableProvider {
  final String id;
  final String name;

  CableProvider({required this.id, required this.name});
}

class CableScreen extends StatefulWidget {
  const CableScreen({super.key});

  @override
  State<CableScreen> createState() => _CableScreenState();
}

class _CableScreenState extends State<CableScreen> {
  bool _loading = false;
  List<CableProvider> _providers = [
    CableProvider(id: 'dstv', name: 'DSTV'),
    CableProvider(id: 'gotv', name: 'GOTV'),
    CableProvider(id: 'startimes', name: 'Startimes'),
    CableProvider(id: 'showmax', name: 'ShowMax TV'),
  ];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    if (mounted) setState(() => _loading = true);
    
    try {
      final data = await ServicesService(token: token).getCatalog();
      final raw = data['cable_providers'];
      if (raw is List && raw.isNotEmpty) {
        final providers = <CableProvider>[];
        for (final item in raw) {
          if (item is Map) {
            final id = (item['id'] ?? '').toString().trim().toLowerCase();
            final name = (item['name'] ?? id).toString().trim();
            if (id.isNotEmpty) {
              providers.add(CableProvider(
                id: id,
                name: name.isEmpty ? id.toUpperCase() : name,
              ));
            }
          }
        }
        if (mounted && providers.isNotEmpty) {
          setState(() => _providers = providers);
        }
      }
    } catch (_) {
      // Keep defaults if failed
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildProviderIcon(String id) {
    if (id == 'dstv') {
      return Image.asset('assets/images/dstv.png', width: 36, height: 36, errorBuilder: (c,e,s) => const Icon(Icons.tv, color: Color(0xFF0073C5)));
    } else if (id == 'gotv') {
      return Image.asset('assets/images/gotv.png', width: 36, height: 36, errorBuilder: (c,e,s) => const Icon(Icons.tv, color: Color(0xFF00A859)));
    } else if (id == 'startimes') {
      return Image.asset('assets/images/startimes.png', width: 36, height: 36, errorBuilder: (c,e,s) => const Icon(Icons.tv, color: Color(0xFFFFA500)));
    } else if (id == 'showmax') {
      return Image.asset('assets/images/showmax.png', width: 36, height: 36, errorBuilder: (c,e,s) => const Icon(Icons.tv, color: Color(0xFFE50914)));
    }
    return const Icon(Icons.live_tv_rounded, color: Colors.blueAccent);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _providers
        .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F141E) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Cable TV',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.receipt_long_rounded, color: isDark ? Colors.white : Colors.black, size: 22),
            onPressed: () {},
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                'Select Biller',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2638) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isDark ? [] : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: _loading && _providers.length == 4 // Default length
                      ? const Center(child: MeleDataLoader(size: 80.0))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            thickness: 1,
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                            indent: 72,
                          ),
                          itemBuilder: (context, index) {
                            final provider = filtered[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: _buildProviderIcon(provider.id),
                                ),
                              ),
                              title: Text(
                                provider.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).primaryColor,
                                size: 20,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CableDetailsScreen(provider: provider),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),);
  }
}
