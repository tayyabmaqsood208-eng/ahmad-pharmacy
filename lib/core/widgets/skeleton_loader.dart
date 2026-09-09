import 'package:flutter/material.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class SkeletonTableLoader extends StatelessWidget {
  final int rows;

  const SkeletonTableLoader({super.key, this.rows = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        rows,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: const [
              SkeletonLoader(width: 40, height: 40, borderRadius: 10),
              SizedBox(width: 16),
              Expanded(child: SkeletonLoader(height: 20)),
              SizedBox(width: 16),
              SkeletonLoader(width: 100, height: 20),
              SizedBox(width: 16),
              SkeletonLoader(width: 80, height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
