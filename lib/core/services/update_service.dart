import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_release.dart';

final class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class UpdateService {
  UpdateService({Dio? dio, Future<String> Function()? currentVersionLoader})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.github.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: const <String, Object>{
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
              },
            ),
          ),
      _currentVersionLoader =
          currentVersionLoader ??
          (() async => (await PackageInfo.fromPlatform()).version);

  static const owner = 'xianxian51';
  static const repository = 'context_words';

  final Dio _dio;
  final Future<String> Function() _currentVersionLoader;

  Future<AppRelease?> checkForUpdate({String? currentVersion}) async {
    final installedVersion = currentVersion ?? await _currentVersionLoader();
    final releases = await _fetchCandidates();
    if (releases.isEmpty) {
      return null;
    }
    releases.sort((a, b) => compareVersions(b.tagName, a.tagName));
    final newest = releases.first;
    return compareVersions(newest.tagName, installedVersion) > 0
        ? newest
        : null;
  }

  Future<List<AppRelease>> _fetchCandidates() async {
    try {
      final candidates = <String, AppRelease>{};
      try {
        final latest = await _dio.get<Object?>(
          '/repos/$owner/$repository/releases/latest',
        );
        final parsed = parseRelease(latest.data);
        candidates[parsed.tagName] = parsed;
      } on DioException catch (error) {
        if (error.response?.statusCode != 404) {
          rethrow;
        }
      }

      // GitHub's /releases/latest endpoint excludes prereleases. The public
      // list is also checked because this app distributes test APKs as prereleases.
      // Source: https://docs.github.com/en/rest/releases/releases#get-the-latest-release
      final response = await _dio.get<Object?>(
        '/repos/$owner/$repository/releases',
        queryParameters: const <String, Object>{'per_page': 10},
      );
      final data = response.data;
      if (data is List) {
        for (final item in data.whereType<Map>()) {
          final normalized = Map<String, Object?>.from(item);
          if (normalized['draft'] == true) {
            continue;
          }
          final parsed = AppRelease.fromJson(normalized);
          candidates[parsed.tagName] = parsed;
        }
      }
      return candidates.values.toList(growable: false);
    } on UpdateException {
      rethrow;
    } on DioException {
      throw const UpdateException('检查更新失败，请稍后重试。');
    } on FormatException {
      throw const UpdateException('GitHub Release 返回格式无法识别。');
    } catch (_) {
      throw const UpdateException('检查更新失败，请稍后重试。');
    }
  }

  Future<void> openRelease(AppRelease release) async {
    final opened = await launchUrl(
      release.htmlUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw const UpdateException('无法打开 GitHub Release 页面。');
    }
  }

  static AppRelease parseRelease(Object? data) {
    if (data is! Map) {
      throw const FormatException('Expected a GitHub release object.');
    }
    return AppRelease.fromJson(Map<String, Object?>.from(data));
  }

  static int compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < length; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }

  static List<int> _versionParts(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final core = normalized.split(RegExp(r'[-+]')).first;
    final parts = core.split('.');
    if (parts.isEmpty || parts.any((part) => int.tryParse(part) == null)) {
      throw const FormatException('Invalid semantic version.');
    }
    return parts.map(int.parse).toList(growable: false);
  }
}
