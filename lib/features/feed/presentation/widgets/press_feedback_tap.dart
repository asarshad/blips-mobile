import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef PressFeedbackTapBuilder = Widget Function(
    BuildContext context, PressFeedbackTapState state);

class PressFeedbackTapState {
  const PressFeedbackTapState({
    required this.isPressed,
    required this.scale,
    required this.duration,
    required this.curve,
    required this.onTap,
    required this.onHighlightChanged,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  final bool isPressed;
  final double scale;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onTap;
  final ValueChanged<bool> onHighlightChanged;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;
}

/// Adds subtle pressed-state scale and selection haptics to a tap target.
class PressFeedbackTap extends StatefulWidget {
  const PressFeedbackTap({
    required this.builder,
    this.onTap,
    this.pressedScale = 0.94,
    this.duration = const Duration(milliseconds: 90),
    this.curve = Curves.easeOutCubic,
    super.key,
  });

  final PressFeedbackTapBuilder builder;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;
  final Curve curve;

  @override
  State<PressFeedbackTap> createState() => _PressFeedbackTapState();
}

class _PressFeedbackTapState extends State<PressFeedbackTap> {
  var _isPressed = false;

  void _setPressed(bool isPressed) {
    if (_isPressed == isPressed || !mounted) {
      return;
    }
    setState(() {
      _isPressed = isPressed;
    });
  }

  void _handleHighlightChanged(bool isHighlighted) {
    _setPressed(isHighlighted);
  }

  void _handleTapDown(TapDownDetails _) {
    _setPressed(true);
  }

  void _handleTapUp(TapUpDetails _) {
    _setPressed(false);
  }

  void _handleTapCancel() {
    _setPressed(false);
  }

  void _handleTap() {
    final onTap = widget.onTap;
    if (onTap == null) {
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      PressFeedbackTapState(
        isPressed: _isPressed,
        scale: _isPressed ? widget.pressedScale : 1,
        duration: widget.duration,
        curve: widget.curve,
        onTap: widget.onTap == null ? null : _handleTap,
        onHighlightChanged: _handleHighlightChanged,
        onTapDown: widget.onTap == null ? null : _handleTapDown,
        onTapUp: widget.onTap == null ? null : _handleTapUp,
        onTapCancel: widget.onTap == null ? null : _handleTapCancel,
      ),
    );
  }
}
