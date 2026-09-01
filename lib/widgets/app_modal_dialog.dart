import 'package:flutter/material.dart';
import 'package:jimpitan/utils/app_theme.dart';

class AppModalDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final IconData? headerIcon;
  final List<Widget>? headerActions;
  final bool scrollable;
  final EdgeInsetsGeometry? contentPadding;

  const AppModalDialog({
    super.key,
    required this.title,
    required this.content,
    this.headerIcon,
    this.headerActions,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    Widget body = content;
    
    if (scrollable) {
      body = SingleChildScrollView(
        child: Padding(
          padding: contentPadding ?? EdgeInsets.zero,
          child: body,
        ),
      );
    } else if (contentPadding != null) {
      body = Padding(
        padding: contentPadding!,
        child: body,
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  if (headerIcon != null) ...[
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(headerIcon, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  ...?headerActions,
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ],
              ),
            ),
            
            // CONTENT
            Flexible(child: body),
          ],
        ),
      ),
    );
  }
}
