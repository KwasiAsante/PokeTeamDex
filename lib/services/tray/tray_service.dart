import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Manages the system-tray icon and "minimize to tray" behaviour on desktop.
///
/// Call [init] once after the first frame. The tray shows a context menu with
/// Show / Sync Now / Quit. Closing the window hides it to the tray instead
/// of terminating the process, so the 15-minute periodic sync timer keeps
/// running in the background.
class TrayService with TrayListener, WindowListener {
  TrayService({required this.onSyncNow, required this.onQuit});

  final VoidCallback onSyncNow;
  final Future<void> Function() onQuit;

  bool _initialized = false;

  static bool get isSupported =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> init() async {
    if (!isSupported || _initialized) return;

    // Intercept the OS close event so we can hide-to-tray instead of quitting.
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    trayManager.addListener(this);

    // Reuse the existing platform app icons — declared as Flutter assets in
    // pubspec.yaml so tray_manager can load them via rootBundle.
    final iconPath = Platform.isWindows
        ? 'windows/runner/resources/app_icon.ico'
        : 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png';

    try {
      await trayManager.setIcon(iconPath);
    } catch (_) {
      // Icon loading may fail in some build configurations; the tray still
      // functions with a system-default icon.
    }

    await trayManager.setToolTip('PokeTeamDex');
    await _setContextMenu();

    _initialized = true;
  }

  Future<void> _setContextMenu() async {
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Show PokeTeamDex'),
      MenuItem.separator(),
      MenuItem(key: 'sync', label: 'Sync Now'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]));
  }

  void dispose() {
    if (!_initialized) return;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    _initialized = false;
  }

  // ── WindowListener ──────────────────────────────────────────────────────────

  @override
  void onWindowClose() async {
    // Hide to tray rather than terminating — the periodic sync timer continues.
    await windowManager.hide();
  }

  // ── TrayListener ───────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
      case 'sync':
        onSyncNow();
      case 'quit':
        await onQuit();
    }
  }
}
