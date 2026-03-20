import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const IoTDashboard(),
    );
  }
}

class IoTDashboard extends StatefulWidget {
  const IoTDashboard({super.key});
  @override
  State<IoTDashboard> createState() => _IoTDashboardState();
}

class _IoTDashboardState extends State<IoTDashboard> {
  bool isDarkMode = false;
  bool isLightOn = false;
  bool isFanOn = false;
  bool isBuzzerOn = false;
  double acTemp = 24.0;
  double acMinTemp = 16.0;
  double acMaxTemp = 30.0;
  bool isAcOn = false;
  String selectedSensor = "Nhiệt độ";
  DateTime selectedDate = DateTime.now();
  bool isBarChart = false;

  final Map<String, List<FlSpot>> sensorData = {
    "Nhiệt độ": List.generate(25, (i) {
      const v = [
        25.0,
        24.5,
        24.0,
        23.8,
        23.5,
        23.2,
        23.8,
        24.5,
        25.5,
        26.8,
        27.5,
        28.2,
        28.8,
        29.0,
        28.5,
        28.0,
        27.5,
        27.2,
        27.0,
        26.8,
        26.5,
        26.2,
        25.8,
        25.5,
        25.0,
      ];
      return FlSpot(i.toDouble(), v[i]);
    }),
    "Độ ẩm": List.generate(25, (i) {
      const v = [
        68.0,
        70.0,
        71.5,
        72.0,
        72.5,
        73.0,
        72.0,
        70.5,
        68.0,
        65.0,
        62.5,
        60.0,
        58.5,
        57.0,
        58.0,
        59.5,
        61.0,
        62.5,
        63.5,
        64.5,
        65.5,
        66.0,
        66.5,
        67.0,
        68.0,
      ];
      return FlSpot(i.toDouble(), v[i]);
    }),
    "Khí gas": List.generate(25, (i) {
      const v = [
        100.0,
        98.0,
        97.0,
        96.0,
        95.0,
        95.0,
        96.0,
        98.0,
        105.0,
        115.0,
        125.0,
        140.0,
        150.0,
        148.0,
        142.0,
        135.0,
        128.0,
        122.0,
        118.0,
        115.0,
        112.0,
        110.0,
        108.0,
        103.0,
        100.0,
      ];
      return FlSpot(i.toDouble(), v[i]);
    }),
    "eCO2": List.generate(25, (i) {
      const v = [
        400.0,
        410.0,
        415.0,
        420.0,
        430.0,
        440.0,
        450.0,
        460.0,
        455.0,
        450.0,
        445.0,
        440.0,
        435.0,
        430.0,
        425.0,
        420.0,
        415.0,
        410.0,
        405.0,
        400.0,
        405.0,
        410.0,
        415.0,
        420.0,
        425.0,
      ];
      return FlSpot(i.toDouble(), v[i]);
    }),
    "TVOC": List.generate(25, (i) {
      const v = [
        100.0,
        105.0,
        110.0,
        115.0,
        120.0,
        125.0,
        130.0,
        125.0,
        120.0,
        115.0,
        110.0,
        105.0,
        100.0,
        95.0,
        90.0,
        85.0,
        80.0,
        85.0,
        90.0,
        95.0,
        100.0,
        105.0,
        110.0,
        115.0,
        120.0,
      ];
      return FlSpot(i.toDouble(), v[i]);
    }),
  };

  static const int eco2Value = 450;
  static const int tvocValue = 125;

  int get aqiValue {
    const smoke = 120.0;
    final co2 = eco2Value.toDouble();
    final rawAqi = (((smoke / 1024) * 300 + ((co2 - 400) / 1600) * 200) / 2)
        .clamp(0, 500);
    if (rawAqi <= 50) return 1;
    if (rawAqi <= 100) return 2;
    if (rawAqi <= 150) return 3;
    if (rawAqi <= 200) return 4;
    return 5;
  }

  Color get aqiColor {
    final v = aqiValue;
    if (v == 1) return Colors.green;
    if (v == 2) return Colors.yellow.shade700;
    if (v == 3) return Colors.orange;
    if (v == 4) return Colors.red;
    return Colors.purple;
  }

