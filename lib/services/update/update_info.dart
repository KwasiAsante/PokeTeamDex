class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.releaseUrl,
    this.apkUrl,
    this.msiUrl,
    this.exeUrl,
    this.webUrl,
  });

  final String version;
  final String releaseUrl;
  final String? apkUrl;
  final String? msiUrl;
  final String? exeUrl;
  final String? webUrl;
}
