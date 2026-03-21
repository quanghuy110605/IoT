import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';

import '../widgets/gauge_widget.dart';
import '../widgets/metric_grid_widget.dart';
import '../widgets/ac_remote_widget.dart';
import '../widgets/control_grid_widget.dart';
import '../widgets/chart_card_widget.dart';

class IoTDashboard extends StatefulWidget {
  const IoTDashboard({super.key});
  @override
  State<IoTDashboard> createState() => _IoTDashboardState();
}

class _IoTDashboardState extends State<IoTDashboard> {
  bool isDarkMode = true;
  String selectedSensor = "Nhiệt độ";
  DateTime selectedDate = DateTime.now();
  bool isBarChart = false;

  double acMinTemp = 16.0;
  double acMaxTemp = 30.0;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("Huy_Project");

  double _pd(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

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
      body: StreamBuilder(
        stream: _dbRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Lỗi kết nối!', style: TextStyle(color: txt)),
            );
          }
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

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

          final control = data['Control'] ?? {};
          bool isLightOn = control['Light'] == 1 || control['Light'] == true;
          bool isFanOn = control['Fan'] == 1 || control['Fan'] == true;
          bool isBuzzerOn = control['Buzzer'] == 1 || control['Buzzer'] == true;
          bool isAcOn = control['AcOn'] == 1 || control['AcOn'] == true;
          double acTemp = _pd(control['AcTemp'], fallback: 24.0);

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

          for (var key in parsedChartData.keys) {
            if (parsedChartData[key]!.isEmpty) {
              parsedChartData[key]!.add(const FlSpot(0, 0));
            }
          }

