import '../dataset/enum/common.dart';
import 'element.dart';

/// Caixa de texto flutuante do cabeçalho (carimbo, F4.8): conteúdo + geometria
/// para o frame do header desenhar a borda e o texto no canto (top-right).
/// Mutável: a caixa é editável na UI (mover/redimensionar/editar texto).
class IHeaderTextBox {
  List<IElement> elements;
  bool alignRight;

  /// Deslocamento X explícito a partir da margem esquerda (px, sem scale).
  /// `null` = posicionar pela regra [alignRight] (comportamento original).
  double? offsetXPx;
  double offsetYPx;
  double widthPx;
  double heightPx;
  String? borderColor;
  double borderWidthPx;
  String? fillColor;

  IHeaderTextBox({
    required this.elements,
    required this.alignRight,
    required this.offsetYPx,
    required this.widthPx,
    required this.heightPx,
    this.offsetXPx,
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
