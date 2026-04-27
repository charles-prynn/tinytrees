part of '../registration_popup.dart';

class PopupPanel extends StatelessWidget {
  const PopupPanel({
    super.key,
    required this.title,
    required this.child,
    this.overlayColor = const Color(0x99000000),
    this.maxWidth = 420,
    this.maxHeightFactor = 0.9,
    this.horizontalPadding = 16,
    this.verticalPadding = 16,
  });

  final String title;
  final Widget child;
  final Color overlayColor;
  final double maxWidth;
  final double maxHeightFactor;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Material(
      color: overlayColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight * maxHeightFactor;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                verticalPadding,
                horizontalPadding,
                verticalPadding + viewInsets.bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2419),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xAA7C6B48),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x99000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupBar(title: title),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: child,
                          ),
                          const PopupBar(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
