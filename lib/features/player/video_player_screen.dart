import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../data/database/repositories/anime_repository.dart';
import '../../data/database/repositories/episode_repository.dart';
import '../../data/models/m3u8_models.dart';
import '../../data/services/download_manager.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String animeId;
  final String animeTitle;
  final int episodeNumber;
  final String episodeTitle;
  final String videoUrl;
  final bool isOffline;
  final MasterPlaylist? masterPlaylist;
  final int? startPosition;

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
  bool _isSeeking = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _seekPosition = Duration.zero;

  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _setLandscapeMode();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 64 * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
      ),
    );

    _controller = VideoController(_player);

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

    _player.stream.error.listen((error) {
      if (mounted && error.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Player error: $error')),
        );
      }
    });

    await _player.open(Media(widget.videoUrl));

    if (widget.startPosition != null && widget.startPosition! > 0) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _player.seek(Duration(seconds: widget.startPosition!));
    }

    if (mounted) setState(() => _isInitialized = true);
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
    if (_position.inSeconds > 0 && _position.inSeconds % 5 == 0) {
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

  Future<void> _startDownload() async {
    if (widget.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already offline')),
      );
      return;
    }

    if (widget.masterPlaylist == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download not available (playlist missing)')),
      );
      return;
    }

    if (widget.masterPlaylist!.videoStreams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video streams found')),
      );
      return;
    }

    try {
      final selection = StreamSelection(
        videoStream: widget.masterPlaylist!.videoStreams.first,
        audioTrack: widget.masterPlaylist!.audioTracks.isNotEmpty
            ? widget.masterPlaylist!.audioTracks.first
            : null,
      );

      await DownloadManager.instance.createDownload(
        animeId: widget.animeId,
        animeTitle: widget.animeTitle,
        episodeNumber: widget.episodeNumber,
        episodeTitle: widget.episodeTitle,
        masterM3u8Url: widget.masterPlaylist!.masterUrl,
        selection: selection,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download started')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
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
            Center(
              child: _isInitialized
                  ? Video(
                      controller: _controller,
                      controls: NoVideoControls,
                    )
                  : const CircularProgressIndicator(),
            ),
            if (_isBuffering)
              const Center(
                child: CircularProgressIndicator(
                  color: AppColors.draculaPurple,
                ),
              ),
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
            _buildTopBar(),
            const Spacer(),
            _buildCenterControls(),
            const Spacer(),
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
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _startDownload,
          ),
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
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.replay_10, color: Colors.white),
          onPressed: () => _player.seek(_position - const Duration(seconds: 10)),
        ),
        const SizedBox(width: 32),
        IconButton(
          iconSize: 64,
          icon: Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: Colors.white,
          ),
          onPressed: () => _player.playOrPause(),
        ),
        const SizedBox(width: 32),
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
          Row(
            children: [
              Text(
                (_isSeeking ? _seekPosition : _position).format,
                style: TextStyle(
                  color: _isSeeking ? AppColors.draculaPurple : Colors.white,
                  fontSize: 12,
                  fontWeight: _isSeeking ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.draculaPurple,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.draculaPurple,
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: _duration.inSeconds > 0
                        ? ((_isSeeking ? _seekPosition : _position).inSeconds /
                                _duration.inSeconds)
                            .clamp(0.0, 1.0)
                        : 0.0,
                    onChangeStart: (_) {
                      setState(() {
                        _isSeeking = true;
                        _seekPosition = _position;
                      });
                    },
                    onChanged: (value) {
                      setState(() {
                        _seekPosition = Duration(
                          seconds: (value * _duration.inSeconds).round(),
                        );
                      });
                    },
                    onChangeEnd: (value) {
                      final newPosition = Duration(
                        seconds: (value * _duration.inSeconds).round(),
                      );
                      _player.seek(newPosition);
                      setState(() => _isSeeking = false);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _showSpeedSheet,
                child: Text(
                  '${_playbackSpeed}x',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: widget.episodeNumber > 1 ? _previousEpisode : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: _nextEpisode,
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.fit_screen, color: Colors.white),
                onPressed: () {},
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
            Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
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
            Text('Playback Speed', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...speeds.map(
              (speed) => RadioListTile<double>(
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previousEpisode() {
    Navigator.pop(context);
  }

  void _nextEpisode() {
    Navigator.pop(context);
  }
}
```0
