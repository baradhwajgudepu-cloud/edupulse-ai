import 'package:flutter_web_plugins/url_strategy.dart';

/// Configures path-based URL strategy on Flutter Web so deep links like
/// `/reset-password?token=...` are correctly parsed by GoRouter.
void configureUrlStrategy() {
  usePathUrlStrategy();
}
