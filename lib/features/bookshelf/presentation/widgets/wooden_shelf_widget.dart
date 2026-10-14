import 'package:flutter/material.dart';

class WoodenShelfWidget extends StatelessWidget {
  final List<Widget> children;

  const WoodenShelfWidget({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: children,
          ),
        ),
        // Shelf Plank Graphic
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5A2B), Color(0xFF654321), Color(0xFF4A2F13)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
