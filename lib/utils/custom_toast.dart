import 'package:flutter/material.dart';

enum ToastType { success, info, warning, error }

class CustomToast {
  static void show(BuildContext context, String message, {bool isError = false, ToastType? type}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    ToastType currentType = type ?? (isError ? ToastType.error : ToastType.success);
    
    // Auto-infer based on message text if not explicitly provided and not an error
    if (type == null && !isError) {
      final msgLower = message.toLowerCase();
      if (msgLower.contains('dihapus') || msgLower.contains('dibatalkan')) {
        currentType = ToastType.warning;
      } else if (msgLower.contains('diperbarui') || msgLower.contains('diedit') || msgLower.contains('diubah')) {
        currentType = ToastType.info;
      } else {
        currentType = ToastType.success;
      }
    }

    Color bgColor;
    Color iconColor;
    Color textColor;
    IconData iconData;

    switch (currentType) {
      case ToastType.warning:
        bgColor = Colors.orange.shade50;
        iconColor = Colors.orange.shade700;
        textColor = Colors.orange.shade800;
        iconData = Icons.warning_amber_rounded;
        break;
      case ToastType.info:
        bgColor = Colors.blue.shade50;
        iconColor = Colors.blue.shade600;
        textColor = Colors.blue.shade800;
        iconData = Icons.info_outline;
        break;
      case ToastType.error:
        bgColor = Colors.red.shade50;
        iconColor = Colors.red.shade600;
        textColor = Colors.red.shade800;
        iconData = Icons.error_outline;
        break;
      case ToastType.success:
        bgColor = Colors.teal.shade50;
        iconColor = Colors.teal.shade600;
        textColor = Colors.teal.shade800;
        iconData = Icons.check_circle_outline;
        break;
    }
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -60 * (1 - value)),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconData,
                    color: iconColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: textColor, 
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}
