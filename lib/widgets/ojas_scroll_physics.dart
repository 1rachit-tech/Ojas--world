import 'package:flutter/material.dart';

class OjasZeroJankScrollPhysics extends BouncingScrollPhysics {
  const OjasZeroJankScrollPhysics({super.parent});

  @override
  OjasZeroJankScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return OjasZeroJankScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 50.0;

  @override
  double get maxFlingVelocity => 8000.0;

  @override
  double frictionFactor(double overscrollFraction) => 0.65;
}
