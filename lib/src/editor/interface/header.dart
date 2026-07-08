import '../dataset/enum/common.dart';
import 'element.dart';

/// Caixa de texto flutuante do cabeçalho (carimbo, F4.8): conteúdo + geometria
/// para o frame do header desenhar a borda e o texto no canto (top-right).
class IHeaderTextBox {
  final List<IElement> elements;
  final bool alignRight;
  final double offsetYPx;
  final double widthPx;
  final double heightPx;
  final String? borderColor;
  final double borderWidthPx;
  final String? fillColor;

  IHeaderTextBox({
    required this.elements,
    required this.alignRight,
    required this.offsetYPx,
    required this.widthPx,
    required this.heightPx,
    this.borderColor,
    this.borderWidthPx = 1,
    this.fillColor,
  });
}

class IHeader {
  double? top;
  double? inactiveAlpha;
  MaxHeightRatio? maxHeightRadio;
  bool? disabled;
  bool? editable;

  IHeader({
    this.top,
    this.inactiveAlpha,
    this.maxHeightRadio,
    this.disabled,
    this.editable,
  });
}
