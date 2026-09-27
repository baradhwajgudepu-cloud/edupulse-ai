import 'package:flutter/material.dart';

/// Guard widget to prevent accidental exits from root screens.
///
/// Uses Flutter's modern [PopScope] API to intercept back navigation
/// and require a double-tap within [exitDuration] (or confirmation) before exiting.
class RootExitGuard extends StatefulWidget {
  final Widget child;
  final String exitMessage;
  final Duration exitDuration;
  final Future<bool> Function(BuildContext context)? onConfirmExit;

  const RootExitGuard({
    super.key,
    required this.child,
    this.exitMessage = 'Press back again to exit the app',
    this.exitDuration = const Duration(seconds: 2),
    this.onConfirmExit,
  });

  @override
  State<RootExitGuard> createState() => _RootExitGuardState();
}

class _RootExitGuardState extends State<RootExitGuard> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        if (widget.onConfirmExit != null) {
          final shouldExit = await widget.onConfirmExit!(context);
          if (shouldExit && context.mounted) {
            Navigator.of(context).pop(result);
          }
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > widget.exitDuration) {
          _lastBackPressTime = now;
          if (context.mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(widget.exitMessage),
                duration: widget.exitDuration,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            Navigator.of(context).pop(result);
          }
        }
      },
      child: widget.child,
    );
  }
}

/// Guard widget for forms with unsaved changes.
///
/// If [isDirty] is true, intercepts back navigation via [PopScope]
/// and presents a confirmation dialog preventing accidental data loss.
class UnsavedFormGuard extends StatelessWidget {
  final bool isDirty;
  final Widget child;
  final String title;
  final String message;
  final String discardLabel;
  final String continueLabel;
  final VoidCallback? onDiscard;

  const UnsavedFormGuard({
    super.key,
    required this.isDirty,
    required this.child,
    this.title = 'Discard Unsaved Changes?',
    this.message = 'You have unsaved changes. Are you sure you want to discard them and leave?',
    this.discardLabel = 'Discard',
    this.continueLabel = 'Keep Editing',
    this.onDiscard,
  });

  Future<bool> _showConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(continueLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
            child: Text(discardLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        final shouldDiscard = await _showConfirmDialog(context);
        if (shouldDiscard && context.mounted) {
          onDiscard?.call();
          Navigator.of(context).pop(result);
        }
      },
      child: child,
    );
  }
}

/// Responsive scroll container that guarantees small screen safety (320dp - 430dp+).
///
/// Prevents keyboard inset overflows and enforces full-height scrolling
/// without unbounded constraints.
class ResponsiveSafeAreaScroll extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool fillRemaining;

  const ResponsiveSafeAreaScroll({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.fillRemaining = true,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: physics,
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: fillRemaining ? (constraints.maxHeight - padding.vertical) : 0,
                minWidth: constraints.maxWidth,
              ),
              child: IntrinsicHeight(
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
