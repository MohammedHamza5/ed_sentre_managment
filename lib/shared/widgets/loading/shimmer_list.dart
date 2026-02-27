import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double height;
  final EdgeInsetsGeometry padding;

  const ShimmerList({
    super.key,
    this.itemCount = 6,
    this.height = 80.0,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                   const SizedBox(width: 16),
                   // Avatar placeholder
                   CircleAvatar(
                     radius: 24,
                     backgroundColor: Colors.white,
                   ),
                   const SizedBox(width: 16),
                   // Text placeholders
                   Expanded(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Container(
                           width: double.infinity,
                           height: 14,
                           color: Colors.white,
                         ),
                         const SizedBox(height: 8),
                         Container(
                           width: 100,
                           height: 10,
                           color: Colors.white,
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


