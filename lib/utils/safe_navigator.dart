import 'package:flutter/material.dart';

/// Utility extension on BuildContext to safely pop navigator routes without throwing assertion errors.
extension SafeNavigatorExtension on BuildContext {
  /// Safely pops the top route from the Navigator stack if popping is possible.
  /// Prevents `_history.isNotEmpty` assertions and black screen crashes.
  bool safePop<T extends Object?>([T? result]) {
    final navigator = Navigator.maybeOf(this);
    if (navigator != null && navigator.canPop()) {
      navigator.pop<T>(result);
      return true;
    }
    return false;
  }
}
