import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/storage_service.dart';
import '../../providers/app_providers.dart';
import '../main/main_screen.dart';

/// Permissions screen shown on first launch
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _notificationGranted = false;
  bool _storageGranted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notificationStatus = await Permission.notification.status;
    final storageStatus = await StorageService.instance.hasSafPermission();

    setState(() {
      _notificationGranted = notificationStatus.isGranted;
      _storageGranted = storageStatus;
    });
  }

  bool get _allPermissionsGranted => _notificationGranted && _storageGranted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              // Header
              Text(
                'Welcome to AniX',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),

              const SizedBox(height: 8),

              Text(
                'We need a few permissions to provide you the best experience',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.draculaComment,
                    ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 48),

              // Permissions List
              _PermissionTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Show download progress and important updates',
                isGranted: _notificationGranted,
                onRequest: _requestNotificationPermission,
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideX(begin: 0.2),

              const SizedBox(height: 16),

              _PermissionTile(
                icon: Icons.folder_outlined,
                title: 'Storage Access',
                subtitle: 'Save downloaded episodes to your device',
                isGranted: _storageGranted,
                onRequest: _requestStoragePermission,
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideX(begin: 0.2),

              const Spacer(flex: 2),

              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.draculaCurrentLine.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.draculaCyan,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can skip permissions but downloading episodes will be disabled.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _skipPermissions,
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isLoading
                          ? null
                          : (_allPermissionsGranted ? _completeSetup : null),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Done'),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

              const SizedBox(height: 16),

              // Refresh button
              Center(
                child: TextButton.icon(
                  onPressed: _checkPermissions,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    setState(() {
      _notificationGranted = status.isGranted;
    });

    if (status.isGranted) {
      ref.read(settingsProvider.notifier).setNotificationPermission(true);
    }
  }

  Future<void> _requestStoragePermission() async {
    final granted = await StorageService.instance.requestSafPermission();
    setState(() {
      _storageGranted = granted;
    });
  }

  Future<void> _skipPermissions() async {
    setState(() => _isLoading = true);

    await ref.read(settingsProvider.notifier).setPermissionsSkipped(true);
    await ref.read(settingsProvider.notifier).completeFirstLaunch();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  Future<void> _completeSetup() async {
    setState(() => _isLoading = true);

    await ref.read(settingsProvider.notifier).completeFirstLaunch();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback onRequest;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isGranted
                ? AppColors.draculaGreen.withOpacity(0.2)
                : AppColors.draculaPurple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isGranted ? AppColors.draculaGreen : AppColors.draculaPurple,
          ),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isGranted
            ? const Icon(Icons.check_circle, color: AppColors.draculaGreen)
            : TextButton(
                onPressed: onRequest,
                child: const Text('Grant'),
              ),
      ),
    );
  }
}
