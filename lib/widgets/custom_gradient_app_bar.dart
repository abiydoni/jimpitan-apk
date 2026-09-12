import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jimpitan/utils/app_theme.dart';

/// Reusable Gradient AppBar dengan dekorasi lingkaran dan lengkungan bawah
/// yang seragam di seluruh halaman, serta indikator status bar/sinyal putih.
class CustomGradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final String? titleText;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final bool centerTitle;
  final double elevation;
  final double borderRadius;
  final double? toolbarHeight;

  const CustomGradientAppBar({
    super.key,
    this.title,
    this.titleText,
    this.leading,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.centerTitle = false,
    this.elevation = 0,
    this.borderRadius = 24.0,
    this.toolbarHeight,
  });

  @override
  Size get preferredSize {
    final double bottomHeight = bottom?.preferredSize.height ?? 0.0;
    final double tbHeight = toolbarHeight ?? kToolbarHeight;
    return Size.fromHeight(tbHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColorNotifier,
      builder: (context, primaryColor, _) {
        final secondaryColor = AppTheme.secondaryColor;

        return AppBar(
          toolbarHeight: toolbarHeight,
          elevation: elevation,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light, // Indikator Android Putih
            statusBarBrightness: Brightness.dark,      // Indikator iOS Putih
          ),
          automaticallyImplyLeading: automaticallyImplyLeading,
          centerTitle: centerTitle,
          leading: leading ??
              (automaticallyImplyLeading && Navigator.canPop(context)
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: InkWell(
                        onTap: () => Navigator.maybePop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    )
                  : null),
          title: title ??
              (titleText != null
                  ? Text(
                      titleText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    )
                  : null),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          actions: actions != null
              ? [
                  ...actions!,
                  const SizedBox(width: 8),
                ]
              : null,
          bottom: bottom,
          flexibleSpace: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(borderRadius),
              bottomRight: Radius.circular(borderRadius),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor,
                    secondaryColor,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Dekorasi Lingkaran Kanan Atas
                  Positioned(
                    right: -30,
                    top: -20,
                    child: IgnorePointer(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ),
                  // Dekorasi Lingkaran Kiri Bawah
                  Positioned(
                    left: -15,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
