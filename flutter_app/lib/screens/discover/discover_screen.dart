import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/brand.dart';
import '../../providers/providers.dart';
import '../../models/app_user.dart';
import '../profile/profile_screen.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchCtrl = TextEditingController();
  List<AppUser> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await ref.read(userServiceProvider).searchUsers(query);
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: QBrand.fg),
          decoration: InputDecoration(
            hintText: 'Search users...',
            hintStyle: const TextStyle(color: QBrand.fgMute),
            filled: true,
            fillColor: QBrand.cardAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.search, color: QBrand.fgMute),
          ),
          onChanged: _search,
        ),
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty && _searchCtrl.text.isEmpty
              ? _TrendingSection()
              : _results.isEmpty
                  ? const Center(
                      child: Text('No users found', style: TextStyle(color: QBrand.fgMute)),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, i) => _UserTile(user: _results[i]),
                    ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AppUser user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[800],
        backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
        child: user.avatarUrl == null ? const Icon(Icons.person, color: QBrand.fgMute) : null,
      ),
      title: Text(user.displayName, style: const TextStyle(color: QBrand.fg, fontWeight: FontWeight.bold)),
      subtitle: Text('@${user.username}', style: const TextStyle(color: QBrand.fgMute)),
      trailing: Text('${user.followerCount} followers', style: const TextStyle(color: QBrand.fgMute, fontSize: 12)),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
      ),
    );
  }
}

class _TrendingSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveStreams = ref.watch(liveStreamsProvider).valueOrNull ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live Now', style: TextStyle(color: QBrand.fg, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (liveStreams.isEmpty)
            const Text('No live streams', style: TextStyle(color: QBrand.fgMute))
          else
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: liveStreams.take(10).length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final stream = liveStreams[i];
                  return Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: stream.hostAvatarUrl != null
                                ? NetworkImage(stream.hostAvatarUrl!)
                                : null,
                            child: stream.hostAvatarUrl == null
                                ? const Icon(Icons.person, color: QBrand.fgMute)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: QBrand.love,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(stream.hostUsername, style: const TextStyle(color: QBrand.fg, fontSize: 11)),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
