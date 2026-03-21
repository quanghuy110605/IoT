import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class IrLearningDialog extends StatefulWidget {
  final bool isDarkMode;
  final double currentMinTemp;
  final double currentMaxTemp;
  final DatabaseReference dbRef;
  final Function(double, double) onRangeSaved;

  const IrLearningDialog({
    super.key,
    required this.isDarkMode,
    required this.currentMinTemp,
    required this.currentMaxTemp,
    required this.dbRef,
    required this.onRangeSaved,
  });

  @override
  State<IrLearningDialog> createState() => _IrLearningDialogState();
}

class _IrLearningDialogState extends State<IrLearningDialog> {
  int _step = 0;
  String _learningTitle = "";
  late double _minTemp;
  late double _maxTemp;

  int _targetSignals = 0;
  int _learnedSignals = 0;
  bool _isCanceled = false;

  StreamSubscription? _dbSubscription;
  String _currentTarget = "";

  // --- CHỐT CHẶN AN TOÀN ---
  bool _isWaitingForDone = false;

  @override
  void initState() {
    super.initState();
    _minTemp = widget.currentMinTemp;
    _maxTemp = widget.currentMaxTemp;
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    if (_isCanceled) widget.dbRef.child("Control/LearnTarget").set("IDLE");
    super.dispose();
  }

  // Sửa thành hàm async để bắt buộc chờ Firebase
  Future<void> _startSingleSignal(String title, String firebaseTarget) async {
    setState(() {
      _step = 2;
      _learningTitle = title;
      _targetSignals = 1;
      _learnedSignals = 0;
      _isCanceled = false;
      _currentTarget = firebaseTarget;
    });
    _listenToFirebase();
    await _sendTargetToFirebase(firebaseTarget);
  }

  // Sửa thành hàm async để bắt buộc chờ Firebase
  Future<void> _startTempRangeSignal() async {
    setState(() {
      _step = 2;
      _learningTitle = "Nhiệt độ";
      _targetSignals = (_maxTemp - _minTemp).toInt() + 1;
      _learnedSignals = 0;
      _isCanceled = false;
      _currentTarget = _minTemp.toInt().toString();
    });
    _listenToFirebase();
    await _sendTargetToFirebase(_currentTarget);
  }

  // HÀM MỚI: Chuyên xử lý gửi lệnh và bắt lỗi
  Future<void> _sendTargetToFirebase(String target) async {
    try {
      _isWaitingForDone = false; // Khóa tai nghe lại

      // Bắt buộc chờ Google phản hồi ghi thành công
      await widget.dbRef.child("Control/LearnTarget").set(target);

      // Ghi thành công rồi mới mở tai nghe để chờ chữ "DONE" từ ESP32
      _isWaitingForDone = true;
    } catch (e) {
      // NẾU LỖI QUYỀN TRUY CẬP SẼ BÁO ĐỎ Ở ĐÂY
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi gửi Firebase: Bị từ chối quyền truy cập!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _listenToFirebase() {
    _dbSubscription?.cancel();
    _dbSubscription = widget.dbRef.child("Control/LearnTarget").onValue.listen((
      event,
    ) async {
      if (_isCanceled) return;
      final val = event.snapshot.value?.toString();

      // LOGIC CHUẨN: Chỉ nhảy số nếu thấy chữ DONE **VÀ** Web đang được phép chờ
      if (val == "DONE" && _isWaitingForDone) {
        _isWaitingForDone =
            false; // Khóa tai nghe ngay lập tức để chống lặp vòng

        setState(() => _learnedSignals++);

        if (_learnedSignals < _targetSignals) {
          if (_learningTitle == "Nhiệt độ") {
            int nextTemp = _minTemp.toInt() + _learnedSignals;
            _currentTarget = nextTemp.toString();
            await _sendTargetToFirebase(_currentTarget); // Gửi số tiếp theo
          }
        } else {
          _dbSubscription?.cancel();
          await widget.dbRef.child("Control/LearnTarget").set("IDLE");
          _finishLearning();
        }
      }
    });
  }

  void _finishLearning() {
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
            () => _startSingleSignal("Bật Điều Hòa", "ON"),
          ),
          const SizedBox(height: 12),
          _btn(
            "Tắt Điều Hòa",
            Icons.power_off_rounded,
            Colors.red,
            txt,
            () => _startSingleSignal("Tắt Điều Hòa", "OFF"),
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
      String currentActionLabel = "";
      if (_learningTitle == "Nhiệt độ") {
        currentActionLabel = "$_currentTarget°C";
      } else {
        currentActionLabel = _learningTitle;
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
                  widget.dbRef.child("Control/LearnTarget").set("IDLE");
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
            "Hãy bấm nút sau trên Remote:",
            style: TextStyle(fontSize: 14, color: sub),
          ),
          const SizedBox(height: 8),
          Text(
            currentActionLabel,
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
