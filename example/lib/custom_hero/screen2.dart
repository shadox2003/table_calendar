import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:table_calendar_example/custom_hero/screen1.dart';

class Screen2 extends StatefulWidget {
  @override
  State<Screen2> createState() => _Screen2State();
}

class _Screen2State extends State<Screen2> {
  Offset _offset = Offset.zero;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onPanUpdate: (detail) {
          setState(() {
            _offset += detail.delta;
          });
        },
        onPanEnd: (detail) {
          Navigator.pop(context);
        },
        child: Center(
          child: Stack(
            children: [
              Positioned(
                left: _offset.dx + 100,
                top: _offset.dy + 100,
                child: Hero(
                  tag: 'blackBox',
                  child: Container(
                    width: 50,
                    height: 50,
                    color: Colors.red,
                    alignment: Alignment.center,
                    child: Text(
                      'SCREEN 2',
                      style: kStyle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// class CircularRectTween extends RectTween {
//   CircularRectTween({required Rect? begin, required Rect? end}) : super(begin: begin, end: end);
//
//   @override
//   Rect lerp(double t) {
//     final double width = lerpDouble(begin?.width, end?.width, t) ?? 0;
//     double startWidthCenter = (begin?.left ?? 0) + ((begin?.width ?? 0) / 2);
//     double startHeightCenter = (begin?.top ?? 0) + ((begin?.height ?? 0) / 2);
//
//     return Rect.fromCircle(center: Offset(startWidthCenter, startHeightCenter), radius: width * 1.7);
//   }
// }

class FlipcardTransition extends AnimatedWidget {
  final Animation<double> flipAnim;
  final Widget child;

  FlipcardTransition({required this.flipAnim, required this.child}) : super(listenable: flipAnim);

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.identity()..rotateY(-pi * flipAnim.value),
      alignment: FractionalOffset.center,
      child: child,
    );
  }
}
