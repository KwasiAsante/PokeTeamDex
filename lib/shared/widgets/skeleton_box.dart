import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A shimmer-animated placeholder rectangle, used as a skeleton loader
/// while async tile data is fetching.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width = 120,
    this.height = 12,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[500]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
