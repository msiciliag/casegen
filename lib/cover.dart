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
        if (id.endsWith('-netflix-comedy')) {
          final capsule = u.abs() < .13 && v > -.37 && v < .09;
          final grille = capsule && (v * 18).floor().isEven;
          final cradle =
              v >= .02 && v < .23 && ((u * u + v * v) - .045).abs() < .012;
          final stand =
              (u.abs() < .026 && v > .18 && v < .38) ||
              (v > .35 && v < .39 && u.abs() < .15);
          final rays =
              u.abs() > .38 && ((u.abs() - .45) * 3.4 - v.abs()).abs() < .05;
          fill = grille || cradle || stand || rays ? 1 : .09;
        } else if (id.endsWith('-spotify-authors')) {
          final spread =
              u.abs() < .62 &&
              v.abs() < .3 &&
              v + .12 * u.abs() < .25 &&
              v + .3 * u.abs() > -.32;
          final pageLines = ((v + .3 * u.abs()) * 12).floor().isEven;
          fill = spread && (pageLines || u.abs() < .03) ? 1 : .09;
        } else if (id.endsWith('-walmart-delivery')) {
          final box = u.abs() < .18 && v > .05 && v < .36;
          final rotor = (v + .2).abs() < .04 && (u.abs() - .37).abs() < .21;
          final arm = (v + .09).abs() < .035 && u.abs() < .4;
          fill = box || rotor || arm || (u.abs() < .035 && v.abs() < .15)
              ? 1
              : .09;
        } else if (id == 'mulan') {
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
