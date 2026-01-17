import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../data/database/database.dart';
import '../../data/services/storage_service.dart';
import '../../providers/app_providers.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    if (settings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _buildSectionHeader(context, 'Appearance'),
          _buildThemeTile(context, ref, settings),

          const SizedBox(height: 24),

          // Playback Section
          _buildSectionHeader(context, 'Playback'),
          _buildQualityTile(context, ref, settings),
          _buildLanguageTile(context, ref, settings),
          _buildAutoPlayTile(context, ref, settings),

          const SizedBox(height: 24),

          // Downloads Section
          _buildSectionHeader(context, 'Downloads'),
          _buildStorageTile(context, ref, settings),
          _buildParallelDownloadsTile(context, ref, settings),
          _buildWifiOnlyTile(context, ref, settings),

          const SizedBox(height: 24),

          // Storage Section
          _buildSectionHeader(context, 'Storage'),
          _buildStorageInfoTile(context, ref),
          _buildClearCacheTile(context, ref),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader(context, 'About'),
          _buildAboutTile(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.draculaPurple,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context, WidgetRef ref, AppSettingsTableData settings) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.palette_outlined),
        title: const Text('Theme'),
        subtitle: Text(_getThemeName(settings.themeMode)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showThemeDialog(context, ref, settings),
      ),
    );
  }

  Widget _buildQualityTile(BuildContext context, WidgetRef ref, AppSettingsTableData settings) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.high_quality_outlined),
        title: const Text('Default Quality'),
        subtitle: Text(settings.defaultQuality ?? 'Ask every time'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showQualityDialog(context, ref, settings),
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context, WidgetRef ref, AppSettingsTableData settings) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.language_outlined),
        title: const Text('Default Language'),
        subtitle: Text(settings.defaultLanguage ?? 'Ask every time'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showLanguageDialog(context, ref, settings),
      ),
    );
  }

  Widget _buildAutoPlayTile(BuildContext context, WidgetRef ref, AppSettingsTableData settings) {
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.skip_next_outlined),
        title: const Text('Auto-play Next Episode'),
        subtitle: const Text('Automatically play the next episode'),
        value: settings.autoPlayNext,
        onChanged: (value) {
          ref.read(settingsProvider.notifier).refresh();
        },
      ),
    );
  }

  Widget _buildStorageTile(BuildContext context, WidgetRef ref, AppSettingsTableData settings) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.folder_outlined),
        title: const Text('Download Location'),
        subtitle: Text(settings.downloadPath ?? 'Not set'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _requestStoragePermission(context, ref),
      ),
    );
  }

  Widget _buildParallelDownloadsTile(BuildContext context, WidgetRef ref, AppSettingsTableData settings) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.download_outlined),
        title: const Text('Parallel Downloads'),
        subtitle: Text('${settings.parallelDownloads} episodes at once'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showParallelDownloadsDialog(context, ref, settings),
      ),
    );
  }

  Widget _buildWifiOnlyTile(BuildContext context, WidgetRef ref, AppSettingsTableData settings) {
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.wifi_outlined),
        title: const Text('Download on Wi-Fi Only'),
        subtitle: const Text('Pause downloads on mobile data'),
        value: settings.downloadOnWifiOnly,
        onChanged: (value) {
          ref.read(settingsProvider.notifier).refresh();
        },
      ),
    );
  }

  Widget _buildStorageInfoTile(BuildContext context, WidgetRef ref) {
    return Card(
      child: FutureBuilder<int>(
        future: StorageService.instance.getTotalDownloadedSize(),
        builder: (context, snapshot) {
          final size = snapshot.data ?? 0;
          return ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Downloaded Content'),
            subtitle: Text(size.formatBytes),
          );
        },
      ),
    );
  }

  Widget _buildClearCacheTile(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
        title: Text('Clear Cache', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        subtitle: const Text('Clear temporary files'),
        onTap: () => _showClearCacheDialog(context, ref),
      ),
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('AniX'),
        subtitle: const Text('Version 1.0.0'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showAboutDialog(context),
      ),
    );
  }

  String _getThemeName(String mode) {
    switch (mode) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, AppSettingsTableData settings) {
    final themes = ['system', 'light', 'dark'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: themes.map((mode) {
            return RadioListTile<String>(
              title: Text(_getThemeName(mode)),
              value: mode,
              groupValue: settings.themeMode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showQualityDialog(BuildContext context, WidgetRef ref, AppSettingsTableData settings) {
    final qualities = ['1080p', '720p', '480p', '360p', null];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: qualities.map((quality) {
            return RadioListTile<String?>(
              title: Text(quality ?? 'Ask every time'),
              value: quality,
              groupValue: settings.defaultQuality,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setDefaultQuality(value, save: true);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, AppSettingsTableData settings) {
    final languages = ['Hindi', 'Japanese', 'English', null];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((language) {
            return RadioListTile<String?>(
              title: Text(language ?? 'Ask every time'),
              value: language,
              groupValue: settings.defaultLanguage,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setDefaultLanguage(value, save: true);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showParallelDownloadsDialog(BuildContext context, WidgetRef ref, AppSettingsTableData settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Parallel Downloads'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1, 2, 3, 4].map((count) {
            return RadioListTile<int>(
              title: Text('$count episode${count > 1 ? 's' : ''} at once'),
              value: count,
              groupValue: settings.parallelDownloads,
              onChanged: (value) {
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _requestStoragePermission(BuildContext context, WidgetRef ref) async {
    final granted = await StorageService.instance.requestSafPermission();
    if (granted) {
      ref.read(settingsProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage location set')),
        );
      }
    }
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear temporary files. Downloaded episodes will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await StorageService.instance.clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache cleared')),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'AniX',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.draculaPurple,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
      ),
      children: const [
        Text('An Flutter app to watch anime in Hindi.'),
        SizedBox(height: 16),
        Text('Made with ❤️'),
      ],
    );
  }
}
