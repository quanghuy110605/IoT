import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

// --- CẤU HÌNH FIREBASE ---
const firebaseConfig = FirebaseOptions(
  apiKey: "AIzaSyAMqDt8myAePFpsqbw3zh2ItzPAV8VPrK4",
  authDomain: "fir-1esp.firebaseapp.com",
  databaseURL: "https://fir-1esp-default-rtdb.firebaseio.com",
  projectId: "fir-1esp",
  storageBucket: "fir-1esp.firebasestorage.app",
  messagingSenderId: "555400554508",
  appId: "1:555400554508:web:b852a56538d272018ca629",
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseConfig);
  runApp(const MyApp());
}

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
  // Biến trạng thái UI
  bool isDarkMode = true;
  String selectedSensor = "Nhiệt độ";
  DateTime selectedDate = DateTime.now();
  bool isBarChart = false;

  // Biến cài đặt Điều hòa
  double acMinTemp = 16.0;
  double acMaxTemp = 30.0;

  // Tham chiếu Firebase
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("Huy_Project");

  // Hàm chuyển đổi số liệu an toàn từ Firebase
  double _pd(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  // Hàm gửi lệnh điều khiển lên Firebase
  void _updateControl(String node, dynamic value) {
    _dbRef.child("Control/$node").set(value);
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
          " Smart Home Control",
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
      body: StreamBuilder(
        stream: _dbRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Text('Lỗi kết nối!', style: TextStyle(color: txt)),
            );
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          // --- 1. Lấy dữ liệu Current ---
          final current = data['Current'] ?? {};
          final env = current['Environment'] ?? {};
          final air = current['Air'] ?? {};
          final alert = current['Alert'] ?? {};

          double currentTemp = _pd(env['Temp']);
          double currentHumi = _pd(env['Humi']);
          double currentEco2 = _pd(air['eCO2']);
          double currentTvoc = _pd(air['TVOC']);
          int aqiValue = (_pd(air['AQI'])).toInt();
          if (aqiValue == 0) aqiValue = 1;

          String smokeStatus = alert['Smoke']?.toString() ?? "SAFE";
          bool isGasWarning = smokeStatus == "DANGER";

          // --- 2. Lấy dữ liệu Control ---
          final control = data['Control'] ?? {};
          bool isLightOn = control['Light'] == 1 || control['Light'] == true;
          bool isFanOn = control['Fan'] == 1 || control['Fan'] == true;
          bool isBuzzerOn = control['Buzzer'] == 1 || control['Buzzer'] == true;
          bool isAcOn = control['AcOn'] == 1 || control['AcOn'] == true;
          double acTemp = _pd(control['AcTemp'], fallback: 24.0);

          // --- 3. Lấy dữ liệu History vẽ biểu đồ ---
          final history = data['History'] as Map<dynamic, dynamic>? ?? {};
          Map<String, List<FlSpot>> parsedChartData = {
            "Nhiệt độ": [],
            "Độ ẩm": [],
            "Khí gas": [],
            "eCO2": [],
            "TVOC": [],
          };

          if (history.isNotEmpty) {
            var sortedKeys = history.keys.toList()..sort();
            var lastKeys = sortedKeys.length > 25
                ? sortedKeys.sublist(sortedKeys.length - 25)
                : sortedKeys;
            int i = 0;
            for (var key in lastKeys) {
              var entry = history[key];
              if (entry != null) {
                double t = _pd(entry['Environment']?['Temp'] ?? entry['Temp']);
                double h = _pd(entry['Environment']?['Humi'] ?? entry['Humi']);
                double e = _pd(entry['Air']?['eCO2'] ?? entry['eCO2']);
                double tv = _pd(entry['Air']?['TVOC'] ?? entry['TVOC']);
                String s = entry['Alert']?['Smoke'] ?? entry['Smoke'] ?? "SAFE";
                double g = (s == "DANGER" || s == "0") ? 150.0 : 50.0;

                parsedChartData["Nhiệt độ"]!.add(FlSpot(i.toDouble(), t));
                parsedChartData["Độ ẩm"]!.add(FlSpot(i.toDouble(), h));
                parsedChartData["eCO2"]!.add(FlSpot(i.toDouble(), e));
                parsedChartData["TVOC"]!.add(FlSpot(i.toDouble(), tv));
                parsedChartData["Khí gas"]!.add(FlSpot(i.toDouble(), g));
                i++;
              }
            }
          }

          // Cung cấp mảng mặc định nếu history trống
          for (var key in parsedChartData.keys) {
            if (parsedChartData[key]!.isEmpty)
              parsedChartData[key]!.add(const FlSpot(0, 0));
          }

          return LayoutBuilder(
            builder: (ctx, bc) {
              final W = bc.maxWidth;
              final H = bc.maxHeight;
              final pad = (W * 0.014).clamp(10.0, 18.0);
              final gap = (W * 0.010).clamp(6.0, 12.0);

              final leftW = ((W - pad * 2 - gap) * 0.38).clamp(240.0, 400.0);
              final availH = H - pad * 2;
              final gaugeH = (availH * 0.18).clamp(90.0, 115.0);
              final mainH = availH - gaugeH - gap;

              final metricH = (mainH * 0.26).clamp(90.0, 140.0);
              final acH = (mainH * 0.22).clamp(94.0, 115.0);
              final ctrlH = (mainH * 0.26).clamp(90.0, 140.0);
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
                            currentTemp,
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
                            currentHumi,
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
                            currentTvoc,
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
                                // 1. eCO2 / Khí gas / AQI
                                SizedBox(
                                  height: metricH,
                                  child: _metricGrid(
                                    card,
                                    txt,
                                    sub,
                                    leftW,
                                    metricH,
                                    currentEco2,
                                    isGasWarning,
                                    aqiValue,
                                  ),
                                ),
                                SizedBox(height: gap),
                                // 2. Điều hòa
                                SizedBox(
                                  height: acH,
                                  child: _acRemote(
                                    card,
                                    txt,
                                    sub,
                                    isAcOn,
                                    acTemp,
                                  ),
                                ),
                                SizedBox(height: gap),
                                // 3. Đèn / Quạt / Còi báo
                                SizedBox(
                                  height: ctrlH,
                                  child: _controlGrid(
                                    card,
                                    txt,
                                    ctrlH,
                                    isLightOn,
                                    isFanOn,
                                    isBuzzerOn,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: gap),

                          //────── CỘT PHẢI: BIỂU ĐỒ ──────
                          Expanded(
                            child: SizedBox(
                              height: chartH,
                              child: _chartCard(
                                card,
                                txt,
                                sub,
                                parsedChartData[selectedSensor]!,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
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
  // METRIC GRID
  //══════════════════════════════════════════════════════
  Widget _metricGrid(
    Color card,
    Color txt,
    Color sub,
    double leftW,
    double h,
    double eco2,
    bool isGasWarning,
    int aqi,
  ) {
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
      _MI(
        "eCO2",
        "${eco2.toInt()}",
        "ppm",
        Colors.teal,
        Icons.cloud_queue_rounded,
      ),
      _MI(
        "Khí gas",
        isGasWarning ? "CẢNH BÁO" : "AN TOÀN",
        isGasWarning ? "Phát hiện khí gas!" : "Bình thường",
        isGasWarning ? Colors.red : Colors.green,
        isGasWarning ? Icons.gpp_bad_rounded : Icons.verified_user_rounded,
      ),
      _MI("AQI", "$aqi", aqiLabel, aqiColor, Icons.eco_rounded),
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
                if (m.label != "AQI") setState(() => selectedSensor = m.label);
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
  Widget _acRemote(
    Color card,
    Color txt,
    Color sub,
    bool isAcOn,
    double acTemp,
  ) {
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
                            });
                            if (acTemp < min) _updateControl("AcTemp", min);
                            if (acTemp > max) _updateControl("AcTemp", max);
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
                      onChanged: (v) => _updateControl("AcOn", v ? 1 : 0),
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
              _acBtn(Icons.remove, isAcOn, () {
                if (acTemp > acMinTemp) _updateControl("AcTemp", acTemp - 1);
              }),
              Text(
                "${acTemp.toInt()}°C",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isAcOn ? Colors.blue : Colors.grey,
                ),
              ),
              _acBtn(Icons.add, isAcOn, () {
                if (acTemp < acMaxTemp) _updateControl("AcTemp", acTemp + 1);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _acBtn(IconData icon, bool active, VoidCallback fn) => GestureDetector(
    onTap: active ? fn : null,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white12 : Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: active ? Colors.blue : Colors.grey, size: 20),
    ),
  );

  //══════════════════════════════════════════════════════
  // CONTROL GRID
  //══════════════════════════════════════════════════════
  Widget _controlGrid(
    Color card,
    Color txt,
    double h,
    bool isLightOn,
    bool isFanOn,
    bool isBuzzerOn,
  ) {
    final items = [
      _CI(
        "Đèn",
        isLightOn,
        Icons.lightbulb_outline_rounded,
        Colors.amber,
        (v) => _updateControl("Light", v ? 1 : 0),
      ),
      _CI(
        "Quạt",
        isFanOn,
        Icons.wind_power_rounded,
        Colors.cyan,
        (v) => _updateControl("Fan", v ? 1 : 0),
      ),
      _CI(
        "Còi báo",
        isBuzzerOn,
        Icons.campaign_rounded,
        Colors.red,
        (v) => _updateControl("Buzzer", v ? 1 : 0),
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
  Widget _chartCard(Color card, Color txt, Color sub, List<FlSpot> spots) {
    Color color = Colors.orangeAccent;
    if (selectedSensor == "Độ ẩm")
      color = Colors.blueAccent;
    else if (selectedSensor == "Khí gas")
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
                onTap: () => setState(() => isBarChart = !isBarChart),
                child: _pillBtn(
                  isBarChart ? Icons.bar_chart : Icons.show_chart,
                  "",
                  isBarChart ? color : Colors.grey,
                  isBarChart,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _pickDate,
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
  final String label, value, unit;
  final Color color;
  final IconData icon;
  const _MI(this.label, this.value, this.unit, this.color, this.icon);
}

class _CI {
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
  int _step = 0;
  String _learningTitle = "";
  late double _minTemp;
  late double _maxTemp;
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
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted || _isCanceled) return;
      setState(() => _learnedSignals++);
    }

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

    if (_learningTitle == "Nhiệt độ") {
      widget.onRangeSaved(_minTemp, _maxTemp);
    }

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
            style: const TextStyle(
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
