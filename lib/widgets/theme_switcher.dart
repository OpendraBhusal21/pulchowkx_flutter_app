import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ThemeSwitcher extends StatefulWidget {
  final Widget child;

  const ThemeSwitcher({super.key, required this.child});

  static ThemeSwitcherState? of(BuildContext context) {
    return context.findAncestorStateOfType<ThemeSwitcherState>();
  }

  @override
  State<ThemeSwitcher> createState() => ThemeSwitcherState();
}

class ThemeSwitcherState extends State<ThemeSwitcher>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  final GlobalKey _boundaryKey = GlobalKey();
  late AnimationController _animationController;
  bool _isDarkToLight = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _image = null;
        });
        _animationController.reset();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> changeTheme(VoidCallback toggle, Offset offset) async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        toggle();
        return;
      }

      // Capture current state
      final image = await boundary.toImage(
        pixelRatio: WidgetsBinding
            .instance
            .platformDispatcher
            .views
            .first
            .devicePixelRatio,
      );

      final bool isCurrentlyDark =
          Theme.of(_boundaryKey.currentContext!).brightness == Brightness.dark;

      setState(() {
        _image = image;
        _isDarkToLight = isCurrentlyDark;
      });

      // Change theme
      toggle();

      // Start animation
      _animationController.forward();
    } catch (e) {
      debugPrint('Failed to capture theme transition: $e');
      toggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _boundaryKey,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            widget.child,
            if (_image != null)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _FadePainter(
                      image: _image!,
                      fraction: _animationController.value,
                      isDarkToLight: _isDarkToLight,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FadePainter extends CustomPainter {
  final ui.Image image;
  final double fraction;
  final bool isDarkToLight;

  _FadePainter({
    required this.image,
    required this.fraction,
    required this.isDarkToLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    if (isDarkToLight) {
      // Dark -> Light: Requested Fade Out animation
      paint.color = Colors.white.withValues(alpha: 1.0 - fraction);
    } else {
      // Light -> Dark: Requested Fade In animation
      // We draw the OLD image (light) and fade it out to reveal the NEW (dark)
      paint.color = Colors.white.withValues(alpha: 1.0 - fraction);
    }

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, size.width, size.height),
      image: image,
      fit: BoxFit.fill,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FadePainter oldDelegate) {
    return oldDelegate.fraction != fraction;
  }
}
