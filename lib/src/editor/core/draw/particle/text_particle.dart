import 'dart:html';
import 'dart:js_util' as js_util;

import '../../../dataset/constant/common.dart';
import '../../../dataset/enum/editor.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/row.dart';
import '../draw.dart';

class IMeasureWordResult {
	IMeasureWordResult({required this.width, this.endElement});

	double width;
	IElement? endElement;
}

class TextParticle {
	TextParticle(this.draw)
			: options = draw.getOptions(),
			cacheMeasureText = <String, ITextMetrics>{},
			ctx = draw.getCtx(),
			curX = -1,
			curY = -1,
			text = '',
			curStyle = '',
			curColor = null;

	final Draw draw;
	final IEditorOption options;
	CanvasRenderingContext2D? ctx;
	double curX;
	double curY;
	String text;
	String curStyle;
	String? curColor;
	// Soma das larguras (do LAYOUT/TTF) dos elementos no batch atual. O
	// `fillText` avança pela métrica do Arial do canvas do browser, que difere
	// da nossa métrica TTF; sem corrigir, o batch "deriva" e o próximo batch
	// (posicionado pelo layout) sobrepõe o anterior (ex.: "determinado(locação)"
	// nos cabeçalhos centralizados). No render escalamos o batch p/ casar esta
	// largura, mantendo 1 fillText por batch.
	double _layoutWidth = 0;
	final Map<String, ITextMetrics> cacheMeasureText;

	// Estado do ctx de medição (plano de otimização A2): setar/ler `ctx.font`
	// é uma chamada de interop DOM; com dezenas de milhares de elementos por
	// render isso domina o custo do layout. Rastreamos o último font aplicado
	// e só tocamos o DOM quando ele muda de fato (e nunca em cache hit).
	CanvasRenderingContext2D? _measureCtx;
	String _measureFont = '';

	// Inclui acentos latinos (0xC0-0x24F) — sem eles, palavras em português
	// eram quebradas no meio ("Implanta|ção"). Ver Draw._defaultLetterReg.
	static final RegExp _fallbackLetterReg = RegExp('[A-Za-zÀ-ɏ]');

	void _applyMeasureFont(CanvasRenderingContext2D ctx, String font) {
		if (font.isEmpty) {
			return;
		}
		if (!identical(ctx, _measureCtx) || font != _measureFont) {
			ctx.font = font;
			_measureCtx = ctx;
			_measureFont = font;
		}
	}

	ITextMetrics measureBasisWord(CanvasRenderingContext2D ctx, String font) {
		ctx.save();
		ctx.font = font;
		final ITextMetrics metrics = measureText(
			ctx,
			IElement(value: METRICS_BASIS_TEXT),
		);
		ctx.restore();
		// O restore reverte o font do ctx por fora do rastreador.
		_measureCtx = null;
		return metrics;
	}

	IMeasureWordResult measureWord(
		CanvasRenderingContext2D ctx,
		List<IElement> elementList,
		int curIndex, [
		String? font,
	]) {
		final RegExp effectiveLetterReg =
				draw.getLetterReg() ?? _fallbackLetterReg;
		double width = 0;
		IElement? endElement;
		int index = curIndex;
		while (index < elementList.length) {
			final IElement element = elementList[index];
			final ElementType? type = element.type;
			if (type != null && type != ElementType.text) {
				endElement = element;
				break;
			}
			if (!effectiveLetterReg.hasMatch(element.value)) {
				endElement = element;
				break;
			}
			width += (font != null
							? measureTextWithFont(ctx, element, font)
							: measureText(ctx, element))
					.width;
			index += 1;
		}
		return IMeasureWordResult(width: width, endElement: endElement);
	}

	double measurePunctuationWidth(
		CanvasRenderingContext2D ctx,
		IElement? element,
	) {
		if (element == null || !PUNCTUATION_LIST.contains(element.value)) {
			return 0;
		}
		final String font = draw.getElementFont(element);
		return measureTextWithFont(ctx, element, font).width;
	}

	ITextMetrics measureText(CanvasRenderingContext2D ctx, IElement element) {
		if (element.width != null) {
			final TextMetrics metrics = ctx.measureText(element.value);
			return _createMetrics(metrics, widthOverride: element.width?.toDouble());
		}
		final String cacheKey = '${element.value}${ctx.font}';
		final ITextMetrics? cached = cacheMeasureText[cacheKey];
		if (cached != null) {
			return cached;
		}
		final TextMetrics metrics = ctx.measureText(element.value);
		final ITextMetrics wrapped = _createMetrics(metrics);
		cacheMeasureText[cacheKey] = wrapped;
		return wrapped;
	}

