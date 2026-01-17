import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../data/models/m3u8_models.dart';

/// Dialog for selecting video quality and audio language
class QualitySelectorDialog extends StatefulWidget {
  final MasterPlaylist playlist;
  final String? defaultQuality;
  final String? defaultLanguage;
  final Function(StreamSelection) onSelect;

  const QualitySelectorDialog({
    super.key,
    required this.playlist,
    this.defaultQuality,
    this.defaultLanguage,
    required this.onSelect,
  });

  @override
  State<QualitySelectorDialog> createState() => _QualitySelectorDialogState();

  /// Show the quality selector dialog
  static Future<StreamSelection?> show(
    BuildContext context, {
    required MasterPlaylist playlist,
    String? defaultQuality,
    String? defaultLanguage,
  }) {
    return showModalBottomSheet<StreamSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QualitySelectorDialog(
        playlist: playlist,
        defaultQuality: defaultQuality,
        defaultLanguage: defaultLanguage,
        onSelect: (selection) => Navigator.pop(context, selection),
      ),
    );
  }
}

class _QualitySelectorDialogState extends State<QualitySelectorDialog> {
  late VideoStream _selectedVideo;
  AudioTrack? _selectedAudio;
  bool _saveAsDefault = false;

  @override
  void initState() {
    super.initState();
    _initializeSelection();
  }

  void _initializeSelection() {
    // Select default or first video stream
    if (widget.defaultQuality != null) {
      _selectedVideo = widget.playlist.videoStreams.firstWhere(
        (v) => v.qualityLabel == widget.defaultQuality,
        orElse: () => widget.playlist.videoStreams.first,
      );
    } else {
      _selectedVideo = widget.playlist.videoStreams.first;
    }

    // Select default or first compatible audio track
    final compatibleAudio = widget.playlist.getCompatibleAudio(_selectedVideo);
    if (compatibleAudio.isNotEmpty) {
      if (widget.defaultLanguage != null) {
        _selectedAudio = compatibleAudio.firstWhere(
          (a) => a.displayName == widget.defaultLanguage,
          orElse: () => compatibleAudio.first,
        );
      } else {
        _selectedAudio = compatibleAudio.firstWhere(
          (a) => a.isDefault,
          orElse: () => compatibleAudio.first,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compatibleAudio = widget.playlist.getCompatibleAudio(_selectedVideo);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.draculaComment,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                'Select Quality',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 16),

              // Quality options
              Text(
                'Video Quality',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.draculaPurple,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.playlist.videoStreams.map((stream) {
                  final isSelected = stream == _selectedVideo;
                  return ChoiceChip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(stream.qualityLabel),
                        Text(
                          stream.bandwidthFormatted,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedVideo = stream;
                          // Update audio selection for new video
                          final newCompatible = widget.playlist.getCompatibleAudio(stream);
                          if (newCompatible.isNotEmpty) {
                            _selectedAudio = newCompatible.first;
                          } else {
                            _selectedAudio = null;
                          }
                        });
                      }
                    },
                    selectedColor: AppColors.draculaPurple,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                    ),
                  );
                }).toList(),
              ),

              // Audio options (if available)
              if (compatibleAudio.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Audio Language',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.draculaPurple,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: compatibleAudio.map((audio) {
                    final isSelected = audio == _selectedAudio;
                    return ChoiceChip(
                      label: Text(audio.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedAudio = audio);
                        }
                      },
                      selectedColor: AppColors.draculaPurple,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 24),

              // Save as default checkbox
              CheckboxListTile(
                value: _saveAsDefault,
                onChanged: (value) {
                  setState(() => _saveAsDefault = value ?? false);
                },
                title: const Text('Save as default'),
                subtitle: const Text('Use this selection for future videos'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        widget.onSelect(StreamSelection(
                          videoStream: _selectedVideo,
                          audioTrack: _selectedAudio,
                          saveAsDefault: _saveAsDefault,
                        ));
                      },
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
