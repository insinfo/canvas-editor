import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:math';

import 'dart:js_util' as js_util;

import '../dataset/constant/regular.dart';
import '../interface/element.dart';

const Object _sentinel = Object();

List<dynamic> _collectArgs(List<dynamic> raw) {
	final result = <dynamic>[];
	for (final entry in raw) {
		if (!identical(entry, _sentinel)) {
			result.add(entry);
		}
	}
	return result;
}

class _DebounceWrapper {
	_DebounceWrapper(this._func, this._delay);

	final Function _func;
	final Duration _delay;
	Timer? _timer;

	dynamic call([
		dynamic arg0 = _sentinel,
		dynamic arg1 = _sentinel,
		dynamic arg2 = _sentinel,
		dynamic arg3 = _sentinel,
		dynamic arg4 = _sentinel,
		dynamic arg5 = _sentinel,
	]) {
		final args = _collectArgs(<dynamic>[arg0, arg1, arg2, arg3, arg4, arg5]);
		_timer?.cancel();
		if (_delay == Duration.zero) {
			return Function.apply(_func, args);
		}
		_timer = Timer(_delay, () => Function.apply(_func, args));
		return null;
	}
}

class _ThrottleWrapper {
	_ThrottleWrapper(this._func, this._delay);

	final Function _func;
	final Duration _delay;
	Timer? _timer;
	int? _lastExecTimestamp;

	dynamic call([
		dynamic arg0 = _sentinel,
		dynamic arg1 = _sentinel,
		dynamic arg2 = _sentinel,
		dynamic arg3 = _sentinel,
		dynamic arg4 = _sentinel,
		dynamic arg5 = _sentinel,
	]) {
		final args = _collectArgs(<dynamic>[arg0, arg1, arg2, arg3, arg4, arg5]);
		final now = DateTime.now().millisecondsSinceEpoch;

		if (_lastExecTimestamp == null ||
				now - _lastExecTimestamp! >= _delay.inMilliseconds) {
			_timer?.cancel();
			_lastExecTimestamp = now;
			return Function.apply(_func, args);
		} else {
			_timer?.cancel();
			final scheduledTimestamp = now;
			final scheduledArgs = List<dynamic>.from(args);
			_timer = Timer(_delay, () {
				_lastExecTimestamp = scheduledTimestamp;
				Function.apply(_func, scheduledArgs);
			});
			return null;
		}
	}
}

Function debounce(Function func, Duration delay) => _DebounceWrapper(func, delay).call;

Function throttle(Function func, Duration delay) => _ThrottleWrapper(func, delay).call;

dynamic deepCloneOmitKeys(dynamic obj, List<String> omitKeys) {
	if (obj == null || obj is num || obj is bool || obj is String) {
		return obj;
	}
	if (obj is List) {
		return obj.map((item) => deepCloneOmitKeys(item, omitKeys)).toList();
	}
	if (obj is Map) {
		final newObj = <dynamic, dynamic>{};
		obj.forEach((key, value) {
			if (omitKeys.contains(key)) {
				return;
			}
			newObj[key] = deepCloneOmitKeys(value, omitKeys);
		});
		return newObj;
	}
	return obj;
}

dynamic deepClone(dynamic obj) {
	if (obj == null || obj is num || obj is bool || obj is String) {
		return obj;
	}
	if (obj is List) {
		return obj.map(deepClone).toList();
	}
	if (obj is Map) {
		final newObj = <dynamic, dynamic>{};
		obj.forEach((key, value) {
			newObj[key] = deepClone(value);
		});
		return newObj;
	}
	return obj;
}

bool isBody(Element? node) {
	return node != null && node.tagName.toLowerCase() == 'body';
}

Element? findParent(
	Element node,
	bool Function(Element element)? filterFn,
	bool includeSelf,
) {
	Element? current = includeSelf ? node : node.parent;
	while (current != null) {
		if (filterFn == null || filterFn(current) || isBody(current)) {
			if (filterFn != null && !filterFn(current) && isBody(current)) {
				return null;
			}
			return current;
		}
		current = current.parent;
	}
	return null;
}

