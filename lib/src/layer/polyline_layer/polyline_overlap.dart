import 'dart:ui';

import 'package:meta/meta.dart';

/// Detects overlapping segments between polylines and computes per-segment
/// offset signs so that overlapping portions are offset in opposite directions.
@internal
class PolylineOverlapDetector {
  const PolylineOverlapDetector._();

  /// Computes per-polyline, per-segment offset signs.
  ///
  /// Returns a `List<List<int>>` where `result[i][j]` is the offset sign for
  /// polyline `i`, segment `j`:
  /// - `0` means no overlap (draw at original position)
  /// - `+1` means offset in the positive direction
  /// - `-1` means offset in the negative direction
  ///
  /// [polylinePoints] are the projected (screen-space) points for each
  /// polyline.
  /// [tolerance] is the maximum squared distance between corresponding
  /// endpoints (in projected coordinates) for two segments to be considered
  /// overlapping.
  /// [polylineGroups] maps each polyline index to its group key. Only
  /// polylines with the same non-null group are compared. Polylines with a
  /// `null` group are excluded from overlap detection.
  static List<List<int>> computeOverlapSigns({
    required List<List<Offset>> polylinePoints,
    required double tolerance,
    required List<String?> polylineGroups,
  }) {
    final toleranceSq = tolerance * tolerance;
    final numPolylines = polylinePoints.length;

    // Initialize signs: 0 = no overlap for each segment of each polyline
    final signs = <List<int>>[];
    for (int i = 0; i < numPolylines; i++) {
      final numSegments =
          polylinePoints[i].length > 1 ? polylinePoints[i].length - 1 : 0;
      signs.add(List<int>.filled(numSegments, 0));
    }

    // Compare each pair of polylines within the same group
    for (int i = 0; i < numPolylines; i++) {
      final pointsI = polylinePoints[i];
      final groupI = polylineGroups[i];
      if (groupI == null) continue; // not participating in offset

      for (int j = i + 1; j < numPolylines; j++) {
        final groupJ = polylineGroups[j];
        if (groupJ != groupI) continue; // different group, skip

        final pointsJ = polylinePoints[j];

        // Compare segments of polyline i with segments of polyline j
        for (int si = 0; si < pointsI.length - 1; si++) {
          final a1 = pointsI[si];
          final a2 = pointsI[si + 1];

          for (int sj = 0; sj < pointsJ.length - 1; sj++) {
            final b1 = pointsJ[sj];
            final b2 = pointsJ[sj + 1];

            if (_segmentsOverlap(a1, a2, b1, b2, toleranceSq)) {
              // Mark both segments as overlapping
              // Polyline with smaller index gets +1, larger gets -1
              if (signs[i][si] == 0) signs[i][si] = 1;
              if (signs[j][sj] == 0) signs[j][sj] = -1;
            }
          }
        }
      }
    }

    return signs;
  }

  /// Checks whether two segments overlap.
  ///
  /// Two segments overlap if either:
  /// - Both endpoints of segment A are close to segment B (within tolerance), or
  /// - Both endpoints of segment B are close to segment A (within tolerance).
  ///
  /// Also checks same-direction overlap (A→B matches B→B direction) and
  /// reverse-direction overlap (A→B matches B in reverse).
  static bool _segmentsOverlap(
      Offset a1, Offset a2, Offset b1, Offset b2, double toleranceSq) {
    // Forward: a1≈b1 and a2≈b2
    if (_distanceSq(a1, b1) <= toleranceSq &&
        _distanceSq(a2, b2) <= toleranceSq) {
      return true;
    }
    // Reverse: a1≈b2 and a2≈b1
    if (_distanceSq(a1, b2) <= toleranceSq &&
        _distanceSq(a2, b1) <= toleranceSq) {
      return true;
    }

    // Also check point-to-segment proximity for partial overlaps:
    // If both endpoints of A are close to segment B
    if (_pointToSegmentDistSq(a1, b1, b2) <= toleranceSq &&
        _pointToSegmentDistSq(a2, b1, b2) <= toleranceSq) {
      return true;
    }
    // If both endpoints of B are close to segment A
    if (_pointToSegmentDistSq(b1, a1, a2) <= toleranceSq &&
        _pointToSegmentDistSq(b2, a1, a2) <= toleranceSq) {
      return true;
    }

    return false;
  }

  static double _distanceSq(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return dx * dx + dy * dy;
  }

  /// Squared distance from point [p] to segment [s1]-[s2].
  static double _pointToSegmentDistSq(Offset p, Offset s1, Offset s2) {
    final dx = s2.dx - s1.dx;
    final dy = s2.dy - s1.dy;
    final lenSq = dx * dx + dy * dy;

    if (lenSq == 0) return _distanceSq(p, s1);

    // Parametric position on segment
    var t = ((p.dx - s1.dx) * dx + (p.dy - s1.dy) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);

    final projX = s1.dx + t * dx;
    final projY = s1.dy + t * dy;
    final pdx = p.dx - projX;
    final pdy = p.dy - projY;
    return pdx * pdx + pdy * pdy;
  }
}
