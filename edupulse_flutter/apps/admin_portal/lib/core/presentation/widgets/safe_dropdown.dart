import 'package:flutter/material.dart';
import '../utils/dropdown_safety.dart';

/// A DropdownButtonFormField that automatically guarantees:
/// 1. Every DropdownMenuItem value is unique (removes duplicate values).
/// 2. [value] is strictly verified against available item values. If [value] is missing from [items],
///    it falls back to [fallbackValue] (default null) to prevent Flutter assertion crashes.
class SafeDropdownButtonFormField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final Widget? hint;
  final Widget? disabledHint;
  final bool isExpanded;
  final bool isDense;
  final T? fallbackValue;
  final FormFieldValidator<T>? validator;
  final Key? formFieldKey;
  final Widget? icon;
  final Color? dropdownColor;
  final int elevation;
  final TextStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;

  const SafeDropdownButtonFormField({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.decoration = const InputDecoration(),
    this.hint,
    this.disabledHint,
    this.isExpanded = true,
    this.isDense = false,
    this.fallbackValue,
    this.validator,
    this.formFieldKey,
    this.icon,
    this.dropdownColor,
    this.elevation = 8,
    this.style,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Ensure all items have strictly unique values
    final sanitizedItems = DropdownSafety.safeMenuItems(items: items);

    // 2. Ensure value is represented exactly once or safely fallback
    final safeVal = DropdownSafety.safeValue(
      selectedValue: value,
      validValues: sanitizedItems.map((i) => i.value),
      fallback: fallbackValue,
    );

    return DropdownButtonFormField<T>(
      key: formFieldKey,
      // ignore: deprecated_member_use
      value: safeVal,
      items: sanitizedItems,
      onChanged: onChanged,
      decoration: decoration,
      hint: hint,
      disabledHint: disabledHint,
      isExpanded: isExpanded,
      isDense: isDense,
      validator: validator,
      icon: icon ?? const Icon(Icons.arrow_drop_down),
      dropdownColor: dropdownColor,
      elevation: elevation,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
    );
  }
}

/// A DropdownButton that automatically guarantees:
/// 1. Every DropdownMenuItem value is unique (removes duplicate values).
/// 2. [value] is strictly verified against available item values. If [value] is missing from [items],
///    it falls back to [fallbackValue] (default null) to prevent Flutter assertion crashes.
class SafeDropdownButton<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget? hint;
  final Widget? disabledHint;
  final bool isExpanded;
  final T? fallbackValue;
  final Key? buttonKey;
  final Widget? underline;
  final Widget? icon;
  final Color? dropdownColor;
  final int elevation;
  final TextStyle? style;
  final FocusNode? focusNode;
  final bool autofocus = false;

  const SafeDropdownButton({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.hint,
    this.disabledHint,
    this.isExpanded = false,
    this.fallbackValue,
    this.buttonKey,
    this.underline,
    this.icon,
    this.dropdownColor,
    this.elevation = 8,
    this.style,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Ensure all items have strictly unique values
    final sanitizedItems = DropdownSafety.safeMenuItems(items: items);

    // 2. Ensure value is represented exactly once or safely fallback
    final safeVal = DropdownSafety.safeValue(
      selectedValue: value,
      validValues: sanitizedItems.map((i) => i.value),
      fallback: fallbackValue,
    );

    return DropdownButton<T>(
      key: buttonKey,
      value: safeVal,
      items: sanitizedItems,
      onChanged: onChanged,
      hint: hint,
      disabledHint: disabledHint,
      isExpanded: isExpanded,
      underline: underline,
      icon: icon ?? const Icon(Icons.arrow_drop_down),
      dropdownColor: dropdownColor,
      elevation: elevation,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
    );
  }
}
