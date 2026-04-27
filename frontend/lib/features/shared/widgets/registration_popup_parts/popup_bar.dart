part of '../registration_popup.dart';

class PopupBar extends StatelessWidget {
  const PopupBar({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              SizedBox(
                width: 22,
                child: Image(
                  image: AssetImage('assets/images/ui/bar/left-bar.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/ui/bar/middle-bar.png'),
                      repeat: ImageRepeat.repeatX,
                      fit: BoxFit.fitHeight,
                      alignment: Alignment.centerLeft,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 22,
                child: Image(
                  image: AssetImage('assets/images/ui/bar/right-bar.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ],
          ),
          if (title != null)
            Center(
              child: Text(
                title!,
                style: const TextStyle(
                  color: Color(0xFFE3D8C3),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: Color(0xAA000000),
                      offset: Offset(0, 1),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
