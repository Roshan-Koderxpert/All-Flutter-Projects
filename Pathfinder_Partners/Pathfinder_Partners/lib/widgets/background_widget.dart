import 'package:flutter/material.dart';
import 'package:retail_gpt/utils/app_colors.dart';

class BackgroundWidget extends StatefulWidget {
  final Widget bottomSheetWidget;
  final Widget headerWidget;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;
  final bool isLogin; // Mark it as final
  const BackgroundWidget({
    super.key,
    required this.headerWidget,
    required this.bottomSheetWidget,
    this.isLogin = false,
    this.floatingActionButton,
    this.appBar,
  });

  @override
  State<BackgroundWidget> createState() => _BackgroundWidgetState();
}

class _BackgroundWidgetState extends State<BackgroundWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.appBar ?? AppBar(
                title: Text('App Bar'),
                backgroundColor: AppColors.primaryColor,
                automaticallyImplyLeading: false,
                elevation: 0,
                excludeHeaderSemantics: true,
                toolbarHeight: 0,
              ),
      backgroundColor: AppColors.primaryColor,
      body: LayoutBuilder(
        // Use LayoutBuilder for responsiveness
        builder: (context, constraints) {
          double topSectionHeight = constraints.maxHeight * 0.09;
          double bottomSectionHeight = constraints.maxHeight - topSectionHeight;
          return GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: SingleChildScrollView(
              physics: NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  /// **Top Section**
                  Container(
                    width: double.infinity,
                    height: topSectionHeight,
                    color: AppColors.primaryColor,
                    child: widget.headerWidget,
                  ),

                  /// **Bottom Section**
                  Container(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    width: double.infinity,
                    height: bottomSectionHeight,
                    // height: constraints.maxHeight,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: widget.bottomSheetWidget,
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
