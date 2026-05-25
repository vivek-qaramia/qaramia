import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../models/video.dart';
import '../../models/video_filter.dart';
import '../../providers/providers.dart';
import '../../theme/brand.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(videoFeedProvider);
    return feedAsync.when(
      loading: () => const _FeedSkeleton(),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: QBrand.fg))),
      data: (videos) {
        if (videos.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off, color: QBrand.fgMute, size: 64),
                SizedBox(height: 16),
                Text('No videos yet', style: TextStyle(color: QBrand.fgMute, fontSize: 18)),
              ],
            ),
          );
        }
        return PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: videos.length,
          itemBuilder: (context, i) => VideoCard(video: videos[i]),
        );
      },
    );
  }
}

class VideoCard extends ConsumerStatefulWidget {
  final Video video;
  const VideoCard({super.key, required this.video});

  @override
  ConsumerState<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends ConsumerState<VideoCard> {
  late VideoPlayerController _ctrl;
  bool _liked = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
          _ctrl.setLooping(true);
          ref.read(videoServiceProvider).incrementView(widget.video.id);
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleLike() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    setState(() => _liked = !_liked);
    if (_liked) {
      await ref.read(videoServiceProvider).likeVideo(widget.video.id, uid);
    } else {
      await ref.read(videoServiceProvider).unlikeVideo(widget.video.id, uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video — wrapped in the post-stream-editor's color-grading filter
        // when filterId is set on the doc. Beauty has no matrix so it
        // renders as Normal here.
        if (_initialized)
          GestureDetector(
            onTap: () => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(),
            child: AspectRatio(
              aspectRatio: _ctrl.value.aspectRatio,
              child: () {
                final filter = VideoFilter.byId(widget.video.filterId);
                final player = VideoPlayer(_ctrl);
                if (!filter.hasColorOverlay) return player;
                return ColorFiltered(
                  colorFilter: ColorFilter.matrix(filter.colorMatrix!),
                  child: player,
                );
              }(),
            ),
          )
        else
          Container(color: Colors.black),

        // Gradient overlay
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.transparent, Color(0xAA000000)],
              stops: [0, 0.5, 1],
            ),
          ),
        ),

        // Right-side actions
        Positioned(
          right: 12,
          bottom: 100,
          child: _ActionColumn(video: widget.video, liked: _liked, onLike: _toggleLike),
        ),

        // Bottom info
        Positioned(
          left: 16,
          right: 80,
          bottom: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.video.authorUsername}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                widget.video.caption,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.video.audioTitle != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.music_note, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(widget.video.audioTitle!,
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionColumn extends StatelessWidget {
  final Video video;
  final bool liked;
  final VoidCallback onLike;

  const _ActionColumn({required this.video, required this.liked, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 24,
          backgroundImage: video.authorAvatarUrl != null
              ? NetworkImage(video.authorAvatarUrl!)
              : null,
          backgroundColor: Colors.grey[800],
          child: video.authorAvatarUrl == null
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 20),
        _ActionBtn(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          label: _fmt(video.likeCount),
          color: liked ? QBrand.love : Colors.white,
          onTap: onLike,
        ),
        const SizedBox(height: 20),
        _ActionBtn(
          icon: Icons.comment_outlined,
          label: _fmt(video.commentCount),
          onTap: () {},
        ),
        const SizedBox(height: 20),
        _ActionBtn(
          icon: Icons.share_outlined,
          label: _fmt(video.shareCount),
          onTap: () {},
        ),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF3830CC))));
  }
}
