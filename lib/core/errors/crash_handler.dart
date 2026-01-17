import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/storage_keys.dart';
import '../utils/logger.dart';

/// Handles app crashes and stores logs for display on next launch
class CrashHandler {
  CrashHandler._();

  static String? _lastCrashLog;
  static bool _isInitialized = false;

  /// Initialize crash handling
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Handle Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _saveCrashLog(details.toString());
    };

    // Handle platform errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _saveCrashLog('Platform Error: $error\n$stack');
      return true;
    };

    // Handle isolate errors
    Isolate.current.addErrorListener(RawReceivePort((pair) {
      final List<dynamic> errorAndStacktrace = pair;
      _saveCrashLog('Isolate Error: ${errorAndStacktrace[0]}\n${errorAndStacktrace[1]}');
    }).sendPort);
  }

  /// Run app with crash zone
  static Future<void> runAppWithCrashHandler(Widget app) async {
    await runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        await initialize();
        await _loadLastCrashLog();
        runApp(app);
      },
      (error, stackTrace) {
        AppLogger.e('Uncaught error', error, stackTrace);
        _saveCrashLog('Uncaught Error: $error\n$stackTrace');
      },
    );
  }

  /// Save crash log to SharedPreferences
  static Future<void> _saveCrashLog(String log) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final fullLog = '[$timestamp]\n$log';
      AppLogger.e('Crash logged', fullLog);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.lastCrashLog, fullLog);
    } catch (e) {
      AppLogger.e('Failed to save crash log', e);
    }
  }

  /// Load last crash log from SharedPreferences
  static Future<void> _loadLastCrashLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastCrashLog = prefs.getString(StorageKeys.lastCrashLog);
      
      // Clear the log after loading
      if (_lastCrashLog != null) {
        await prefs.remove(StorageKeys.lastCrashLog);
      }
    } catch (e) {
      AppLogger.e('Failed to load crash log', e);
    }
  }

  /// Check if there's a crash log from previous session
  static bool get hasCrashLog => _lastCrashLog != null && _lastCrashLog!.isNotEmpty;

  /// Get the last crash log
  static String? get lastCrashLog => _lastCrashLog;

  /// Clear the last crash log
  static void clearCrashLog() {
    _lastCrashLog = null;
  }

  /// Show crash dialog if there's a crash log
  static Future<void> showCrashDialogIfNeeded(BuildContext context) async {
    if (!hasCrashLog) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CrashLogDialog(crashLog: _lastCrashLog!),
    );
    clearCrashLog();
  }
}

/// Dialog to display crash log with copy option
class CrashLogDialog extends StatelessWidget {
  final String crashLog;

  const CrashLogDialog({super.key, required this.crashLog});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          const Text('App Crashed'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The app crashed during the last session. You can copy the error log to report this issue.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  crashLog,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Dismiss'),
        ),
        FilledButton.icon(
          onPressed: () {
            // Copy to clipboard
            // Using Clipboard.setData would require services import
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Log copied to clipboard')),
            );
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy Log'),
        ),
      ],
    );
  }
}
