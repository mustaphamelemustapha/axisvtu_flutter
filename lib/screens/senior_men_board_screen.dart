import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../services/leaderboard_service.dart';
import '../widgets/concentric_circles_bg.dart';
import '../widgets/glass_card.dart';

class SeniorMenBoardScreen extends StatefulWidget {
  const SeniorMenBoardScreen({super.key});

  @override
  State<SeniorMenBoardScreen> createState() => _SeniorMenBoardScreenState();
}

class _SeniorMenBoardScreenState extends State<SeniorMenBoardScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _topUsers = [];
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = context.read<SessionController>();
      final service = LeaderboardService(token: session.token);
      final resp = await service.getLeaderboard();
      
      if (mounted) {
        setState(() {
          _topUsers = resp['top_users'] ?? [];
          _currentUser = resp['current_user'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatRank(int rank) {
    if (rank == 1) return '1st';
    if (rank == 2) return '2nd';
    if (rank == 3) return '3rd';
    return '${rank}th';
  }

  Widget _buildAvatar(String? imageUrl, String username, {double radius = 24}) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: Icon(
        Icons.smart_toy_rounded, // Robot icon as per screenshot
        size: radius * 1.2,
        color: const Color(0xFFF97316),
      ),
    );
  }

  Widget _buildPodiumColumn(Map<String, dynamic>? user, int rank, double height, Color color) {
    if (user == null) {
      return SizedBox(
        width: 100,
        height: height + 80,
      );
    }
    
    return Flexible(
      flex: rank == 1 ? 4 : 3,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                child: _buildAvatar(user['profile_image_url'], user['username'], radius: rank == 1 ? 32 : 26),
              ),
              if (rank == 1)
                const Positioned(
                  top: -8,
                  right: -8,
                  child: Icon(Icons.workspace_premium_rounded, color: Color(0xFFFACC15), size: 28),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '${user['username']}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: double.infinity,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.8),
                      color,
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Top oval to simulate 3D cylinder
              Container(
                width: double.infinity,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.all(Radius.elliptical(50, 10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    final first = _topUsers.isNotEmpty ? _topUsers[0] : null;
    final second = _topUsers.length > 1 ? _topUsers[1] : null;
    final third = _topUsers.length > 2 ? _topUsers[2] : null;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: SizedBox(
        height: 280,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildPodiumColumn(second, 2, 120, const Color(0xFFFDBA74)),
            _buildPodiumColumn(first, 1, 160, const Color(0xFFFED7AA)),
            _buildPodiumColumn(third, 3, 90, const Color(0xFFFB923C)),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentUserCard() {
    if (_currentUser == null) return const SizedBox.shrink();

    final rank = _currentUser!['rank'] as int;
    final rankStr = rank > 50 ? 'Unranked' : _formatRank(rank);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildAvatar(_currentUser!['profile_image_url'], _currentUser!['username']),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  children: [
                    TextSpan(text: '${_currentUser!['username']} '),
                    const TextSpan(
                      text: '(You)',
                      style: TextStyle(color: Color(0xFFEA580C)),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFED7AA).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                rankStr,
                style: const TextStyle(
                  color: Color(0xFFEA580C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_topUsers.length <= 3) return const SizedBox.shrink();
    final remaining = _topUsers.sublist(3);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: remaining.length,
        separatorBuilder: (_, __) => const Divider(height: 32, color: Colors.black12),
        itemBuilder: (context, index) {
          final user = remaining[index];
          final rank = user['rank'] as int;
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                child: _buildAvatar(user['profile_image_url'], user['username']),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${user['username']}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFED7AA).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatRank(rank),
                  style: const TextStyle(
                    color: Color(0xFFEA580C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3ED), // Very light peach/orange background
      body: ConcentricCirclesBg(
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chevron_left_rounded, size: 24),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Senior men Board',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _fetchData,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.refresh_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_error!, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchData,
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                _buildPodium(),
                                _buildCurrentUserCard(),
                                _buildList(),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
