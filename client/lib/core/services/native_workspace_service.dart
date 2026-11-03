import 'package:flutter/services.dart';

class NativeWorkspaceService {
  static const MethodChannel _channel = MethodChannel('devforge/native_workspace');

  Future<Map<String, dynamic>> runtimeInfo() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('runtimeInfo');
    return result ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listEntries({String path = ''}) async {
    final result = await _channel.invokeListMethod<dynamic>(
      'listEntries',
      <String, dynamic>{'path': path},
    );
    return (result ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((entry) => entry.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);
  }

  Future<String> readFile(String path) async {
    return await _channel.invokeMethod<String>(
          'readFile',
          <String, dynamic>{'path': path},
        ) ??
        '';
  }

  Future<void> writeFile(String path, String content) async {
    await _channel.invokeMethod<void>(
      'writeFile',
      <String, dynamic>{'path': path, 'content': content},
    );
  }

  Future<void> createDirectory(String path) async {
    await _channel.invokeMethod<void>(
      'createDirectory',
      <String, dynamic>{'path': path},
    );
  }
}
