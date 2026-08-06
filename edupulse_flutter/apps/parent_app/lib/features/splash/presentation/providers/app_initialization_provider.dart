import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/bootstrap_provider.dart';

class AppInitializationNotifier extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> initialize() async {
    state = const AsyncValue.loading();
    
    final result = ref.read(bootstrapResultProvider);
    
    // Brief delay to ensure smooth logo fading transition
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (result.success) {
      state = const AsyncValue.data(null);
    } else {
      state = AsyncValue.error(
        result.errorMessage ?? 'Bootstrap failed',
        StackTrace.current,
      );
    }
  }
}

final appInitializationProvider =
    NotifierProvider.autoDispose<AppInitializationNotifier, AsyncValue<void>>(
  AppInitializationNotifier.new,
);
