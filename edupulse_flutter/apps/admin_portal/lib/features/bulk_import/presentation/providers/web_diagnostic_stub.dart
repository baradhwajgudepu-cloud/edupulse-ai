import 'dart:async';

Future<void> runNativeFetchImpl(String schoolId, String token, void Function(String) log) async {
  log('Native fetch is not supported on this platform.\n');
}

Future<void> runProgressiveTestImpl(String schoolId, String token, void Function(String) log) async {
  log('Progressive header test is not supported on this platform.\n');
}
