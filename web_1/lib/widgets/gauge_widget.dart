import 'package:flutter/material.dart';

class GaugeWidget extends StatelessWidget {
  final String title;
  final double val;
  final double max;
  final String unit;
  final Color color;
  final Color card;
  final Color txt;
  final double h;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const GaugeWidget({
    super.key,
    required this.title,
    required this.val,
    required this.max,
    required this.unit,
    required this.color,
    required this.card,
    required this.txt,
    required this.h,
    required this.isSelected,
    required this.isDarkMode,
    required this.onTap,
  });

  BoxDecoration _boxDec(Color bg, Color border, double radius) => BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border, width: 1.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDarkMode ? 0.35 : 0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final circD = (h * 0.56).clamp(36.0, 52.0);
    final fs = (h * 0.145).clamp(10.0, 14.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: h * 0.12,
          vertical: h * 0.08,
        ),
        decoration: _boxDec(
          isSelected ? color.withValues(alpha: 0.12) : card,
          isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
          16,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Giữ min cho UI di động
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: circD,
              height: circD,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: max > 0 ? (val / max) : 0,
                    color: color,
                    strokeWidth: 5,
                    backgroundColor: Colors.black12,
                  ),
                  Text(
                    "${val.toInt()}",
                    style: TextStyle(
                      fontSize: fs,
                      fontWeight: FontWeight.bold,
                      color: txt,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: h * 0.10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Thu gọn theo content
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: fs * 0.85,
                    color: isDarkMode ? Colors.white60 : Colors.grey,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: fs,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
