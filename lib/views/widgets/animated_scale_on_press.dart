import 'package:flutter/material.dart';

class AnimatedScaleOnPress extends StatefulWidget {
  const AnimatedScaleOnPress({
    super.key,
    required this.child,
    this.isDisabled = false,
  });

  final Widget child;
  final bool isDisabled;

  @override
  State<AnimatedScaleOnPress> createState() => _AnimatedScaleOnPressState();
}

class _AnimatedScaleOnPressState extends State<AnimatedScaleOnPress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(PointerDownEvent event) {
    if (widget.isDisabled) return;
    _controller.forward();
  }

  void _handleTapUp(PointerUpEvent event) {
    if (widget.isDisabled) return;
    _controller.reverse();
  }

  void _handleTapCancel(PointerCancelEvent event) {
    if (widget.isDisabled) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handleTapDown,
      onPointerUp: _handleTapUp,
      onPointerCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
