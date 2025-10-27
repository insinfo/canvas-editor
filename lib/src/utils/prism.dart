import 'dart:js_util' as js_util;

class PrismKindStyle {
	final String? color;
	final bool? italic;
	final double? opacity;
	final bool? bold;

	const PrismKindStyle({this.color, this.italic, this.opacity, this.bold});

	Map<String, dynamic> toJson() => <String, dynamic>{
				if (color != null) 'color': color,
				if (italic != null) 'italic': italic,
				if (opacity != null) 'opacity': opacity,
				if (bold != null) 'bold': bold,
			};

	bool get hasStyle =>
			color != null || italic != null || opacity != null || bold != null;
}

PrismKindStyle? getPrismKindStyle(String? payload) {
	switch (payload) {
		case 'comment':
		case 'prolog':
		case 'doctype':
		case 'cdata':
			return const PrismKindStyle(color: '#008000', italic: true);
		case 'namespace':
			return const PrismKindStyle(opacity: 0.7);
		case 'string':
			return const PrismKindStyle(color: '#A31515');
		case 'punctuation':
		case 'operator':
			return const PrismKindStyle(color: '#393A34');
		case 'url':
		case 'symbol':
		case 'number':
		case 'boolean':
		case 'variable':
		case 'constant':
		case 'inserted':
			return const PrismKindStyle(color: '#36acaa');
		case 'atrule':
		case 'keyword':
		case 'attr-value':
			return const PrismKindStyle(color: '#0000ff');
		case 'function':
			return const PrismKindStyle(color: '#b9a40a');
		case 'deleted':
		case 'tag':
			return const PrismKindStyle(color: '#9a050f');
		case 'selector':
			return const PrismKindStyle(color: '#00009f');
		case 'important':
			return const PrismKindStyle(color: '#e90', bold: true);
		case 'italic':
			return const PrismKindStyle(italic: true);
		case 'class-name':
		case 'property':
			return const PrismKindStyle(color: '#2B91AF');
		case 'attr-name':
		case 'regex':
		case 'entity':
			return const PrismKindStyle(color: '#ff0000');
		default:
			return null;
	}
}

class FormatPrismToken {
	final String content;
	final String? type;
	final String? color;
	final bool? italic;
	final double? opacity;
	final bool? bold;

	const FormatPrismToken({
		required this.content,
		this.type,
		this.color,
		this.italic,
		this.opacity,
		this.bold,
	});

	Map<String, dynamic> toJson() => <String, dynamic>{
				if (type != null) 'type': type,
				'content': content,
				if (color != null) 'color': color,
				if (italic != null) 'italic': italic,
				if (opacity != null) 'opacity': opacity,
				if (bold != null) 'bold': bold,
			};
}

List<FormatPrismToken> formatPrismToken(List<dynamic> payload) {
	final formatTokenList = <FormatPrismToken>[];

	void format(List<dynamic> tokenList) {
		for (final element in tokenList) {
			final normalized = js_util.dartify(element);

			if (normalized is FormatPrismToken) {
				formatTokenList.add(normalized);
			} else if (normalized is String) {
				formatTokenList.add(FormatPrismToken(content: normalized));
			} else if (normalized is List) {
				format(List<dynamic>.from(normalized));
			} else if (normalized is Iterable) {
				format(List<dynamic>.from(normalized));
			} else if (normalized is Map) {
				final typeValue = normalized['type'];
				final contentValue = normalized['content'];
				final type = typeValue is String ? typeValue : null;

				if (contentValue is String) {
					final style = getPrismKindStyle(type);
					formatTokenList.add(
						FormatPrismToken(
							type: type,
							content: contentValue,
							color: style?.color,
							italic: style?.italic,
							opacity: style?.opacity,
							bold: style?.bold,
						),
					);
				} else if (contentValue is List) {
					format(List<dynamic>.from(contentValue));
				} else if (contentValue is Iterable) {
					format(List<dynamic>.from(contentValue));
				}
			} else if (normalized != null &&
					js_util.hasProperty(normalized, 'content')) {
				final dynamic typeValue = js_util.hasProperty(normalized, 'type')
						? js_util.getProperty(normalized, 'type')
						: null;
				final dynamic contentValue =
						js_util.getProperty(normalized, 'content');
				final type = typeValue is String ? typeValue : null;
				final dartifiedContent = js_util.dartify(contentValue);

				if (dartifiedContent is String) {
					final style = getPrismKindStyle(type);
					formatTokenList.add(
						FormatPrismToken(
							type: type,
							content: dartifiedContent,
							color: style?.color,
							italic: style?.italic,
							opacity: style?.opacity,
							bold: style?.bold,
						),
					);
				} else if (dartifiedContent is List) {
					format(List<dynamic>.from(dartifiedContent));
				} else if (dartifiedContent is Iterable) {
					format(List<dynamic>.from(dartifiedContent));
				}
			}
		}
	}

	format(payload);
	return formatTokenList;
}