	/// Variante quente de [measureText]: recebe a fonte já resolvida, monta a
	/// cache key sem ler `ctx.font` do DOM e só aplica a fonte no ctx em cache
	/// miss (quando `measureText` nativo realmente vai rodar).
	ITextMetrics measureTextWithFont(
		CanvasRenderingContext2D ctx,
		IElement element,
		String font,
	) {
		if (element.width != null) {
			_applyMeasureFont(ctx, font);
			final TextMetrics metrics = ctx.measureText(element.value);
			return _createMetrics(metrics, widthOverride: element.width?.toDouble());
		}
		final String cacheKey = '${element.value}$font';
		final ITextMetrics? cached = cacheMeasureText[cacheKey];
		if (cached != null) {
			return cached;
		}
		_applyMeasureFont(ctx, font);
		final TextMetrics metrics = ctx.measureText(element.value);
		final ITextMetrics wrapped = _createMetrics(metrics);
		cacheMeasureText[cacheKey] = wrapped;
		return wrapped;
	}

	void complete() {
		_render();
		text = '';
	}

	void record(
		CanvasRenderingContext2D ctx,
		IRowElement element,
		double x,
		double y,
	) {
		this.ctx = ctx;
		if (options.renderMode == RenderMode.compatibility) {
			_setCurXY(x, y);
			text = element.value;
			curStyle = element.style;
			curColor = element.color;
			complete();
			return;
		}
		if (text.isEmpty) {
			_setCurXY(x, y);
			_layoutWidth = 0;
		}
		if ((curStyle.isNotEmpty && element.style != curStyle) ||
					element.color != curColor) {
			complete();
			_setCurXY(x, y);
			_layoutWidth = 0;
		}
		text += element.value;
		_layoutWidth += element.metrics.width;
		curStyle = element.style;
		curColor = element.color;
	}

	void _setCurXY(double x, double y) {
		curX = x;
		curY = y;
	}

	void _render() {
		final CanvasRenderingContext2D? context = ctx ?? draw.getCtx();
		if (context == null) {
			return;
		}
		if (text.isEmpty || curX < 0 || curY < 0) {
			return;
		}
		context.save();
		context.font = curStyle;
		context.fillStyle = curColor ?? _defaultColor;
		// Casa a largura renderizada (métrica do canvas) com a largura do layout
		// (TTF), escalando o batch horizontalmente. Sem isso o texto deriva e
		// batches consecutivos (quebrados na pontuação) se sobrepõem.
		final double canvasWidth = _measuredWidth(context, text);
		if (_layoutWidth > 0 &&
				canvasWidth > 0 &&
				(canvasWidth - _layoutWidth).abs() > 0.25) {
			final double scaleX = _layoutWidth / canvasWidth;
			context
				..translate(curX, curY)
				..scale(scaleX, 1)
				..fillText(text, 0, 0);
		} else {
			context.fillText(text, curX, curY);
		}
		context.restore();
	}

	double _measuredWidth(CanvasRenderingContext2D context, String value) {
		try {
			final TextMetrics m = context.measureText(value);
			final dynamic w = js_util.getProperty(m, 'width');
			return w is num ? w.toDouble() : 0;
		} catch (_) {
			return 0;
		}
	}

	ITextMetrics _createMetrics(TextMetrics metrics, {double? widthOverride}) {
		double metricProperty(String name) {
			final dynamic value = js_util.getProperty(metrics, name);
			return value is num ? value.toDouble() : 0;
		}

		final double resolvedWidth = widthOverride ?? metricProperty('width');

		return ITextMetrics(
			width: resolvedWidth,
			actualBoundingBoxAscent: metricProperty('actualBoundingBoxAscent'),
			actualBoundingBoxDescent: metricProperty('actualBoundingBoxDescent'),
			actualBoundingBoxLeft: metricProperty('actualBoundingBoxLeft'),
			actualBoundingBoxRight: metricProperty('actualBoundingBoxRight'),
			fontBoundingBoxAscent: metricProperty('fontBoundingBoxAscent'),
			fontBoundingBoxDescent: metricProperty('fontBoundingBoxDescent'),
		);
	}

	String get _defaultColor => options.defaultColor ?? '#3d4756';
}