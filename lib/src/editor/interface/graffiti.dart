class IGraffitiStroke {
  String? lineColor;
  num? lineWidth;
  List<double> points;

  IGraffitiStroke({
    this.lineColor,
    this.lineWidth,
    required this.points,
  });
}

class IGraffitiData {
  int pageNo;
  List<IGraffitiStroke> strokes;

  IGraffitiData({
    required this.pageNo,
    required this.strokes,
  });
}

class IGraffitiOption {
  String? defaultLineColor;
  num? defaultLineWidth;

  IGraffitiOption({
    this.defaultLineColor,
    this.defaultLineWidth,
  });
}