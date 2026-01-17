import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../data/database/repositories/episode_repository.dart';
import '../../data/database/repositories/anime_repository.dart';
import '../../data/models/m3u8_models.dart';

/// Video player screen with custom controls
class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String animeId;
  final String animeTitle;
  final int episodeNumber;
  final String episodeTitle;
  final String videoUrl;
  final bool isOffline;
  final MasterPlaylist? masterPlaylist;
  final int? startPosition; // Resume position in seconds

  const VideoPlayerScreen({
    super.key,
    required this.animeId,
    required this.animeTitle,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.videoUrl,
    this.isOffline = false,
    this.masterPlaylist,
    this.startPosition,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _setLandscapeMode();
  }

  Future<void> _initPlayer() async {
    _player = Player();
    _controller = VideoController(_player);

    // Listen to player state
    _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    _player.stream.position.listen((position) {
      if (mounted) setState(() => _position = position);
      _saveProgress();
    });

    _player.stream.duration.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    // Open media
    await _player.open(Media(widget.videoUrl));

    // Seek to start position if provided
    if (widget.startPosition != null && widget.startPosition! > 0) {
      await _player.seek(Duration(seconds: widget.startPosition!));
    }

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  void _setLandscapeMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _resetOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _saveProgress() async {
    // Save progress every 5 seconds
    if (_position.inSeconds % 5 == 0) {
      await EpisodeRepository.instance.updateWatchProgress(
        widget.animeId,
        widget.episodeNumber,
        position: _position.inSeconds,
        duration: _duration.inSeconds,
      );

      await AnimeRepository.instance.updateWatchProgress(
        widget.animeId,
        episodeNumber: widget.episodeNumber,
        position: _position.inSeconds,
      );
    }
  }

  @override
  void dispose() {
    _resetOrientation();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video
            Center(
              child: _isInitialized
                  ? Video(
                      controller: _controller,
                      controls: NoVideoControls,
                    )
                  : const CircularProgressIndicator(),
            ),

            // Buffering indicator
            if (_isBuffering)
              const Center(
                child: CircularProgressIndicator(
                  color: AppColors.draculaPurple,
                ),
              ),

            // Controls overlay
            if (_showControls) _buildControlsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            _buildTopBar(),

            const Spacer(),

            // Center controls
            _buildCenterControls(),

            const Spacer(),

            // Bottom controls
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.animeTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Episode ${widget.episodeNumber}: ${widget.episodeTitle}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rewind 10s
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.replay_10, color: Colors.white),
          onPressed: () => _player.seek(_position - const Duration(seconds: 10)),
        ),
        const SizedBox(width: 32),
        // Play/Pause
        IconButton(
          iconSize: 64,
          icon: Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: Colors.white,
          ),
          onPressed: () => _player.playOrPause(),
        ),
        const SizedBox(width: 32),
        // Forward 10s
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.forward_10, color: Colors.white),
          onPressed: () => _player.seek(_position + const Duration(seconds: 10)),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress bar
          Row(
            children: [
              Text(
                _position.format,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.draculaPurple,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.draculaPurple,
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _duration.inSeconds > 0
                        ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (value) {
                      final newPosition = Duration(
                        seconds: (value * _duration.inSeconds).round(),
                      );
                      _player.seek(newPosition);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _duration.format,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Bottom buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Playback speed
              TextButton(
                onPressed: _showSpeedSheet,
                child: Text(
                  '${_playbackSpeed}x',
                  style: const TextStyle(color: Colors.white),
                ),
              ),

              Row(
                children: [
                  // Previous episode
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: widget.episodeNumber > 1 ? _previousEpisode : null,
                  ),
                  // Next episode
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: _nextEpisode,
                  ),
                ],
              ),

              // Fullscreen toggle (already fullscreen in this implementation)
              IconButton(
                icon: const Icon(Icons.fit_screen, color: Colors.white),
                onPressed: () {
                  // Toggle fit mode
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (widget.masterPlaylist != null) ...[
              ListTile(
                leading: const Icon(Icons.high_quality),
                title: const Text('Quality'),
                subtitle: const Text('Auto'),
                onTap: () {
                  Navigator.pop(context);
                  _showQualitySheet();
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Audio'),
                subtitle: const Text('Hindi'),
                onTap: () {
                  Navigator.pop(context);
                  _showAudioSheet();
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Playback Speed'),
              subtitle: Text('${_playbackSpeed}x'),
              onTap: () {
                Navigator.pop(context);
                _showSpeedSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedSheet() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Playback Speed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...speeds.map((speed) => RadioListTile<double>(
                  title: Text('${speed}x'),
                  value: speed,
                  groupValue: _playbackSpeed,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _playbackSpeed = value);
                      _player.setRate(value);
                      Navigator.pop(context);
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showQualitySheet() {
    if (widget.masterPlaylist == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quality',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...widget.masterPlaylist!.videoStreams.map((stream) => ListTile(
                  title: Text(stream.qualityLabel),
                  subtitle: Text(stream.bandwidthFormatted),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Switch quality
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showAudioSheet() {
    if (widget.masterPlaylist == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...widget.masterPlaylist!.audioTracks.map((track) => ListTile(
                  title: Text(track.displayName),
                  trailing: track.isDefault
                      ? const Icon(Icons.check, color: AppColors.draculaPurple)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Switch audio track
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _previousEpisode() {
    // TODO: Navigate to previous episode
    Navigator.pop(context);
  }

  void _nextEpisode() {
    // TODO: Navigate to next episode
    Navigator.pop(context);
  }
}
