import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';

class ControlGridWidget extends StatelessWidget {
  final Color card;
  final Color txt;
  final double h;
  final bool isLightOn;
  final bool isFanOn;
  final bool isBuzzerOn;
  final Function(String, dynamic) onUpdateControl;

  const ControlGridWidget({
    super.key,
    required this.card,
    required this.txt,
    required this.h,
    required this.isLightOn,
    required this.isFanOn,
    required this.isBuzzerOn,
    required this.onUpdateControl,
  });

  BoxDecoration _boxDec(Color bg, Color border, double radius) => BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border, width: 1.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04), // simplified shadow
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final items = [
      ControlItem(
        "Đèn",
        isLightOn,
        Icons.lightbulb_outline_rounded,
        Colors.amber,
        (v) => onUpdateControl("Light", v ? 1 : 0),
      ),
      ControlItem(
        "Quạt",
        isFanOn,
        Icons.wind_power_rounded,
        Colors.cyan,
        (v) => onUpdateControl("Fan", v ? 1 : 0),
        canTurnOn: false,
      ),
      ControlItem(
        "Còi báo",
        isBuzzerOn,
        Icons.campaign_rounded,
        Colors.red,
        (v) => onUpdateControl("Buzzer", v ? 1 : 0),
        canTurnOn: false,
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
              onTap: () {
                if (!item.canTurnOn && !item.isOn) return;
                item.onChange(!item.isOn);
              },
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
                        onChanged: (!item.canTurnOn && !item.isOn) ? null : item.onChange,
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
}
