import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class BookCoverGenerator extends StatelessWidget {
  final String title;
  final String author;
  final double width;
  final double height;

  const BookCoverGenerator({
    super.key,
    required this.title,
    required this.author,
    this.width = 110,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a consistent aesthetic palette based on title hash
    final hash = title.hashCode.abs();
    final palettes = [
      (const Color(0xFF2C3E50), const Color(0xFF1A252F), AppColors.amberGold),
      (const Color(0xFF8B4513), const Color(0xFF5C2C0E), const Color(0xFFF5DEB3)),
      (const Color(0xFF1E3F20), const Color(0xFF0F2311), const Color(0xFFA3B18A)),
      (const Color(0xFF4A235A), const Color(0xFF2E1138), const Color(0xFFE8DAEF)),
      (const Color(0xFF78281F), const Color(0xFF511812), const Color(0xFFFADBD8)),
    ];

    final (color1, color2, accent) = palettes[hash % palettes.length];

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 6,
            offset: Offset(2, 3),
          ),
        ],
        border: Border.all(color: accent.withOpacity(0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: accent.withOpacity(0.6)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'TAHRİR',
                style: GoogleFonts.inter(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: accent,
                ),
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.literata(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            Text(
              author,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