String getUUID() {
	String s4() {
		final random = Random();
		return ((1 + random.nextDouble()) * 0x10000).floor().toRadixString(16).substring(1);
	}

	return '${s4()}${s4()}-${s4()}-${s4()}-${s4()}-${s4()}${s4()}${s4()}';
}

List<String> splitText(String text) {
	final data = <String>[];
	final intl = js_util.hasProperty(js_util.globalThis, 'Intl')
			? js_util.getProperty(js_util.globalThis, 'Intl')
			: null;
		if (intl != null && js_util.hasProperty(intl, 'Segmenter')) {
		final segmenterConstructor = js_util.getProperty(intl, 'Segmenter');
		final segmenter = js_util.callConstructor(segmenterConstructor, const []);
		final segments = js_util.callMethod(segmenter, 'segment', [text]);
			final dartifiedSegments = js_util.dartify(segments);
			if (dartifiedSegments is Iterable) {
				for (final entry in dartifiedSegments) {
					if (entry is Map && entry['segment'] is String) {
						data.add(entry['segment'] as String);
					}
				}
				return data;
			}

			if (js_util.hasProperty(segments, 'values')) {
				final iterator = js_util.callMethod(segments, 'values', const []);
				while (true) {
					final result = js_util.callMethod(iterator, 'next', const []);
					if (result == null || js_util.getProperty(result, 'done') == true) {
						break;
					}
					final segment = js_util.getProperty(result, 'value');
					final value = js_util.getProperty(segment, 'segment');
					if (value is String) {
						data.add(value);
					}
				}
				return data;
			}
	}

		final symbolMap = <int, String>{};
		for (final match in unicodeSymbolReg.allMatches(text)) {
		symbolMap[match.start] = match.group(0)!;
	}
	var index = 0;
	while (index < text.length) {
		final symbol = symbolMap[index];
		if (symbol != null) {
			data.add(symbol);
			index += symbol.length;
		} else {
			data.add(text[index]);
			index++;
		}
	}
	return data;
}

void downloadFile(String href, String fileName) {
	final anchor = AnchorElement()
		..href = href
		..download = fileName;
	anchor.click();
}

void threeClick(Element dom, void Function(MouseEvent evt) fn) {
	_nClickEvent(3, dom, fn);
}

void _nClickEvent(int n, Element dom, void Function(MouseEvent evt) fn) {
	var count = 0;
	var lastTime = 0;

	dom.onClick.listen((event) {
		final currentTime = DateTime.now().millisecondsSinceEpoch;
		count = currentTime - lastTime < 300 ? count + 1 : 0;
		lastTime = currentTime;
		if (count >= n - 1) {
			fn(event);
			count = 0;
		}
	});
}

bool isObject(dynamic value) => value is Map;

bool isArray(dynamic value) => value is List;

bool isNumber(dynamic value) => value is num;

bool isString(dynamic value) => value is String;

dynamic mergeObject(dynamic source, dynamic target) {
	if (source is Map && target is Map) {
		source.forEach((key, value) {
			if (!target.containsKey(key)) {
				target[key] = value;
			} else {
				target[key] = mergeObject(value, target[key]);
			}
		});
	} else if (source is List && target is List) {
		target.addAll(source);
	}
	return target;
}

void nextTick(Function fn) {
	Timer(Duration.zero, () => fn());
}

