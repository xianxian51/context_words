final class AppRelease {
  const AppRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.isPrerelease,
    this.apkDownloadUrl,
  });

  final String tagName;
  final String name;
  final String body;
  final Uri htmlUrl;
  final bool isPrerelease;
  final Uri? apkDownloadUrl;

  factory AppRelease.fromJson(Map<String, Object?> json) {
    final tagName = _requiredString(json, 'tag_name');
    final htmlUrl = Uri.tryParse(_requiredString(json, 'html_url'));
    if (!_isAllowedRepositoryUrl(htmlUrl)) {
      throw const FormatException('Invalid GitHub release URL.');
    }
    Uri? apkUrl;
    final assets = json['assets'];
    if (assets is List) {
      for (final asset in assets.whereType<Map>()) {
        if (asset['name'] == 'app-debug.apk') {
          final candidate = Uri.tryParse(
            asset['browser_download_url']?.toString() ?? '',
          );
          if (_isAllowedRepositoryUrl(candidate)) {
            apkUrl = candidate;
          }
          break;
        }
      }
    }
    return AppRelease(
      tagName: tagName,
      name: _optionalString(json['name']) ?? tagName,
      body: _optionalString(json['body']) ?? '',
      htmlUrl: htmlUrl!,
      isPrerelease: json['prerelease'] == true,
      apkDownloadUrl: apkUrl,
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = _optionalString(json[key]);
  if (value == null) {
    throw FormatException('Missing release field: $key');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}

bool _isAllowedRepositoryUrl(Uri? uri) {
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'github.com' &&
      uri.path.startsWith('/xianxian51/context_words/');
}
