import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Manages the system-tray icon and "minimize to tray" behaviour on desktop.
///
/// Call [init] once after the first frame to register listeners, then call
/// [enable] or [disable] to show/hide the tray icon based on the user setting.
/// When enabled, closing the window hides it to the tray instead of
/// terminating the process so the 15-minute periodic sync timer keeps running.
class TrayService with TrayListener, WindowListener {
  TrayService({required this.onSyncNow, required this.onQuit});

  final VoidCallback onSyncNow;
  final Future<void> Function() onQuit;

  bool _initialized = false;
  bool _trayEnabled = false;

  static bool get isSupported =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Registers window and tray listeners. Must be called once after the first
  /// frame. Does not show the tray icon — call [enable] for that.
  Future<void> init() async {
    if (!isSupported || _initialized) return;
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initialized = true;
  }

  /// Shows the tray icon and intercepts window-close to hide instead of quit.
  Future<void> enable() async {
    if (!_initialized || _trayEnabled) return;

    final iconPath = Platform.isWindows
        ? 'windows/runner/resources/app_icon.ico'
        : 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png';

    try {
      await trayManager.setIcon(iconPath);
    } catch (_) {}

    await trayManager.setToolTip('PokeTeamDex');
    await _setContextMenu();
    await windowManager.setPreventClose(true);
    _trayEnabled = true;
  }

  /// Removes the tray icon and lets window-close exit the app normally.
  Future<void> disable() async {
    if (!_initialized || !_trayEnabled) return;
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    _trayEnabled = false;
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
    // Only called when preventClose=true (i.e. tray is enabled).
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
