part of '../animation_debug_panel.dart';

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                width: 40,
                child: Image(
                  image: AssetImage('assets/images/ui/bar/left-bar.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
              const Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/ui/bar/middle-bar.png'),
                      repeat: ImageRepeat.repeat,
                      fit: BoxFit.fill,
                      alignment: Alignment.centerLeft,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 40,
                child: Image(
                  image: AssetImage('assets/images/ui/bar/right-bar.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ],
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