String convertNumberToChinese(num number) {
	const chineseNum = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
	const chineseUnit = [
		'',
		'十',
		'百',
		'千',
		'万',
		'十',
		'百',
		'千',
		'亿',
		'十',
		'百',
		'千',
		'万',
		'十',
		'百',
		'千',
		'亿',
	];

	if (number == 0 || number.isNaN) {
		return '零';
	}

	final numStr = number.toString().split('');
	var result = '';
	for (var i = 0; i < numStr.length; i++) {
		final desIndex = numStr.length - 1 - i;
		result = '${chineseUnit[i]}$result';
		result = '${chineseNum[int.parse(numStr[desIndex])]}$result';
	}
	result = result.replaceAll(RegExp(r'零(千|百|十)'), '零');
	result = result.replaceAll('十零', '十');
	result = result.replaceAll(RegExp(r'零+'), '零');
	result = result.replaceAll('零亿', '亿').replaceAll('零万', '万');
	result = result.replaceAll('亿万', '亿');
	result = result.replaceAll(RegExp(r'零+$'), '');
	result = result.replaceAll(RegExp(r'^一十'), '十');
	return result;
}

void cloneProperty(
	List<String> properties,
	Map<String, dynamic> sourceElement,
	Map<String, dynamic> targetElement,
) {
	for (final property in properties) {
		if (sourceElement.containsKey(property)) {
			targetElement[property] = sourceElement[property];
		} else {
			targetElement.remove(property);
		}
	}
}

Map<String, dynamic> pickObject(
	Map<String, dynamic> object,
	List<String> pickKeys,
) {
	final newObject = <String, dynamic>{};
	object.forEach((key, value) {
		if (pickKeys.contains(key)) {
			newObject[key] = value;
		}
	});
	return newObject;
}

Map<String, dynamic> omitObject(
	Map<String, dynamic> object,
	List<String> omitKeys,
) {
	final newObject = <String, dynamic>{};
	object.forEach((key, value) {
		if (!omitKeys.contains(key)) {
			newObject[key] = value;
		}
	});
	return newObject;
}

String convertStringToBase64(String input) {
	final data = utf8.encode(input);
	return base64Encode(data);
}

Element findScrollContainer(Element element) {
	Element? parent = element.parent;
	while (parent != null) {
		final style = parent.getComputedStyle();
		final overflowY = style.getPropertyValue('overflow-y');
		if (parent.scrollHeight > parent.clientHeight &&
				(overflowY == 'auto' || overflowY == 'scroll')) {
			return parent;
		}
		parent = parent.parent;
	}
	return document.documentElement ?? document.body ?? element; // fallbacks
}

bool isArrayEqual(dynamic arr1, dynamic arr2) {
	if (arr1 is! List || arr2 is! List) {
		return false;
	}
	if (arr1.length != arr2.length) {
		return false;
	}
	for (final item in arr1) {
		if (!arr2.contains(item)) {
			return false;
		}
	}
	return true;
}

bool isObjectEqual(dynamic obj1, dynamic obj2) {
	if (obj1 is! Map || obj2 is! Map) {
		return false;
	}
	if (obj1.length != obj2.length) {
		return false;
	}
	for (final entry in obj1.entries) {
		if (obj2[entry.key] != entry.value) {
			return false;
		}
	}
	return true;
}

bool isRectIntersect(IElementFillRect rect1, IElementFillRect rect2) {
	final rect1Left = rect1.x;
	final rect1Right = rect1.x + rect1.width;
	final rect1Top = rect1.y;
	final rect1Bottom = rect1.y + rect1.height;
	final rect2Left = rect2.x;
	final rect2Right = rect2.x + rect2.width;
	final rect2Top = rect2.y;
	final rect2Bottom = rect2.y + rect2.height;

	if (rect1Left > rect2Right ||
			rect1Right < rect2Left ||
			rect1Top > rect2Bottom ||
			rect1Bottom < rect2Top) {
		return false;
	}
	return true;
}

bool isNonValue(dynamic value) => value == null;

String normalizeLineBreak(String text) {
	return text.replaceAll(RegExp(r'\r\n|\r'), '\n');
}
// TODO: Translate from C:\\MyTsProjects\\canvas-editor\\src\\editor\\utils\\index.ts