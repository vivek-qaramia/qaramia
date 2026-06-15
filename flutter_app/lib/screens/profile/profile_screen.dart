import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/providers.dart';
import '../../models/app_user.dart';
import '../../models/streamer_stats.dart';
import '../../models/video.dart';
import '../../theme/brand.dart';
import '../../widgets/system_panel.dart';
import '../feed/feed_screen.dart' show VideoCard;
import '../studio/ads_screen.dart';
import '../../widgets/wallet_badge.dart';

// Self profile (uses current auth user)
class ProfileScreenSelf extends ConsumerWidget {
  const ProfileScreenSelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: QBrand.primary)),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('$e')),
      ),
      data: (user) => user == null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👤', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 16),
                      const Text(
                        'Profile not loaded',
                        style: TextStyle(color: QBrand.fg, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Something went wrong reading your account. Try retrying or signing back in.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: QBrand.fgMute, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(currentUserProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => ref.read(authServiceProvider).signOut(),
                        icon: const Icon(Icons.logout, color: QBrand.fgMute),
                        label: const Text('Sign out',
                            style: TextStyle(color: QBrand.fgMute)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ProfileScreen(uid: user.uid),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(uid));
    final videosAsync = ref.watch(userVideosProvider(uid));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isSelf = currentUser?.uid == uid;

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: QBrand.primary)),
        error: (e, _) => Center(child: Text('$e')),
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: Text('@${user.username}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                actions: [
                  if (isSelf) ...[
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Center(child: WalletBadge()),
                    ),
                    IconButton(
                      tooltip: 'Manage ads',
                      icon: const Icon(Icons.campaign_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdsScreen()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => ref.read(authServiceProvider).signOut(),
                    ),
                  ],
                ],
              ),
              SliverToBoxAdapter(
                child: _ProfileHeader(user: user, isSelf: isSelf, currentUserId: currentUser?.uid),
              ),
              videosAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator(color: QBrand.primary)),
                ),
                error: (e, _) => SliverToBoxAdapter(child: Text('$e')),
                data: (videos) => _VideoGrid(videos: videos),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  final AppUser user;
  final bool isSelf;
  final String? currentUserId;

  const _ProfileHeader({required this.user, required this.isSelf, this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowingAsync = currentUserId != null && !isSelf
        ? ref.watch(isFollowingProvider((currentUid: currentUserId!, targetUid: user.uid)))
        : null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 48,
            backgroundColor: QBrand.cardAlt,
            backgroundImage: user.avatarUrl != null ? CachedNetworkImageProvider(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? const Icon(Icons.person, size: 48, color: QBrand.fgMute)
                : null,
          ),
          const SizedBox(height: 12),
          Text(user.displayName,
              style: const TextStyle(color: QBrand.fg, fontSize: 20, fontWeight: FontWeight.bold)),
          if (user.bio != null) ...[
            const SizedBox(height: 8),
            Text(user.bio!,
                style: const TextStyle(color: QBrand.fgMute, fontSize: 14),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),

          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(value: user.followingCount, label: 'Following'),
              _Stat(value: user.followerCount, label: 'Followers'),
              _Stat(value: user.likeCount, label: 'Likes'),
            ],
          ),
          const SizedBox(height: 20),

          // LitRPG "System" status card — level + derived stats. No live
          // stream here, so it shows the lifetime (follower/like) stats only.
          SystemStatusCard(
            stats: StreamerStats.from(user: user),
            name: user.username,
          ),
          const SizedBox(height: 20),

          // Follow/Edit button
          if (!isSelf && currentUserId != null)
            isFollowingAsync!.when(
              loading: () => const SizedBox(height: 44),
              error: (_, _) => const SizedBox.shrink(),
              data: (isFollowing) => SizedBox(
                width: 200,
                height: 44,
                child: ElevatedButton(
                  onPressed: () async {
                    if (isFollowing) {
                      await ref.read(userServiceProvider).unfollowUser(currentUserId!, user.uid);
                    } else {
                      await ref.read(userServiceProvider).followUser(currentUserId!, user.uid);
                    }
                    ref.invalidate(isFollowingProvider);
                    ref.invalidate(userProfileProvider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? QBrand.cardAlt : QBrand.primary,
                    foregroundColor: isFollowing ? QBrand.fg : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isFollowing ? 'Following' : 'Follow',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final display = value >= 1000000
        ? '${(value / 1000000).toStringAsFixed(1)}M'
        : value >= 1000
            ? '${(value / 1000).toStringAsFixed(1)}K'
            : '$value';
    return Column(
      children: [
        Text(display,
            style: const TextStyle(color: QBrand.fg, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: QBrand.fgMute, fontSize: 12)),
      ],
    );
  }
}

class _VideoGrid extends StatelessWidget {
  final List<Video> videos;
  const _VideoGrid({required this.videos});

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('No videos yet', style: TextStyle(color: QBrand.fgDim)),
          ),
        ),
      );
    }
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final video = videos[i];
          return GestureDetector(
            onTap: () {
              // Open the tapped video full-screen using the same VideoCard
              // widget the home feed renders, so all editor effects (zoom,
              // blur, vignette, text, stickers, color filter) come along.
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    body: SafeArea(child: VideoCard(video: video)),
                  ),
                ),
              );
            },
            child: video.thumbnailUrl != null
                ? CachedNetworkImage(imageUrl: video.thumbnailUrl!, fit: BoxFit.cover)
                : Container(
                    color: QBrand.cardAlt,
                    child: const Icon(Icons.videocam, color: QBrand.fgDim),
                  ),
          );
        },
        childCount: videos.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 0.6,
      ),
    );
  }
}
