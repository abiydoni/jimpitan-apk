import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jimpitan/utils/update_checker.dart';

class FormattedWhatsAppText extends StatelessWidget {
  final String text;
  final TextStyle style;

  final int? maxLines;
  final TextOverflow? overflow;

  const FormattedWhatsAppText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(
        children: _parseMessage(text, style, context),
      ),
    );
  }

  List<InlineSpan> _parseMessage(String text, TextStyle baseStyle, BuildContext context) {
    final List<InlineSpan> spans = [];

    // regex order: URL, Bold, Italic, Strikethrough, Code
    final RegExp exp = RegExp(
      r'(https?:\/\/[^\s]+|www\.[^\s]+)'
      r'|\*([^\*]+)\*'
      r'|_([^_]+)_'
      r'|~([^~]+)~'
      r'|```([^`]+)```',
    );

    int lastMatchEnd = 0;
    for (final Match match in exp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: baseStyle));
      }

      if (match.group(1) != null) {
        // URL
        final String url = match.group(1)!;
        final String launchUrlString = url.startsWith('www.') ? 'https://$url' : url;
        spans.add(
          TextSpan(
            text: url,
            style: baseStyle.copyWith(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final Uri uri = Uri.parse(launchUrlString);
                
                // Cegat URL APK agar di-download menggunakan in-app downloader
                if (launchUrlString.toLowerCase().endsWith('.apk')) {
                  await showDownloadApkDialog(context, launchUrlString);
                } else if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
          ),
        );
      } else if (match.group(2) != null) {
        // Bold
        spans.add(TextSpan(text: match.group(2), style: baseStyle.copyWith(fontWeight: FontWeight.bold)));
      } else if (match.group(3) != null) {
        // Italic
        spans.add(TextSpan(text: match.group(3), style: baseStyle.copyWith(fontStyle: FontStyle.italic)));
      } else if (match.group(4) != null) {
        // Strikethrough
        spans.add(TextSpan(text: match.group(4), style: baseStyle.copyWith(decoration: TextDecoration.lineThrough)));
      } else if (match.group(5) != null) {
        // Code
        spans.add(TextSpan(
          text: match.group(5),
          style: baseStyle.copyWith(fontFamily: 'monospace', backgroundColor: Colors.black12),
        ));
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: baseStyle));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }

    return spans;
  }
}