  String get aqiLabel {
    final v = aqiValue;
    if (v == 1) return "Tốt";
    if (v == 2) return "Trung bình";
    if (v == 3) return "Kém";
    if (v == 4) return "Xấu";
    return "Nguy hiểm";
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? const Color(0xFF111827) : const Color(0xFFF1F5FB);
    final card = isDarkMode ? const Color(0xFF1F2937) : Colors.white;
    final txt = isDarkMode ? Colors.white : Colors.black87;
    final sub = isDarkMode ? Colors.white54 : Colors.grey;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        toolbarHeight: 44,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Huy Smart Home Control",
          style: TextStyle(
            color: txt,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        actions: [
          Icon(
            isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: txt,
            size: 18,
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: isDarkMode,
              onChanged: (v) => setState(() => isDarkMode = v),
              activeThumbColor: Colors.blueAccent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (ctx, bc) {
          final W = bc.maxWidth;
          final H = bc.maxHeight;
          final pad = (W * 0.014).clamp(10.0, 18.0);
          final gap = (W * 0.010).clamp(6.0, 12.0);

          // Left column = 38% of usable width
          final leftW = ((W - pad * 2 - gap) * 0.38).clamp(240.0, 400.0);
          // Available height inside padding
          final availH = H - pad * 2;
          // Gauge row: 18% of height — bigger cards
          final gaugeH = (availH * 0.18).clamp(90.0, 115.0);
          // Remaining after gauge + gap
          final mainH = availH - gaugeH - gap;
          // Left section heights (proportional to mainH)
          final metricH = (mainH * 0.26).clamp(90.0, 140.0);
          final acH = (mainH * 0.22).clamp(94.0, 115.0);
          final ctrlH = (mainH * 0.26).clamp(90.0, 140.0);
          // Chart = same as mainH (fills full height)
          final chartH = mainH;

          return Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //──────────────────── GAUGE ROW ────────────────────
                SizedBox(
                  height: gaugeH,
                  child: Row(
                    children: [
                      _gauge(
                        "Nhiệt độ",
                        28.5,
                        50,
                        "°C",
                        Colors.orangeAccent,
                        card,
                        txt,
                        gaugeH,
                      ),
                      SizedBox(width: gap),
                      _gauge(
                        "Độ ẩm",
                        65,
                        100,
                        "%",
                        Colors.blueAccent,
                        card,
                        txt,
                        gaugeH,
                      ),
                      SizedBox(width: gap),
                      _gauge(
                        "TVOC",
                        tvocValue.toDouble(),
                        500,
                        "ppb",
                        Colors.purple,
                        card,
                        txt,
                        gaugeH,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: gap),

                //──────────────────── MAIN ROW ─────────────────────
                SizedBox(
                  height: mainH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //────── CỘT TRÁI ──────
                      SizedBox(
                        width: leftW,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. eCO2 / TVOC / AQI
                            SizedBox(
                              height: metricH,
                              child: _metricGrid(
                                card,
                                txt,
                                sub,
                                leftW,
                                metricH,
                              ),
                            ),
                            SizedBox(height: gap),
                            // 2. Điều hòa
                            SizedBox(height: acH, child: _acRemote(card, txt)),
                            SizedBox(height: gap),
                            // 3. Đèn / Quạt / Còi báo
                            SizedBox(
                              height: ctrlH,
                              child: _controlGrid(card, txt, ctrlH),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: gap),

                      //────── CỘT PHẢI: BIỂU ĐỒ ──────
                      Expanded(
                        child: SizedBox(
                          height: chartH,
                          child: _chartCard(card, txt, sub),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  //══════════════════════════════════════════════════════
  // GAUGE CARD
  //══════════════════════════════════════════════════════
  Widget _gauge(
    String title,
    double val,
    double max,
    String unit,
    Color color,
    Color card,
    Color txt,
    double h,
  ) {
    final sel = selectedSensor == title;
    final circD = (h * 0.56).clamp(36.0, 52.0);
    final fs = (h * 0.145).clamp(10.0, 14.0);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedSensor = title),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: h * 0.12,
            vertical: h * 0.08,
          ),
          decoration: _boxDec(
            sel ? color.withValues(alpha: 0.12) : card,
            sel ? color.withValues(alpha: 0.5) : Colors.transparent,
            16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: circD,
                height: circD,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: val / max,
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
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  //══════════════════════════════════════════════════════
  // METRIC GRID (eCO2 / TVOC / AQI) — 2 or 3 cards per row
  //══════════════════════════════════════════════════════
  Widget _metricGrid(Color card, Color txt, Color sub, double leftW, double h) {
    // Current gas value (from sensor config, typically dynamic, here static 120 approx)
    final gasValue = 120;
    final isGasWarning = gasValue > 150;

    final items = [
      _MI("eCO2", "$eco2Value", "ppm", Colors.teal, Icons.cloud_queue_rounded),
      _MI(
        "Khí gas",
        isGasWarning ? "CẢNH BÁO" : "AN TOÀN",
        isGasWarning ? "Phát hiện khí gas!" : "Bình thường",
        isGasWarning ? Colors.red : Colors.green,
        isGasWarning ? Icons.gpp_bad_rounded : Icons.verified_user_rounded,
      ),
      _MI("AQI", "$aqiValue", aqiLabel, aqiColor, Icons.eco_rounded),
    ];
    final iconSz = (h * 0.22).clamp(18.0, 28.0);
    final valSz = (h * 0.20).clamp(16.0, 26.0);
    final lblSz = (h * 0.10).clamp(9.0, 13.0);

    return Row(
      children: items.asMap().entries.map((e) {
        final m = e.value;
        final isLast = e.key == items.length - 1;
        // Map metric label back to sensor key for chart
        String sensorKey = m.label;

        final isSelected = selectedSensor == sensorKey;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 6),
            child: GestureDetector(
              onTap: () {
                if (sensorKey != "AQI") {
                  setState(() => selectedSensor = sensorKey);
                }
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

  //══════════════════════════════════════════════════════
  // ĐIỀU HÒA
  //══════════════════════════════════════════════════════
  Widget _acRemote(Color card, Color txt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: _boxDec(card, Colors.transparent, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.thermostat_rounded,
                    color: isAcOn ? Colors.blue : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Điều hòa",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: txt,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Cài đặt IR
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => _IrLearningDialog(
                          isDarkMode: isDarkMode,
                          currentMinTemp: acMinTemp,
                          currentMaxTemp: acMaxTemp,
                          onRangeSaved: (min, max) {
                            setState(() {
                              acMinTemp = min;
                              acMaxTemp = max;
                              if (acTemp < acMinTemp) acTemp = acMinTemp;
                              if (acTemp > acMaxTemp) acTemp = acMaxTemp;
                            });
                          },
                        ),
                      );
                    },
                    child: Icon(
                      Icons.settings_rounded,
                      color: isDarkMode ? Colors.white54 : Colors.grey,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Transform.scale(
                    scale: 0.82,
                    child: Switch(
                      value: isAcOn,
                      onChanged: (v) => setState(() => isAcOn = v),
                      activeThumbColor: Colors.blue,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _acBtn(Icons.remove, () {
                if (acTemp > acMinTemp) setState(() => acTemp--);
              }),
              Text(
                "${acTemp.toInt()}°C",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isAcOn ? Colors.blue : Colors.grey,
                ),
              ),
              _acBtn(Icons.add, () {
                if (acTemp < acMaxTemp) setState(() => acTemp++);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _acBtn(IconData icon, VoidCallback fn) => GestureDetector(
    onTap: isAcOn ? fn : null,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white12 : Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: isAcOn ? Colors.blue : Colors.grey, size: 20),
    ),
  );

  //══════════════════════════════════════════════════════
  // CONTROL GRID (Đèn / Quạt / Còi báo)
  //══════════════════════════════════════════════════════
  Widget _controlGrid(Color card, Color txt, double h) {
    final items = [
      _CI(
        "Đèn",
        isLightOn,
        Icons.lightbulb_outline_rounded,
        Colors.amber,
        (v) => setState(() => isLightOn = v),
      ),
      _CI(
        "Quạt",
        isFanOn,
        Icons.wind_power_rounded,
        Colors.cyan,
        (v) => setState(() => isFanOn = v),
      ),
      _CI(
        "Còi báo",
        isBuzzerOn,
        Icons.campaign_rounded,
        Colors.red,
        (v) => setState(() => isBuzzerOn = v),
      ),
    ];
    final iconSz = (h * 0.25).clamp(20.0, 32.0);
    final lblSz = (h * 0.115).clamp(10.0, 14.0);
    final swScale = (h * 0.010).clamp(0.70, 0.90);

    return Row(
      children: items.asMap().entries.map((e) {
        final item = e.value;
        final isLast = e.key == items.length - 1;
        final active = item.isOn;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 6),
            child: GestureDetector(
              onTap: () => item.onChange(!item.isOn),
              child: Container(
                decoration: _boxDec(
                  active ? item.color.withValues(alpha: 0.13) : card,
                  active
                      ? item.color.withValues(alpha: 0.55)
                      : Colors.transparent,
                  16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      color: active ? item.color : Colors.grey,
                      size: iconSz,
                    ),
                    SizedBox(height: h * 0.05),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: lblSz,
                        fontWeight: FontWeight.w600,
                        color: active ? item.color : txt,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: h * 0.03),
                    Transform.scale(
                      scale: swScale,
                      child: Switch(
                        value: active,
                        onChanged: item.onChange,
                        activeThumbColor: item.color,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  //══════════════════════════════════════════════════════
  // CHART CARD
  //══════════════════════════════════════════════════════
  Widget _chartCard(Color card, Color txt, Color sub) {
    Color color = Colors.orangeAccent;
    if (selectedSensor == "Độ ẩm") {
      color = Colors.blueAccent;
    } else if (selectedSensor == "Khí gas") {
      color = Colors.redAccent;
    } else if (selectedSensor == "eCO2") {
      color = Colors.teal;
    } else if (selectedSensor == "TVOC") {
      color = Colors.purple;
    }
    final spots = sensorData[selectedSensor]!;
    final minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final yPad = (maxY - minY) * 0.18;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: _boxDec(card, Colors.transparent, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
              // Toggle
              GestureDetector(
                onTap: () => setState(() => isBarChart = !isBarChart),
                child: _pillBtn(
                  isBarChart ? Icons.bar_chart : Icons.show_chart,
                  "",
                  isBarChart ? color : Colors.grey,
                  isBarChart,
                ),
              ),
              const SizedBox(width: 8),
              // Date
              GestureDetector(
                onTap: _pickDate,
                child: _pillBtn(
                  Icons.calendar_today,
                  "${selectedDate.day.toString().padLeft(2, '0')}/"
                  "${selectedDate.month.toString().padLeft(2, '0')}/"
                  "${selectedDate.year}",
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
        maxX: 24,
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
                    "${s.x.toInt().toString().padLeft(2, '0')}:00\n${s.y.toStringAsFixed(1)}",
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
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
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
                if (v == meta.max || v == meta.min)
                  return const SizedBox.shrink();
                return Text(
                  v.toStringAsFixed(0),
                  style: TextStyle(fontSize: 10, color: sub),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
              "${g.x.toString().padLeft(2, '0')}:00\n${rod.toY.toStringAsFixed(1)}",
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

  FlTitlesData _titles(
    Color sub,
    double minY,
    double maxY,
    double step,
  ) => FlTitlesData(
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
          if (v == meta.max || v == meta.min) return const SizedBox.shrink();
          return Text(
            v.toStringAsFixed(0),
            style: TextStyle(fontSize: 10, color: sub),
          );
        },
      ),
    ),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  );

  //══════════════════════════════════════════════════════
  // HELPERS
  //══════════════════════════════════════════════════════

  //══════════════════════════════════════════════════════
  // HELPERS
  //══════════════════════════════════════════════════════

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
}

// ── Data classes ──────────────────────────────────────
class _MI {
  // Metric Item
  final String label, value, unit;
  final Color color;
  final IconData icon;
  const _MI(this.label, this.value, this.unit, this.color, this.icon);
}

class _CI {
  // Control Item
  final String label;
  final bool isOn;
  final IconData icon;
  final Color color;
  final void Function(bool) onChange;
  const _CI(this.label, this.isOn, this.icon, this.color, this.onChange);
}

// ── Widget Học IR ──────────────────────────────────────────
class _IrLearningDialog extends StatefulWidget {
  final bool isDarkMode;
  final double currentMinTemp;
  final double currentMaxTemp;
  final Function(double, double) onRangeSaved;

  const _IrLearningDialog({
    Key? key,
    required this.isDarkMode,
    required this.currentMinTemp,
    required this.currentMaxTemp,
    required this.onRangeSaved,
  }) : super(key: key);

  @override
  State<_IrLearningDialog> createState() => _IrLearningDialogState();
}

class _IrLearningDialogState extends State<_IrLearningDialog> {
  int _step = 0; // 0: Menu, 1: Chọn dải nhiệt độ, 2: Đang học lệnh
  String _learningTitle = "";

  // Biến cho thanh chọn nhiệt độ
  late double _minTemp;
  late double _maxTemp;

  // Logic mô phỏng IR
  int _targetSignals = 0;
  int _learnedSignals = 0;
  bool _isCanceled = false;

  @override
  void initState() {
    super.initState();
    _minTemp = widget.currentMinTemp;
    _maxTemp = widget.currentMaxTemp;
  }

  void _startSingleSignal(String title) {
    setState(() {
      _step = 2;
      _learningTitle = title;
      _targetSignals = 1;
      _learnedSignals = 0;
      _isCanceled = false;
    });
    _simulateLearning();
  }

  void _startTempRangeSignal() {
    setState(() {
      _step = 2;
      _learningTitle = "Nhiệt độ";
      _targetSignals = (_maxTemp - _minTemp).toInt() + 1;
      _learnedSignals = 0;
      _isCanceled = false;
    });
    _simulateLearning();
  }

  Future<void> _simulateLearning() async {
    while (_learnedSignals < _targetSignals) {
      // Giả lập chờ tín hiệu IR mất 1.5 giây
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted || _isCanceled) return;
      setState(() => _learnedSignals++);
    }

    // Hoàn tất
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _isCanceled) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(" Đã học xong lệnh $_learningTitle!"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 3),
      ),
    );

    // Lưu lại dải nhiệt độ nếu đang học nhiệt độ
    if (_learningTitle == "Nhiệt độ") {
      widget.onRangeSaved(_minTemp, _maxTemp);
    }

    // Thay vì Pop, ta quay về Menu chính
    setState(() {
      _step = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.isDarkMode ? const Color(0xFF1F2937) : Colors.white;
    final txt = widget.isDarkMode ? Colors.white : Colors.black87;
    final sub = widget.isDarkMode ? Colors.white54 : Colors.grey;

    return Dialog(
      backgroundColor: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildStep(txt, sub),
        ),
      ),
    );
  }

  Widget _buildStep(Color txt, Color sub) {
    if (_step == 0) {
      return Column(
        key: const ValueKey(0),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header("Học lệnh Hồng Ngoại", txt, sub),
          const SizedBox(height: 12),
          Text(
            "Chọn một chức năng để thiết lập mã điều khiển từ remote gốc.",
            style: TextStyle(fontSize: 14, color: sub),
          ),
          const SizedBox(height: 24),
          _btn(
            "Bật Điều Hòa",
            Icons.power_settings_new_rounded,
            Colors.green,
            txt,
            () => _startSingleSignal("Bật Điều Hòa"),
          ),
          const SizedBox(height: 12),
          _btn(
            "Tắt Điều Hòa",
            Icons.power_off_rounded,
            Colors.red,
            txt,
            () => _startSingleSignal("Tắt Điều Hòa"),
          ),
          const SizedBox(height: 12),
          _btn(
            "Học dải Nhiệt Độ",
            Icons.thermostat_rounded,
            Colors.blue,
            txt,
            () => setState(() => _step = 1),
          ),
        ],
      );
    } else if (_step == 1) {
      return Column(
        key: const ValueKey(1),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: txt),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _step = 0),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Chọn khoảng Nhiệt độ",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: txt,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Chọn ngưỡng thấp nhất và cao nhất để học. Hệ thống sẽ tự động quét qua các mức nhiệt này.",
            style: TextStyle(fontSize: 14, color: sub),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _tempPicker(
                "Min",
                _minTemp,
                (v) {
                  if (v < _maxTemp) setState(() => _minTemp = v);
                },
                txt,
                sub,
              ),
              const Icon(Icons.arrow_right_alt_rounded, color: Colors.grey),
              _tempPicker(
                "Max",
                _maxTemp,
                (v) {
                  if (v > _minTemp) setState(() => _maxTemp = v);
                },
                txt,
                sub,
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _startTempRangeSignal,
              child: const Text(
                "Tiếp tục",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Step 2: Learning
      String currentAction = "";
      if (_learningTitle == "Nhiệt độ") {
        int currentTemp = (_minTemp + _learnedSignals).toInt();
        if (currentTemp > _maxTemp.toInt()) currentTemp = _maxTemp.toInt();
        currentAction = "$currentTemp°C";
      } else {
        currentAction = _learningTitle;
      }

      return Column(
        key: const ValueKey(2),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.close, color: sub),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _isCanceled = true;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          Icon(
            Icons.wifi_tethering_rounded,
            size: 60,
            color: Colors.blueAccent.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 20),
          Text(
            "Đang chờ tín hiệu ",
            style: TextStyle(fontSize: 14, color: sub),
          ),
          const SizedBox(height: 8),
          Text(
            currentAction,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _targetSignals == 0
                  ? 0
                  : (_learnedSignals / _targetSignals),
              minHeight: 12,
              backgroundColor: widget.isDarkMode
                  ? Colors.white10
                  : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Tiến độ: $_learnedSignals / $_targetSignals",
            style: TextStyle(
              fontSize: 13,
              color: sub,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
  }

  Widget _header(String title, Color txt, Color sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: txt,
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: sub),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _btn(
    String label,
    IconData icon,
    Color color,
    Color txtColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: txtColor),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tempPicker(
    String title,
    double val,
    Function(double) onChanged,
    Color txt,
    Color sub,
  ) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: sub, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: txt),
              onPressed: () => onChanged(val - 1),
            ),
            SizedBox(
              width: 40,
              child: Text(
                "${val.toInt()}°C",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: txt,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: txt),
              onPressed: () => onChanged(val + 1),
            ),
          ],
        ),
      ],
    );
  }
}
