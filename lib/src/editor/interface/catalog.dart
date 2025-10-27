import '../dataset/enum/title.dart';

class ICatalogItem {
  String id;
  String name;
  TitleLevel level;
  int pageNo;
  List<ICatalogItem> subCatalog;

  ICatalogItem({
    required this.id,
    required this.name,
    required this.level,
    required this.pageNo,
    required this.subCatalog,
  });
}

typedef ICatalog = List<ICatalogItem>;
