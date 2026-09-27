import 'package:flutter/foundation.dart';

class AuthIncidentLogger {
  static final List<String> _eventBuffer = [];
  static const int _maxBufferSize = 300;

  static void _addToBuffer(String text) {
    _eventBuffer.add(text);
    if (_eventBuffer.length > _maxBufferSize) {
      _eventBuffer.removeAt(0);
    }
  }

  static void log(String event, [Map<String, dynamic>? metadata]) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final buffer = StringBuffer('[AUTH INCIDENT][$timestamp] $event');
    if (metadata != null && metadata.isNotEmpty) {
      for (final entry in metadata.entries) {
        buffer.write('\n  ${entry.key}: ${entry.value}');
      }
    }
    final text = buffer.toString();
    _addToBuffer(text);
    debugPrint(text);
  }

  static void logUnauthenticated({
    required String previousState,
    required String sourceClass,
    required String sourceMethod,
    required String reason,
    String? currentRoute,
    bool hasAccessToken = false,
    bool hasRefreshToken = false,
    bool hasTenantContext = false,
    bool hasSchoolContext = false,
    int? httpStatus,
    String? requestPath,
  }) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final buffer = StringBuffer();
    buffer.writeln('[AUTH INCIDENT][$timestamp] AUTH_STATE_UNAUTHENTICATED');
    buffer.writeln('  Previous State: $previousState');
    buffer.writeln('  Source Class: $sourceClass');
    buffer.writeln('  Source Method: $sourceMethod');
    buffer.writeln('  Reason: $reason');
    if (currentRoute != null) buffer.writeln('  Current Route: $currentRoute');
    if (httpStatus != null) buffer.writeln('  HTTP Status: $httpStatus');
    if (requestPath != null) buffer.writeln('  Request Path: $requestPath');
    buffer.writeln('  Access Token Exists: ${hasAccessToken ? "YES" : "NO"}');
    buffer.writeln('  Refresh Token Exists: ${hasRefreshToken ? "YES" : "NO"}');
    buffer.writeln('  Tenant Context Exists: ${hasTenantContext ? "YES" : "NO"}');
    buffer.writeln('  School Context Exists: ${hasSchoolContext ? "YES" : "NO"}');
    final text = buffer.toString();
    _addToBuffer(text);
    debugPrint(text);

    debugPrintStack(
      label: '[AUTH INCIDENT] CALL STACK FOR UNAUTHENTICATED',
    );
  }

  static void logStateMutation({
    required String oldState,
    required String newState,
    required String callerClass,
    required String callerMethod,
    required String reason,
  }) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final msg = '[AUTH STATE MUTATION][$timestamp]\n'
        '  OLD STATE: $oldState\n'
        '  NEW STATE: $newState\n'
        '  CALLER CLASS: $callerClass\n'
        '  CALLER METHOD: $callerMethod\n'
        '  REASON: $reason';
    _addToBuffer(msg);
    debugPrint(msg);
    debugPrintStack(label: '[AUTH STATE MUTATION STACK]');
  }

  static void dump() {
    debugPrint('[AUTH INCIDENT DUMP START]');
    for (final e in _eventBuffer) {
      debugPrint(e);
    }
    debugPrint('[AUTH INCIDENT DUMP END]');
  }
}
