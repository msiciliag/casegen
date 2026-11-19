import 'dart:math' as math;
import 'package:flutter/material.dart';

const orange = Color(0xFFFF5117);
const paper = Color(0xFFF5F5EF);
const ink = Color(0xFF171815);
const muted = Color(0xFF595B54);
const line = Color(0xFFD5D6CE);

// A dot screen shaped like sound waves, film perforations or a game controller.
class Cover extends CustomPainter {
  final String id;
  final Color color;
  Cover(this.id, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final unit = size.shortestSide / 25;
    for (var x = unit / 2; x < size.width; x += unit) {
      for (var y = unit / 2; y < size.height; y += unit) {
        final u = (x - size.width / 2) / size.height;
        final v = (y - size.height / 2) / size.height;
        double fill;
        if (id == 'mulan') {
          final strip = (v + u * .38).abs();
          fill = strip < .34 && !(strip > .22 && (u * 6).floor().isEven)
              ? 1
              : .06;
        } else if (id == 'stadia') {
          final body =
              math.pow(u.abs() / .46, 4) +
              math.pow((v - u.abs() * .28) / .23, 2);
          final buttons =
              (u + .23).abs() < .035 && v.abs() < .11 ||
              (u + .23).abs() < .1 && v.abs() < .035 ||
              math.pow(u - .22, 2) + math.pow(v, 2) < .006;
          fill = body < 1 && !buttons ? 1 : .06;
        } else {
          final amplitude =
              .07 +
              .34 *
                  (.5 + .5 * math.cos(u * 5)) *
                  (.65 + .35 * math.cos(u * 19));
          fill = v.abs() < amplitude ? 1 - v.abs() * .75 : .11;
        }
        canvas.drawCircle(Offset(x, y), unit * .41 * fill, paint);
      }
    }
  }

  @override
  bool shouldRepaint(Cover old) => id != old.id || color != old.color;
}
