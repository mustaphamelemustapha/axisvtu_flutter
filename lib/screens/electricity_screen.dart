import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/services_service.dart';
import '../state/session.dart';
import 'electricity_meter_screen.dart';

class ElectricityProvider {
  final String discoId;
  final String name;
  final String type; // prepaid or postpaid
  final String imagePath;

  ElectricityProvider({
    required this.discoId,
    required this.name,
    required this.type,
    required this.imagePath,
  });
}

class ElectricityScreen extends StatefulWidget {
  const ElectricityScreen({super.key});

  @override
  State<ElectricityScreen> createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends State<ElectricityScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<ElectricityProvider> _allProviders = [];
  List<ElectricityProvider> _filteredProviders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _getDiscoImage(String disco) {
    switch (disco.toLowerCase()) {
      case 'ikeja': return 'assets/images/discos/ikeja.png';
      case 'eko': return 'assets/images/discos/eko.png';
      case 'abuja': return 'assets/images/discos/abuja.png';
      case 'kano': return 'assets/images/discos/kano.png';
      case 'ibadan': return 'assets/images/discos/ibadan.png';
      case 'enugu': return 'assets/images/discos/enugu.png';
      case 'portharcourt': return 'assets/images/discos/ph.png';
      case 'kaduna': return 'assets/images/discos/kaduna.png';
      case 'jos': return 'assets/images/discos/jos.png';
      case 'aba': return 'assets/images/discos/aba.png';
      case 'benin': return 'assets/images/discos/benin.png';
      default: return 'assets/images/discos/default.png';
    }
  }

  String _formatDiscoName(String disco) {
    final mapping = {
      'ikeja': 'Ikeja Electricity Distribution',
      'eko': 'Eko Electricity Distribution',
      'abuja': 'Abuja Electricity Distribution',
      'kano': 'Kano Electricity Distribution',
      'ibadan': 'Ibadan Electricity Distribution',
      'enugu': 'Enugu Electricity Distribution',
      'portharcourt': 'Port-Harcourt Electricity Distribution',
      'kaduna': 'Kaduna Electricity Distribution',
      'jos': 'Jos Electricity Distribution',
      'aba': 'Aba Electricity Distribution',
      'benin': 'Benin Electricity Distribution Company (BEDC)',
    };
    return mapping[disco.toLowerCase()] ?? disco.toUpperCase();
  }

  Future<void> _loadCatalog() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    
    try {
      final data = await ServicesService(token: token).getCatalog();
      final raw = data['electricity_discos'];
      
      List<ElectricityProvider> providers = [];
      if (raw is List && raw.isNotEmpty) {
        for (var e in raw) {
          final disco = e.toString().trim().toLowerCase();
          if (disco.isNotEmpty) {
            providers.add(ElectricityProvider(
              discoId: disco,
              name: '${_formatDiscoName(disco)} Postpaid',
              type: 'postpaid',
              imagePath: _getDiscoImage(disco),
            ));
            providers.add(ElectricityProvider(
              discoId: disco,
              name: '${_formatDiscoName(disco)} Prepaid',
              type: 'prepaid',
              imagePath: _getDiscoImage(disco),
            ));
          }
        }
      }
      
      // If backend failed to return discos, provide fallbacks
      if (providers.isEmpty) {
        final fallbacks = ['aba', 'abuja', 'benin', 'eko', 'enugu', 'ibadan', 'ikeja', 'jos', 'kaduna', 'kano', 'portharcourt'];
        for (var disco in fallbacks) {
            providers.add(ElectricityProvider(
              discoId: disco,
              name: '${_formatDiscoName(disco)} Postpaid',
              type: 'postpaid',
              imagePath: _getDiscoImage(disco),
            ));
            providers.add(ElectricityProvider(
              discoId: disco,
              name: '${_formatDiscoName(disco)} Prepaid',
              type: 'prepaid',
              imagePath: _getDiscoImage(disco),
            ));
        }
      }

      // Sort alphabetically like screenshot
      providers.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _allProviders = providers;
          _filteredProviders = providers;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onSearch() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProviders = _allProviders;
      } else {
        _filteredProviders = _allProviders.where((p) {
          return p.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _selectProvider(ElectricityProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ElectricityMeterScreen(provider: provider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F141E) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Electricity',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.receipt_long, color: Theme.of(context).primaryColor),
            onPressed: () {}, // Optional: history
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2638) : const Color(0xFFEBEFF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search all billers',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            
            Expanded(
              child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredProviders.length,
                    itemBuilder: (context, index) {
                      final p = _filteredProviders[index];
                      // Simulate the "Temporarily unavailable" for BEDC/Abuja Postpaid from screenshot just for UX, or leave normal.
                      // The screenshot had Abuja Postpaid and BEDC Postpaid as unavailable. We will just render them normal.
                      
                      return InkWell(
                        onTap: () => _selectProvider(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF1E2638) : Colors.white,
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)
                                  ),
                                ),
                                child: ClipOval(
                                  // Use standard Icons if image missing, else try load image
                                  child: Icon(Icons.electrical_services, color: isDark ? Colors.white54 : Colors.grey, size: 24),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: isDark ? Colors.white54 : Colors.black45,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
