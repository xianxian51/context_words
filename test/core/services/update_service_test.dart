import 'dart:convert';
import 'dart:typed_data';

import 'package:context_words/core/services/update_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares semantic versions with v prefixes and build metadata', () {
    expect(UpdateService.compareVersions('v0.1.1', '0.1.0'), greaterThan(0));
    expect(UpdateService.compareVersions('0.1.1+5', 'v0.1.1'), 0);
    expect(UpdateService.compareVersions('0.1.0', '0.1.1'), lessThan(0));
  });

  test('detects a newer prerelease from the public release list', () async {
    final adapter = _ReleaseAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.github.com'))
      ..httpClientAdapter = adapter;
    final service = UpdateService(
      dio: dio,
      currentVersionLoader: () async => '0.1.0',
    );

    final release = await service.checkForUpdate();

    expect(release?.tagName, 'v0.1.1');
    expect(release?.isPrerelease, isTrue);
    expect(release?.apkDownloadUrl?.path, endsWith('/app-debug.apk'));
  });

  test('rejects release links outside the configured GitHub repository', () {
    expect(
      () => UpdateService.parseRelease(<String, Object?>{
        'tag_name': 'v9.9.9',
        'html_url': 'https://example.com/untrusted',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('maps network failures to a readable update error', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.github.com'))
      ..httpClientAdapter = _FailingAdapter();
    final service = UpdateService(
      dio: dio,
      currentVersionLoader: () async => '0.1.0',
    );

    await expectLater(
      service.checkForUpdate(),
      throwsA(
        isA<UpdateException>().having(
          (error) => error.message,
          'message',
          '检查更新失败，请稍后重试。',
        ),
      ),
    );
  });
}

final class _ReleaseAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final stable = _releaseJson('v0.1.0', prerelease: false);
    final response = options.path.endsWith('/latest')
        ? stable
        : <Object>[_releaseJson('v0.1.1', prerelease: true), stable];
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  Map<String, Object?> _releaseJson(String tag, {required bool prerelease}) {
    return <String, Object?>{
      'tag_name': tag,
      'name': tag,
      'body': 'Test release',
      'html_url':
          'https://github.com/xianxian51/context_words/releases/tag/$tag',
      'prerelease': prerelease,
      'draft': false,
      'assets': <Object>[
        <String, Object?>{
          'name': 'app-debug.apk',
          'browser_download_url':
              'https://github.com/xianxian51/context_words/releases/download/$tag/app-debug.apk',
        },
      ],
    };
  }

  @override
  void close({bool force = false}) {}
}

final class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: const SocketExceptionStub(),
    );
  }

  @override
  void close({bool force = false}) {}
}

final class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
