import 'dart:math' as math;
import 'dart:ui';

import 'package:meta/meta.dart';

@internal
class PolylineOffsetHelper {
  const PolylineOffsetHelper._();

  static List<Offset> offsetPoints(List<Offset> points, double offset) {
    if (points.isEmpty) return [];
    // No need to simplify, as points are already simplified by flutter_map

    final offsetSegments = _offsetPointLine(points, offset);
    return _joinLineSegments(offsetSegments, offset);
  }

  static List<_OffsetSegment> _offsetPointLine(
      List<Offset> points, double distance) {
    final offsetSegments = <_OffsetSegment>[];

    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];

      if (a == b) continue;

      // angles in (-PI, PI]
      final segmentAngle = math.atan2(a.dy - b.dy, a.dx - b.dx);
      final offsetAngle = segmentAngle - math.pi / 2;

      offsetSegments.push(_OffsetSegment(
        offsetAngle: offsetAngle,
        original: [a, b],
        offset: [
          _translatePoint(a, distance, offsetAngle),
          _translatePoint(b, distance, offsetAngle),
        ],
      ));
    }

    return offsetSegments;
  }

  static List<Offset> _joinLineSegments(
      List<_OffsetSegment> segments, double offset) {
    final joinedPoints = <Offset>[];
    final first = segments.firstOrNull;
    final last = segments.lastOrNull;

    if (first != null && last != null) {
      joinedPoints.add(first.offset[0]);
      for (int i = 0; i < segments.length - 1; i++) {
        final s1 = segments[i];
        final s2 = segments[i + 1];
        joinedPoints.addAll(_joinSegments(s1, s2, offset));
      }
      joinedPoints.add(last.offset[1]);
    }

    return joinedPoints;
  }

  static List<Offset> _joinSegments(
      _OffsetSegment s1, _OffsetSegment s2, double offset) {
    // TODO: different join styles
    return _circularArc(s1, s2, offset).whereType<Offset>().toList();
  }

  static List<Offset> _circularArc(
      _OffsetSegment s1, _OffsetSegment s2, double distance) {
    // if the segments are the same angle,
    // there should be a single join point
    if (s1.offsetAngle == s2.offsetAngle) {
      return [s1.offset[1]];
    }

    final signedAngle = _getSignedAngle(s1.offset, s2.offset);
    // for inner angles, just find the offset segments intersection
    if ((signedAngle * distance > 0) &&
        (signedAngle *
                _getSignedAngle(s1.offset, [s1.offset[0], s2.offset[1]]) >
            0)) {
      final intersect = _intersection(
          s1.offset[0], s1.offset[1], s2.offset[0], s2.offset[1]);
      if (intersect != null) {
        return [intersect];
      }
    }

    // draws a circular arc with R = offset distance, C = original meeting point
    final points = <Offset>[];
    final center = s1.original[1];
    // ensure angles go in the anti-clockwise direction
    final rightOffset = distance > 0;
    final startAngle = rightOffset ? s2.offsetAngle : s1.offsetAngle;
    var endAngle = rightOffset ? s1.offsetAngle : s2.offsetAngle;
    // and that the end angle is bigger than the start angle
    if (endAngle < startAngle) {
      endAngle += math.pi * 2;
    }
    final step = math.pi / 8;
    for (var alpha = startAngle; alpha < endAngle; alpha += step) {
      points.add(_translatePoint(center, distance, alpha));
    }
    points.add(_translatePoint(center, distance, endAngle));

    return rightOffset ? points.reversed.toList() : points;
  }

  static double _getSignedAngle(List<Offset> s1, List<Offset> s2) {
    final a = _segmentAsVector(s1);
    final b = _segmentAsVector(s2);
    return math.atan2(a.dx * b.dy - a.dy * b.dx, a.dx * b.dx + a.dy * b.dy);
  }

  static Offset _segmentAsVector(List<Offset> s) {
    return Offset(s[1].dx - s[0].dx, s[1].dy - s[0].dy);
  }

  static Offset? _intersection(Offset l1a, Offset l1b, Offset l2a, Offset l2b) {
    final line1 = _lineEquation(l1a, l1b);
    final line2 = _lineEquation(l2a, l2b);

    if (line1 == null || line2 == null) {
      return null;
    }

    if (line1.x != null) {
      return line2.x != null
          ? null
          : Offset(line1.x!, line2.a! * line1.x! + line2.b!);
    }
    if (line2.x != null) {
      return Offset(line2.x!, line1.a! * line2.x! + line1.b!);
    }

    if (line1.a == line2.a) {
      return null;
    }

    final x = (line2.b! - line1.b!) / (line1.a! - line2.a!);
    return Offset(x, line1.a! * x + line1.b!);
  }

  static _LineEquation? _lineEquation(Offset pt1, Offset pt2) {
    if (pt1.dx == pt2.dx) {
      return pt1.dy == pt2.dy ? null : _LineEquation(x: pt1.dx);
    }

    final a = (pt2.dy - pt1.dy) / (pt2.dx - pt1.dx);
    return _LineEquation(
      a: a,
      b: pt1.dy - a * pt1.dx,
    );
  }

  static Offset _translatePoint(Offset pt, double dist, double heading) {
    return Offset(
      pt.dx + dist * math.cos(heading),
      pt.dy + dist * math.sin(heading),
    );
  }
}

class _LineEquation {
  final double? x;
  final double? a;
  final double? b;

  _LineEquation({this.x, this.a, this.b});
}

class _OffsetSegment {
  final double offsetAngle;
  final List<Offset> original;
  final List<Offset> offset;

  _OffsetSegment({
    required this.offsetAngle,
    required this.original,
    required this.offset,
  });
}

extension on List<_OffsetSegment> {
  void push(_OffsetSegment segment) => add(segment);
}
