import 'package:flutter/widgets.dart';

/// Synchronizes [controller] text with controller state without clobbering active IME composition.
void syncTextControllerWithImeGuard(
  TextEditingController controller,
  String nextText,
) {
  if (controller.text == nextText) {
    return;
  }

  // Korean Hangul jamo assembly holds an active composing range; preserve it while non-empty.
  if (nextText.isNotEmpty && !controller.value.composing.isCollapsed) {
    return;
  }

  controller.value = TextEditingValue(
    text: nextText,
    selection: TextSelection.collapsed(offset: nextText.length),
  );
}
