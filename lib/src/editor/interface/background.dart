import '../dataset/enum/background.dart';

class IBackgroundOption {
  String? color;
  String? image;
  BackgroundSize? size;
  BackgroundRepeat? repeat;
  List<int>? applyPageNumbers;

  IBackgroundOption({
    this.color,
    this.image,
    this.size,
    this.repeat,
    this.applyPageNumbers,
  });
}
