class IBadge {
  double? top;
  double? left;
  double width;
  double height;
  String value;

  IBadge({
    this.top,
    this.left,
    required this.width,
    required this.height,
    required this.value,
  });
}

class IBadgeOption {
  double? top;
  double? left;

  IBadgeOption({this.top, this.left});
}

class IAreaBadge {
  String areaId;
  IBadge badge;

  IAreaBadge({required this.areaId, required this.badge});
}
