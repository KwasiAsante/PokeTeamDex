import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poke_team_dex/services/update/update_info.dart';
import 'package:poke_team_dex/services/update/update_provider.dart';
import 'package:poke_team_dex/services/update/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _dismissedKey = 'dismissed_update_version';

class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateAsync = ref.watch(updateCheckProvider);

    return updateAsync.when(
      data: (info) {
        if (info == null) return child;
        return _DismissableUpdateBanner(info: info, child: child);
      },
      loading: () => child,
      error: (_, _) => child,
    );
  }
}

class _DismissableUpdateBanner extends StatefulWidget {
  const _DismissableUpdateBanner({required this.info, required this.child});

  final UpdateInfo info;
  final Widget child;

  @override
  State<_DismissableUpdateBanner> createState() => _DismissableUpdateBannerState();
}

class _DismissableUpdateBannerState extends State<_DismissableUpdateBanner> {
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _checkDismissed();
  }

  Future<void> _checkDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(_dismissedKey);
    if (mounted && dismissedVersion == widget.info.version) {
      setState(() => _dismissed = true);
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, widget.info.version);
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return widget.child;

    final downloadUrl = platformDownloadUrl(widget.info);

    return Column(
      children: [
        MaterialBanner(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          content: Text(
            'Update ${widget.info.version} available',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          actions: [
            if (downloadUrl != null)
              TextButton(
                onPressed: () async {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                child: const Text('Download'),
              ),
            TextButton(
              onPressed: () async {
                final uri = Uri.parse(widget.info.releaseUrl);
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              child: const Text("What's new"),
            ),
            TextButton(
              onPressed: _dismiss,
              child: const Text('Dismiss'),
            ),
          ],
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
