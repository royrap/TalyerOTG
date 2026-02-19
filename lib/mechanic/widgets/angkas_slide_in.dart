import 'package:flutter/material.dart';

/// Reusable slide+fade in wrapper to unify mechanic screen loading/content transitions.
/// Usage:
/// AngkasSlideIn(child: YourContent())
class AngkasSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Offset beginOffset;
  final bool fade;

  const AngkasSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOut,
    this.beginOffset = const Offset(0, 0.3),
    this.fade = true,
  });

  @override
  State<AngkasSlideIn> createState() => _AngkasSlideInState();
}

class _AngkasSlideInState extends State<AngkasSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _slide = Tween<Offset>(begin: widget.beginOffset, end: Offset.zero).animate(curved);
    _fade = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AngkasSlideIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.key != widget.child.key) {
      // Restart animation if keyed child changes
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = SlideTransition(position: _slide, child: widget.child);
    if (widget.fade) {
      content = FadeTransition(opacity: _fade, child: content);
    }
    return content;
  }
}










