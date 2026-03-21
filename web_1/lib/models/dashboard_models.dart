import 'package:flutter/material.dart';

class MetricItem {
  final String label, value, unit;
  final Color color;
  final IconData icon;
  const MetricItem(this.label, this.value, this.unit, this.color, this.icon);
}

class ControlItem {
  final String label;
  final bool isOn;
  final IconData icon;
  final Color color;
  final void Function(bool) onChange;
  const ControlItem(this.label, this.isOn, this.icon, this.color, this.onChange);
}
