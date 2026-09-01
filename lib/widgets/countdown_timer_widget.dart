import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jimpitan/utils/date_helper.dart';

class CountdownTimerWidget extends StatefulWidget {
  final DateTime endDate;
  final Color primaryColor;
  final Color backgroundColor;
  final bool isExpired;

  const CountdownTimerWidget({
    super.key,
    required this.endDate,
    required this.primaryColor,
    required this.backgroundColor,
    this.isExpired = false,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nowJkt = DateHelper.toJakartaTime(DateTime.now());
    final rawTargetJkt = DateHelper.toJakartaTime(widget.endDate);
    
    // Set target tepat di jam 00:00:00 WIB (Asia/Jakarta) pada tanggal tersebut
    final targetJkt = DateTime.utc(
      rawTargetJkt.year,
      rawTargetJkt.month,
      rawTargetJkt.day,
      0, 0, 0,
    );
    final diff = targetJkt.difference(nowJkt);

    final isExpired = diff.isNegative || diff.inSeconds <= 0 || widget.isExpired;

    final days = isExpired ? 0 : diff.inDays;
    final hours = isExpired ? 0 : diff.inHours % 24;
    final minutes = isExpired ? 0 : diff.inMinutes % 60;
    final seconds = isExpired ? 0 : diff.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTimeBox(days.toString().padLeft(2, '0'), 'HARI'),
          _buildColon(),
          _buildTimeBox(hours.toString().padLeft(2, '0'), 'JAM'),
          _buildColon(),
          _buildTimeBox(minutes.toString().padLeft(2, '0'), 'MENIT'),
          _buildColon(),
          _buildTimeBox(seconds.toString().padLeft(2, '0'), 'DETIK'),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: widget.primaryColor,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: widget.primaryColor.withValues(alpha: 0.85),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildColon() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          color: widget.primaryColor.withValues(alpha: 0.6),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
