import 'package:flutter/material.dart';

class ScreenUtil {
  static late ScreenUtil _instance;
  static bool _initialized = false;

  final double width;
  final double height;

  ScreenUtil._({required this.width, required this.height});

  static void init(BuildContext context, {double designWidth = 390, double designHeight = 844}) {
    final size = MediaQuery.of(context).size;
    _instance = ScreenUtil._(width: size.width, height: size.height);
    _initialized = true;
  }

  static double get scaleWidth => _initialized ? _instance.width / 390.0 : 1.0;
  static double get scaleHeight => _initialized ? _instance.height / 844.0 : 1.0;
  static double get scaleText => scaleWidth;
}

extension ScreenUtilExtension on num {
  double get w => this * ScreenUtil.scaleWidth;
  double get h => this * ScreenUtil.scaleHeight;
  double get sp => this * ScreenUtil.scaleText;
  double get r => this * ScreenUtil.scaleWidth;
}

class REdgeInsets extends EdgeInsets {
  REdgeInsets.fromLTRB(double left, double top, double right, double bottom)
      : super.fromLTRB(left.w, top.h, right.w, bottom.h);

  REdgeInsets.all(double value)
      : super.fromLTRB(value.r, value.r, value.r, value.r);

  REdgeInsets.only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) : super.fromLTRB(left.w, top.h, right.w, bottom.h);

  REdgeInsets.symmetric({double vertical = 0, double horizontal = 0})
      : super.fromLTRB(horizontal.w, vertical.h, horizontal.w, vertical.h);
}

class RSizedBox extends SizedBox {
  RSizedBox({
    super.key,
    double? width,
    double? height,
    super.child,
  }) : super(
          width: width?.w,
          height: height?.h,
        );

  RSizedBox.vertical(double height, {super.key, super.child})
      : super(height: height.h);

  RSizedBox.horizontal(double width, {super.key, super.child})
      : super(width: width.w);
}

class RBorderRadius extends BorderRadius {
  RBorderRadius.all(Radius radius)
      : super.all(Radius.circular(radius.x.r));

  RBorderRadius.circular(double radius)
      : super.circular(radius.r);

  RBorderRadius.vertical({
    Radius top = Radius.zero,
    Radius bottom = Radius.zero,
  }) : super.vertical(
          top: Radius.circular(top.x.r),
          bottom: Radius.circular(bottom.x.r),
        );

  RBorderRadius.horizontal({
    Radius left = Radius.zero,
    Radius right = Radius.zero,
  }) : super.horizontal(
          left: Radius.circular(left.x.r),
          right: Radius.circular(right.x.r),
        );

  RBorderRadius.only({
    Radius topLeft = Radius.zero,
    Radius topRight = Radius.zero,
    Radius bottomLeft = Radius.zero,
    Radius bottomRight = Radius.zero,
  }) : super.only(
          topLeft: Radius.circular(topLeft.x.r),
          topRight: Radius.circular(topRight.x.r),
          bottomLeft: Radius.circular(bottomLeft.x.r),
          bottomRight: Radius.circular(bottomRight.x.r),
        );
}
