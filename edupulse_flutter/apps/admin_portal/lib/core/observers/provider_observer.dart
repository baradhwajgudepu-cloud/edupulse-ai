import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';

class AppProviderObserver extends ProviderObserver {
  @override
  void didAddProvider(ProviderBase<Object?> provider, Object? value,
      ProviderContainer container) {
    EduLogger.d(
        'Provider Created: ${provider.name ?? provider.runtimeType} -> Initial Value: $value');
  }

  @override
  void didUpdateProvider(ProviderBase<Object?> provider, Object? previousValue,
      Object? newValue, ProviderContainer container) {
    EduLogger.d(
        'Provider Updated: ${provider.name ?? provider.runtimeType} -> Value changed from: $previousValue to: $newValue');
  }

  @override
  void didDisposeProvider(
      ProviderBase<Object?> provider, ProviderContainer container) {
    EduLogger.d('Provider Disposed: ${provider.name ?? provider.runtimeType}');
  }

  @override
  void providerDidFail(ProviderBase<Object?> provider, Object error,
      StackTrace stackTrace, ProviderContainer container) {
    EduLogger.e('Provider Failed: ${provider.name ?? provider.runtimeType}',
        error, stackTrace);
  }
}
