import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';

class MetricGridWidget extends StatelessWidget {
  final Color card;
  final Color txt;
  final Color sub;
  final double leftW;
  final double h;
  final double eco2;
  final bool isGasWarning;
  final int aqi;
  final String selectedSensor;
  final Function(String) onSensorSelected;

  const MetricGridWidget({
    Key? key,
    required this.card,
    required this.txt,
    required this.sub,
    required this.leftW,
    required this.h,
    required this.eco2,
    required this.isGasWarning,
    required this.aqi,
    required this.selectedSensor,
    required this.onSensorSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String aqiLabel = "Tốt";
    Color aqiColor = Colors.green;
    if (aqi == 2) {
      aqiLabel = "Trung bình";
      aqiColor = Colors.yellow.shade700;
    } else if (aqi == 3) {
      aqiLabel = "Kém";
      aqiColor = Colors.orange;
    } else if (aqi == 4) {
      aqiLabel = "Xấu";
      aqiColor = Colors.red;
    } else if (aqi >= 5) {
      aqiLabel = "Nguy hiểm";
      aqiColor = Colors.purple;
    }

    final items = [
      MetricItem(
        "eCO2",
        "${eco2.toInt()}",
        "ppm",
        Colors.teal,
        Icons.cloud_queue_rounded,
      ),
      MetricItem(
        "Khí gas",
        isGasWarning ? "CẢNH BÁO" : "AN TOÀN",
        isGasWarning ? "Phát hiện khí gas!" : "Bình thường",
        isGasWarning ? Colors.red : Colors.green,
        isGasWarning ? Icons.gpp_bad_rounded : Icons.verified_user_rounded,
      ),
      MetricItem("AQI", "$aqi", aqiLabel, aqiColor, Icons.eco_rounded),
    ];

    final iconSz = (h * 0.22).clamp(18.0, 28.0);
    final valSz = (h * 0.20).clamp(16.0, 26.0);
    final lblSz = (h * 0.10).clamp(9.0, 13.0);

    return Row(
      children: items.asMap().entries.map((e) {
        final m = e.value;
        final isLast = e.key == items.length - 1;
        final isSelected = selectedSensor == m.label;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 6),
            child: GestureDetector(
              onTap: () {
                if (m.label != "AQI") onSensorSelected(m.label);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? m.color.withValues(alpha: 0.15)
                      : m.color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? m.color
                        : m.color.withValues(alpha: 0.25),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(m.icon, color: m.color, size: iconSz),
                    SizedBox(height: h * 0.04),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        m.value,
                        style: TextStyle(
                          fontSize: valSz,
                          fontWeight: FontWeight.bold,
                          color: m.color,
                        ),
                      ),
                    ),
                    Text(
                      m.label,
                      style: TextStyle(fontSize: lblSz, color: sub),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      m.unit,
                      style: TextStyle(
                        fontSize: lblSz,
                        color: m.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
