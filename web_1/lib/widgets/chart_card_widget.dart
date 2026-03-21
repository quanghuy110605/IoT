import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ChartCardWidget extends StatelessWidget {
  final Color card;
  final Color txt;
  final Color sub;
  final bool isDarkMode;
  final String selectedSensor;
  final List<FlSpot> spots;
  final bool isBarChart;
  final DateTime selectedDate;
  final VoidCallback onToggleChartType;
  final VoidCallback onPickDate;

  const ChartCardWidget({
    super.key,
    required this.card,
    required this.txt,
    required this.sub,
    required this.isDarkMode,
    required this.selectedSensor,
    required this.spots,
    required this.isBarChart,
    required this.selectedDate,
    required this.onToggleChartType,
    required this.onPickDate,
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

  Widget _pillBtn(
    IconData icon,
    String label,
    Color color,
    bool active, {
    Color? forceColor,
  }) {
    final c = forceColor ?? (active ? color : Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.12)
            : (isDarkMode ? Colors.white10 : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: c,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  FlTitlesData _titles(Color sub, double minY, double maxY, double step) =>
      FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 6,
            reservedSize: 26,
            getTitlesWidget: (v, _) {
              final h = v.toInt();
              if (h % 6 != 0) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "${h.toString().padLeft(2, '0')}:00",
                  style: TextStyle(fontSize: 10, color: sub),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 46,
            interval: step,
            getTitlesWidget: (v, meta) {
              if (v == meta.max || v == meta.min) {
                return const SizedBox.shrink();
              }
              return Text(
                v.toStringAsFixed(0),
                style: TextStyle(fontSize: 10, color: sub),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      );

  Widget _lineChart(
    List<FlSpot> spots,
    Color color,
    Color sub,
    double minY,
    double maxY,
    double yPad,
  ) {
    final double step = (maxY - minY <= 0)
        ? 1.0
        : ((maxY - minY) / 4).ceilToDouble();
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: spots.length > 1 ? spots.last.x : 24,
        minY: minY - yPad,
        maxY: maxY + yPad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: step,
          verticalInterval: 6,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.15 : 0.06),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.15 : 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _titles(sub, minY, maxY, step),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, idx) =>
                  FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.07),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (pts) => pts
                .map(
                  (s) => LineTooltipItem(
                    "${s.x.toInt()}:00\n${s.y.toStringAsFixed(1)}",
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _barChart(
    List<FlSpot> spots,
    Color color,
    Color sub,
    double minY,
    double maxY,
    double yPad,
  ) {
    final double step = (maxY - minY <= 0)
        ? 1.0
        : ((maxY - minY) / 4).ceilToDouble();
    final groups = spots
        .where((s) => s.x.toInt() % 2 == 0)
        .map(
          (s) => BarChartGroupData(
            x: s.x.toInt(),
            barRods: [
              BarChartRodData(
                toY: s.y,
                color: color,
                width: 12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY + yPad,
                  color: Colors.black.withValues(
                    alpha: isDarkMode ? 0.08 : 0.03,
                  ),
                ),
              ),
            ],
          ),
        )
        .toList();

    return BarChart(
      BarChartData(
        minY: minY - yPad,
        maxY: maxY + yPad,
        barGroups: groups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.15 : 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _titles(sub, minY, maxY, step),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
              "${g.x}:00\n${rod.toY.toStringAsFixed(1)}",
              const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color color = Colors.orangeAccent;
    if (selectedSensor == "Độ ẩm") {
      color = Colors.blueAccent;
    } else if (selectedSensor == "Khí gas")
      color = Colors.redAccent;
    else if (selectedSensor == "eCO2")
      color = Colors.teal;
    else if (selectedSensor == "TVOC")
      color = Colors.purple;

    double minY = 0, maxY = 10;
    if (spots.isNotEmpty) {
      minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    }
    if (minY == maxY) {
      minY -= 5;
      maxY += 5;
    }
    final yPad = (maxY - minY) * 0.18;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: _boxDec(card, Colors.transparent, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Lịch sử: $selectedSensor",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: txt,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onToggleChartType,
                child: _pillBtn(
                  isBarChart ? Icons.bar_chart : Icons.show_chart,
                  "",
                  isBarChart ? color : Colors.grey,
                  isBarChart,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onPickDate,
                child: _pillBtn(
                  Icons.calendar_today,
                  "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}",
                  Colors.blueAccent,
                  false,
                  forceColor: Colors.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isBarChart
                ? _barChart(spots, color, sub, minY, maxY, yPad)
                : _lineChart(spots, color, sub, minY, maxY, yPad),
          ),
        ],
      ),
    );
  }
}