          return LayoutBuilder(
            builder: (ctx, bc) {
              final W = bc.maxWidth;
              final isDesktop = W >= 800;
              final H = bc.maxHeight;
              final pad = (W * 0.014).clamp(10.0, 18.0);
              final gap = (W * 0.010).clamp(6.0, 16.0);

              final availH = H - pad * 2;
              final gaugeHDesktop = (availH * 0.18).clamp(90.0, 115.0);
              final gaugeHMobile = 100.0;
              final gaugeH = isDesktop ? gaugeHDesktop : gaugeHMobile;

              final leftW = isDesktop ? ((W - pad * 2 - gap) * 0.38).clamp(240.0, 400.0) : (W - pad * 2);

              final metricsDesktopH = ((availH - gaugeHDesktop - gap) * 0.26).clamp(90.0, 140.0);
              final acDesktopH = ((availH - gaugeHDesktop - gap) * 0.22).clamp(94.0, 115.0);
              final ctrlDesktopH = ((availH - gaugeHDesktop - gap) * 0.26).clamp(90.0, 140.0);

              final metricH = isDesktop ? metricsDesktopH : 120.0;
              final acH = isDesktop ? acDesktopH : 120.0;
              final ctrlH = isDesktop ? ctrlDesktopH : 120.0;
              final chartH = isDesktop ? (availH - gaugeHDesktop - gap) : 320.0;

              final gaugeWidgets = [
                GaugeWidget(
                  title: "Nhiệt độ",
                  val: currentTemp,
                  max: 50,
                  unit: "°C",
                  color: Colors.orangeAccent,
                  card: card,
                  txt: txt,
                  h: gaugeH,
                  isSelected: selectedSensor == "Nhiệt độ",
                  isDarkMode: isDarkMode,
                  onTap: () => setState(() => selectedSensor = "Nhiệt độ"),
                ),
                GaugeWidget(
                  title: "Độ ẩm",
                  val: currentHumi,
                  max: 100,
                  unit: "%",
                  color: Colors.blueAccent,
                  card: card,
                  txt: txt,
                  h: gaugeH,
                  isSelected: selectedSensor == "Độ ẩm",
                  isDarkMode: isDarkMode,
                  onTap: () => setState(() => selectedSensor = "Độ ẩm"),
                ),
                GaugeWidget(
                  title: "TVOC",
                  val: currentTvoc,
                  max: 500,
                  unit: "ppb",
                  color: Colors.purple,
                  card: card,
                  txt: txt,
                  h: gaugeH,
                  isSelected: selectedSensor == "TVOC",
                  isDarkMode: isDarkMode,
                  onTap: () => setState(() => selectedSensor = "TVOC"),
                ),
              ];

              final colChildren = [
                if (isDesktop)
                  SizedBox(
                    height: gaugeH,
                    child: Row(
                      children: gaugeWidgets.asMap().entries.map((e) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: e.key != gaugeWidgets.length - 1 ? gap : 0),
                            child: e.value,
                          ),
                        );
                      }).toList(),
                    ),
                  )
                else
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    alignment: WrapAlignment.center,
                    children: gaugeWidgets,
                  ),
                SizedBox(height: gap),
                if (isDesktop)
                  SizedBox(
                    height: availH - gaugeHDesktop - gap,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: leftW,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: metricH,
                                child: MetricGridWidget(
                                  card: card,
                                  txt: txt,
                                  sub: sub,
                                  leftW: leftW,
                                  h: metricH,
                                  eco2: currentEco2,
                                  isGasWarning: isGasWarning,
                                  aqi: aqiValue,
                                  selectedSensor: selectedSensor,
                                  onSensorSelected: (sensor) => setState(() => selectedSensor = sensor),
                                ),
                              ),
                              SizedBox(height: gap),
                              SizedBox(
                                height: acH,
                                child: AcRemoteWidget(
                                  card: card,
                                  txt: txt,
                                  sub: sub,
                                  isAcOn: isAcOn,
                                  acTemp: acTemp,
                                  isDarkMode: isDarkMode,
                                  acMinTemp: acMinTemp,
                                  acMaxTemp: acMaxTemp,
                                  dbRef: _dbRef,
                                  onUpdateControl: _updateControl,
                                  onRangeSaved: (min, max) {
                                    setState(() {
                                      acMinTemp = min;
                                      acMaxTemp = max;
                                    });
                                    if (acTemp < min) _updateControl("AcTemp", min);
                                    if (acTemp > max) _updateControl("AcTemp", max);
                                  },
                                ),
                              ),
                              SizedBox(height: gap),
                              SizedBox(
                                height: ctrlH,
                                child: ControlGridWidget(
                                  card: card,
                                  txt: txt,
                                  h: ctrlH,
                                  isLightOn: isLightOn,
                                  isFanOn: isFanOn,
                                  isBuzzerOn: isBuzzerOn,
                                  onUpdateControl: _updateControl,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: gap),
                        Expanded(
                          child: SizedBox(
                            height: chartH,
                            child: ChartCardWidget(
                              card: card,
                              txt: txt,
                              sub: sub,
                              isDarkMode: isDarkMode,
                              selectedSensor: selectedSensor,
                              spots: parsedChartData[selectedSensor]!,
                              isBarChart: isBarChart,
                              selectedDate: selectedDate,
                              onToggleChartType: () => setState(() => isBarChart = !isBarChart),
                              onPickDate: _pickDate,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...[
                    SizedBox(
                      height: metricH,
                      child: MetricGridWidget(
                        card: card,
                        txt: txt,
                        sub: sub,
                        leftW: leftW,
                        h: metricH,
                        eco2: currentEco2,
                        isGasWarning: isGasWarning,
                        aqi: aqiValue,
                        selectedSensor: selectedSensor,
                        onSensorSelected: (sensor) => setState(() => selectedSensor = sensor),
                      ),
                    ),
                    SizedBox(height: gap),
                    SizedBox(
                      height: acH,
                      child: AcRemoteWidget(
                        card: card,
                        txt: txt,
                        sub: sub,
                        isAcOn: isAcOn,
                        acTemp: acTemp,
                        isDarkMode: isDarkMode,
                        acMinTemp: acMinTemp,
                        acMaxTemp: acMaxTemp,
                        dbRef: _dbRef,
                        onUpdateControl: _updateControl,
                        onRangeSaved: (min, max) {
                          setState(() {
                            acMinTemp = min;
                            acMaxTemp = max;
                          });
                          if (acTemp < min) _updateControl("AcTemp", min);
                          if (acTemp > max) _updateControl("AcTemp", max);
                        },
                      ),
                    ),
                    SizedBox(height: gap),
                    SizedBox(
                      height: ctrlH,
                      child: ControlGridWidget(
                        card: card,
                        txt: txt,
                        h: ctrlH,
                        isLightOn: isLightOn,
                        isFanOn: isFanOn,
                        isBuzzerOn: isBuzzerOn,
                        onUpdateControl: _updateControl,
                      ),
                    ),
                    SizedBox(height: gap),
                    SizedBox(
                      height: chartH,
                      child: ChartCardWidget(
                        card: card,
                        txt: txt,
                        sub: sub,
                        isDarkMode: isDarkMode,
                        selectedSensor: selectedSensor,
                        spots: parsedChartData[selectedSensor]!,
                        isBarChart: isBarChart,
                        selectedDate: selectedDate,
                        onToggleChartType: () => setState(() => isBarChart = !isBarChart),
                        onPickDate: _pickDate,
                      ),
                    ),
                  ],
              ];

              return isDesktop
                  ? Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: colChildren,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: colChildren,
                      ),
                    );
            },
          );
        },
      ),
    );
  }
}
