import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'ir_learning_dialog.dart';

class AcRemoteWidget extends StatelessWidget {
  final Color card;
  final Color txt;
  final Color sub;
  final bool isAcOn;
  final double acTemp;
  final bool isDarkMode;
  final double acMinTemp;
  final double acMaxTemp;
  final DatabaseReference dbRef;
  final Function(String, dynamic) onUpdateControl;
  final Function(double, double) onRangeSaved;

  const AcRemoteWidget({
    super.key,
    required this.card,
    required this.txt,
    required this.sub,
    required this.isAcOn,
    required this.acTemp,
    required this.isDarkMode,
    required this.acMinTemp,
    required this.acMaxTemp,
    required this.dbRef,
    required this.onUpdateControl,
    required this.onRangeSaved,
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

  @override
  Widget build(BuildContext context) {
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
                        builder: (ctx) => IrLearningDialog(
                          isDarkMode: isDarkMode,
                          currentMinTemp: acMinTemp,
                          currentMaxTemp: acMaxTemp,
                          dbRef: dbRef,
                          onRangeSaved: onRangeSaved,
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
                      onChanged: (v) => onUpdateControl("AcOn", v ? 1 : 0),
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
                if (acTemp > acMinTemp) onUpdateControl("AcTemp", acTemp - 1);
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
                if (acTemp < acMaxTemp) onUpdateControl("AcTemp", acTemp + 1);
              }),
            ],
          ),
        ],
      ),
    );
  }
}
