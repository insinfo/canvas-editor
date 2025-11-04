import '../../../dataset/constant/common.dart';
import '../../../dataset/enum/element.dart';
import '../../../dataset/enum/title.dart';
import '../../../interface/catalog.dart';
import '../../../interface/element.dart';
import '../../../interface/table/td.dart';
import '../../../interface/table/tr.dart';

class _CatalogElement {
	_CatalogElement({
		required this.titleId,
		required this.level,
		required this.pageNo,
		required this.value,
	});

	final String titleId;
	final TitleLevel level;
	final int pageNo;
	final String value;
}

class _CatalogExtractionResult {
	_CatalogExtractionResult(this.position, this.element);

	final int position;
	final _CatalogElement element;
}

const Map<TitleLevel, int> _titleOrderNumberMapping = <TitleLevel, int>{
	TitleLevel.first: 1,
	TitleLevel.second: 2,
	TitleLevel.third: 3,
	TitleLevel.fourth: 4,
	TitleLevel.fifth: 5,
	TitleLevel.sixth: 6,
};

final Set<ElementType> _textLikeElementTypes = <ElementType>{
	ElementType.text,
	ElementType.hyperlink,
	ElementType.subscript,
	ElementType.superscript,
	ElementType.control,
	ElementType.date,
};

bool _isTextLikeElement(IElement element) {
	return element.type == null || _textLikeElementTypes.contains(element.type!);
}

int _resolvePageNo(List<IElementPosition> positionList, int index) {
	if (index >= 0 && index < positionList.length) {
		return positionList[index].pageNo;
	}
	return 0;
}

_CatalogExtractionResult _extractTitle(
	List<IElement> elementList,
	int startIndex,
	int pageNo,
) {
	final IElement startElement = elementList[startIndex];
	final String titleId = startElement.titleId!;
	final TitleLevel level = startElement.level!;
	final List<IElement> valueList = <IElement>[];
	int position = startIndex;
	while (position < elementList.length) {
		final IElement titleElement = elementList[position];
		if (titleElement.titleId != titleId) {
			position -= 1;
			break;
		}
		valueList.add(titleElement);
		position += 1;
	}
	final String value = valueList
		.where(_isTextLikeElement)
		.map((IElement el) => el.value)
		.join()
		.replaceAll(RegExp(ZERO), '');
	return _CatalogExtractionResult(
		position,
		_CatalogElement(
			titleId: titleId,
			level: level,
			pageNo: pageNo,
			value: value,
		),
	);
}

ICatalogItem _toCatalogItem(_CatalogElement title) {
	return ICatalogItem(
		id: title.titleId,
		name: title.value,
		level: title.level,
		pageNo: title.pageNo,
		subCatalog: <ICatalogItem>[],
	);
}

void _recursiveInsert(_CatalogElement title, ICatalogItem catalogItem) {
	if (catalogItem.subCatalog.isEmpty) {
		catalogItem.subCatalog.add(_toCatalogItem(title));
		return;
	}
	final ICatalogItem last = catalogItem.subCatalog.last;
	final int? catalogItemLevel = _titleOrderNumberMapping[last.level];
	final int titleLevel = _titleOrderNumberMapping[title.level]!;
	if (catalogItemLevel != null && titleLevel > catalogItemLevel) {
		_recursiveInsert(title, last);
		return;
	}
	catalogItem.subCatalog.add(_toCatalogItem(title));
}

/// Builds the catalog tree from the provided element and position lists.
ICatalog? computeCatalog(
	List<IElement> elementList,
	List<IElementPosition> positionList,
) {
	final List<_CatalogElement> titleElementList = <_CatalogElement>[];
	int index = 0;
	while (index < elementList.length) {
		final IElement element = elementList[index];
		if (element.titleId != null && element.level != null) {
			final _CatalogExtractionResult result = _extractTitle(
				elementList,
				index,
				_resolvePageNo(positionList, index),
			);
			index = result.position;
			titleElementList.add(result.element);
		}
		if (element.type == ElementType.table && element.trList != null) {
			final int pageNo = _resolvePageNo(positionList, index);
			for (final ITr tr in element.trList!) {
				for (final ITd td in tr.tdList) {
					final List<IElement> cellValue = td.value;
					if (cellValue.length <= 1) {
						continue;
					}
					int cellIndex = 1;
					while (cellIndex < cellValue.length) {
						final IElement cellElement = cellValue[cellIndex];
						if (cellElement.titleId != null && cellElement.level != null) {
							final _CatalogExtractionResult cellResult = _extractTitle(
								cellValue,
								cellIndex,
								pageNo,
							);
							titleElementList.add(cellResult.element);
							cellIndex = cellResult.position;
						}
						cellIndex += 1;
					}
				}
			}
		}
		index += 1;
	}
	if (titleElementList.isEmpty) {
		return null;
	}
	final ICatalog catalog = <ICatalogItem>[];
	for (final _CatalogElement title in titleElementList) {
		if (catalog.isEmpty) {
			catalog.add(_toCatalogItem(title));
			continue;
		}
		final ICatalogItem last = catalog.last;
		final int? lastLevel = _titleOrderNumberMapping[last.level];
		final int titleLevel = _titleOrderNumberMapping[title.level]!;
		if (lastLevel != null && titleLevel > lastLevel) {
			_recursiveInsert(title, last);
		} else {
			catalog.add(_toCatalogItem(title));
		}
	}
	return catalog;
}