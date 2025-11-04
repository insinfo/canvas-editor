import 'dart:html';

import '../../../../dataset/constant/editor.dart';
import '../../../../dataset/enum/element.dart';
import '../../../../interface/element.dart';
import '../../../../interface/row.dart';
import '../../draw.dart';
import 'modules/base_block.dart';

class BlockParticle {
	BlockParticle(Draw draw)
			: _draw = draw,
				_container = draw.getContainer(),
				_blockMap = <String, BaseBlock>{},
				_blockContainer = DivElement()
					..classes.add('$editorPrefix-block-container') {
		_container.append(_blockContainer);
	}

	final Draw _draw;
	final DivElement _container;
	final DivElement _blockContainer;
	final Map<String, BaseBlock> _blockMap;

	Draw getDraw() => _draw;

	DivElement getBlockContainer() => _blockContainer;

	void render(
		CanvasRenderingContext2D ctx,
		int pageNo,
		IRowElement element,
		double x,
		double y,
	) {
		final String? id = element.id;
		if (id == null || id.isEmpty) {
			return;
		}
		BaseBlock? cacheBlock = _blockMap[id];
		if (cacheBlock == null) {
			cacheBlock = BaseBlock(
				draw: _draw,
				blockContainer: _blockContainer,
				element: element,
			);
			cacheBlock.render();
			_blockMap[id] = cacheBlock;
		}
		cacheBlock.updateElement(element);
		if (_draw.isPrintMode()) {
			cacheBlock.snapshot(ctx, x, y);
		} else {
			cacheBlock.setClientRects(pageNo, x, y);
		}
	}

	void clear() {
		if (_blockMap.isEmpty) {
			return;
		}
		final List<IElement> elementList = _draw.getOriginalMainElementList();
		final Set<String> liveBlockIds = <String>{};
		for (final IElement element in elementList) {
			if (element.type == ElementType.block && element.id != null) {
				liveBlockIds.add(element.id!);
			}
		}
		if (liveBlockIds.length == _blockMap.length) {
			return;
		}
		final List<String> removeIds = <String>[];
		_blockMap.forEach((String key, BaseBlock block) {
			if (!liveBlockIds.contains(key)) {
				block.remove();
				removeIds.add(key);
			}
		});
		for (final String id in removeIds) {
			_blockMap.remove(id);
		}
	}
}