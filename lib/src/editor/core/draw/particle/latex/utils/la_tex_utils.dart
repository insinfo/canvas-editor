// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';
import 'dart:html';
import 'dart:math' as math;

import 'hershey.dart';
import 'symbols.dart';

const double _subSupScale = 0.5;
const double _sqrtMagScale = 0.5;
const double _fracScale = 0.85;
const double _lineSpacing = 0.5;
const double _fracSpacing = 0.4;

const Map<String, double> CONFIG = <String, double>{
	'SUB_SUP_SCALE': _subSupScale,
	'SQRT_MAG_SCALE': _sqrtMagScale,
	'FRAC_SCALE': _fracScale,
	'LINE_SPACING': _lineSpacing,
	'FRAC_SPACING': _fracSpacing,
};

final RegExp _wordCharReg = RegExp(r'[A-Za-z0-9\.]');

List<String> tokenize(String input) {
	String str = input.replaceAll('\n', ' ');
	final List<String> tokens = <String>[];
	String curr = '';
	for (int i = 0; i < str.length; i++) {
		final String ch = str[i];
		if (ch == ' ') {
			if (curr.isNotEmpty) {
				tokens.add(curr);
				curr = '';
			}
		} else if (ch == r'\') {
			if (curr.length == 1 && curr[0] == r'\') {
				curr += ch;
				tokens.add(curr);
				curr = '';
			} else {
				if (curr.isNotEmpty) {
					tokens.add(curr);
				}
				curr = ch;
			}
		} else if (_wordCharReg.hasMatch(ch)) {
			curr += ch;
		} else {
			if (curr.isNotEmpty && curr != r'\') {
				tokens.add(curr);
				curr = '';
			}
			curr += ch;
			tokens.add(curr);
			curr = '';
		}
	}
	if (curr.isNotEmpty) {
		tokens.add(curr);
	}
	return tokens;
}

class Bbox {
	Bbox({
		required this.x,
		required this.y,
		required this.w,
		required this.h,
	});

	double x;
	double y;
	double w;
	double h;
}

class Expr {
	Expr({
		required this.type,
		required this.text,
		required this.mode,
		List<Expr>? children,
		this.bbox,
	}) : chld = children ?? <Expr>[];

	String type;
	String text;
	String mode;
	List<Expr> chld;
	Bbox? bbox;
}

Expr parseAtom(String token) {
	final Symb? symb = SYMB[token];
	return Expr(
		type: symb != null ? 'symb' : 'char',
		text: token,
		mode: 'math',
		children: <Expr>[],
		bbox: null,
	);
}

Expr parse(List<String> tokens) {
	int index = 0;

	Expr? takeOpt() {
		if (index >= tokens.length || tokens[index] != '[') {
			return null;
		}
		int lvl = 0;
		int j = index;
		while (j < tokens.length) {
			if (tokens[j] == '[') {
				lvl++;
			} else if (tokens[j] == ']') {
				lvl--;
				if (lvl == 0) {
					break;
				}
			}
			j++;
		}
		final Expr opt = parse(tokens.sublist(index + 1, j));
		index = j;
		return opt;
	}

	List<Expr> takeN(int n) {
		int j = index;
		int start = j;
		int lvl = 0;
		int count = 0;
		final List<Expr> result = <Expr>[];
		while (j < tokens.length) {
			final String token = tokens[j];
			if (token == '{') {
				if (lvl == 0) {
					start = j;
				}
				lvl++;
			} else if (token == '}') {
				lvl--;
				if (lvl == 0) {
					result.add(parse(tokens.sublist(start + 1, j)));
					count++;
					if (count == n) {
						break;
					}
				}
			} else if (lvl == 0) {
				result.add(parseAtom(token));
				count++;
				if (count == n) {
					break;
				}
			}
			j++;
		}
		index = j;
		return result;
	}

	Expr root = Expr(
		type: 'node',
		text: '',
		mode: 'math',
		children: <Expr>[],
		bbox: null,
	);

	while (index < tokens.length) {
		final String token = tokens[index];
		final Symb? symb = SYMB[token];
		final Expr current = Expr(
			type: '',
			text: token,
			mode: 'math',
			children: <Expr>[],
			bbox: null,
		);

		if (symb != null) {
			if (symb.arity != null) {
				index++;
				current.type = 'func';
				Expr? opt;
				if (symb.flags['opt'] == true) {
					opt = takeOpt();
					if (opt != null) {
						index++;
					}
				}
				final List<Expr> children = takeN(symb.arity!);
				current.chld = children;
				if (opt != null) {
					current.chld.add(opt);
				}
			} else {
				current.type = 'symb';
			}
		} else {
			if (token == '{') {
				current.type = 'node';
				current.text = '';
				index++;
				current.chld = takeN(1);
			} else {
				current.type = 'char';
			}
		}

		root.chld.add(current);
		index++;
	}

	if (root.chld.length == 1) {
		root = root.chld.first;
	}
	return root;
}

void environments(List<Expr> exprs) {
	int i = 0;
	while (i < exprs.length) {
		if (exprs[i].text == r'\begin') {
			int j = i;
			for (; j < exprs.length; j++) {
				if (exprs[j].text == r'\end') {
					break;
				}
			}
			final List<Expr> slice = exprs.sublist(i + 1, j);
			environments(slice);
			exprs[i]
				..text = exprs[i].chld.isNotEmpty ? exprs[i].chld.first.text : ''
				..chld = slice;
			exprs.removeAt(i + 1);
		}
		i++;
	}
}

void transform(
	Expr expr,
	double sclx, [
	double? scly,
	double x = 0,
	double y = 0,
	bool notFirst = false,
]) {
	if (expr.bbox == null) {
		return;
	}
	scly ??= sclx;
	if (notFirst) {
		expr.bbox!
			..x *= sclx
			..y *= scly;
	}
	expr.bbox!
		..w *= sclx
		..h *= scly;
	for (final Expr child in expr.chld) {
		transform(child, sclx, scly, 0, 0, true);
	}
	expr.bbox!
		..x += x
		..y += y;
}

Bbox computeBbox(List<Expr> exprs) {
	double xmin = double.infinity;
	double xmax = double.negativeInfinity;
	double ymin = double.infinity;
	double ymax = double.negativeInfinity;

	for (final Expr expr in exprs) {
		final Bbox? bbox = expr.bbox;
		if (bbox == null) {
			continue;
		}
		xmin = math.min(xmin, bbox.x);
		ymin = math.min(ymin, bbox.y);
		xmax = math.max(xmax, bbox.x + bbox.w);
		ymax = math.max(ymax, bbox.y + bbox.h);
	}

	if (xmin == double.infinity || ymin == double.infinity) {
		return Bbox(x: 0, y: 0, w: 0, h: 0);
	}
	return Bbox(x: xmin, y: ymin, w: xmax - xmin, h: ymax - ymin);
}

Expr? group(List<Expr> exprs) {
	if (exprs.isEmpty) {
		return null;
	}
	final Bbox bbox = computeBbox(exprs);
	for (final Expr expr in exprs) {
		if (expr.bbox == null) {
			continue;
		}
		expr.bbox!
			..x -= bbox.x
			..y -= bbox.y;
	}
	return Expr(
		type: 'node',
		text: '',
		mode: 'math',
		children: exprs,
		bbox: bbox,
	);
}

void align(List<Expr> exprs, [String alignment = 'center']) {
	for (int i = 0; i < exprs.length; i++) {
		final Expr expr = exprs[i];
		if (expr.bbox == null) {
			continue;
		}
		if (expr.text == '^' || expr.text == "'") {
			double baseline = 0;
			int j = i;
			while (j > 0 &&
					(exprs[j].text == '^' ||
							exprs[j].text == '_' ||
							exprs[j].text == "'")) {
				j--;
			}
			baseline = exprs[j].bbox?.y ?? 0;
			if (expr.text == "'") {
				expr.bbox!.y = baseline;
			} else {
				transform(expr, _subSupScale, null, 0, 0);
				final Symb? ref = SYMB[exprs[j].text];
				if (ref != null && ref.flags['big'] == true) {
					expr.bbox!.y = baseline - expr.bbox!.h;
				} else if (exprs[j].text == r'\int') {
					expr.bbox!.y = baseline;
				} else {
					expr.bbox!.y = baseline - expr.bbox!.h / 2;
				}
			}
		} else if (expr.text == '_') {
			double baseline = 0;
			int j = i;
			while (j > 0 &&
					(exprs[j].text == '^' ||
							exprs[j].text == '_' ||
							exprs[j].text == "'")) {
				j--;
			}
			baseline = (exprs[j].bbox?.y ?? 0) + (exprs[j].bbox?.h ?? 0);
			transform(expr, _subSupScale, null, 0, 0);
			final Symb? ref = SYMB[exprs[j].text];
			if (ref != null && ref.flags['big'] == true) {
				expr.bbox!.y = baseline;
			} else if (exprs[j].text == r'\int') {
				expr.bbox!.y = baseline - expr.bbox!.h;
			} else {
				expr.bbox!.y = baseline - expr.bbox!.h / 2;
			}
		}
	}

	List<double> searchHigh(
		int start,
		String left,
		String right,
		int dir,
		int lvl0,
	) {
		int j = start;
		int lvl = lvl0;
		double ymin = double.infinity;
		double ymax = double.negativeInfinity;
		bool condition() => dir > 0 ? j < exprs.length : j >= 0;
		while (condition()) {
			final Expr expr = exprs[j];
			if (expr.text == left) {
				lvl++;
			} else if (expr.text == right) {
				lvl--;
				if (lvl == 0) {
					break;
				}
			} else if (expr.text == '^' || expr.text == '_') {
				// skip
			} else if (expr.bbox != null) {
				ymin = math.min(ymin, expr.bbox!.y);
				ymax = math.max(ymax, expr.bbox!.y + expr.bbox!.h);
			}
			j += dir;
		}
		return <double>[ymin, ymax];
	}

	for (int i = 0; i < exprs.length; i++) {
		final Expr expr = exprs[i];
		if (expr.bbox == null) {
			continue;
		}
		if (expr.text == r'\left') {
			final List<double> bounds = searchHigh(i, r'\left', r'\right', 1, 0);
			final double ymin = bounds[0];
			final double ymax = bounds[1];
			if (ymin != double.infinity && ymax != double.negativeInfinity) {
				expr.bbox!.y = ymin;
				transform(expr, 1, (ymax - ymin) / expr.bbox!.h, 0, 0);
			}
		} else if (expr.text == r'\right') {
			final List<double> bounds = searchHigh(i, r'\right', r'\left', -1, 0);
			final double ymin = bounds[0];
			final double ymax = bounds[1];
			if (ymin != double.infinity && ymax != double.negativeInfinity) {
				expr.bbox!.y = ymin;
				transform(expr, 1, (ymax - ymin) / expr.bbox!.h, 0, 0);
			}
		} else if (expr.text == r'\middle') {
			final List<double> leftBounds =
					searchHigh(i, r'\right', r'\left', -1, 1);
			final List<double> rightBounds =
					searchHigh(i, r'\left', r'\right', 1, 1);
			final double ymin = math.min(leftBounds[0], rightBounds[0]);
			final double ymax = math.max(leftBounds[1], rightBounds[1]);
			if (ymin != double.infinity && ymax != double.negativeInfinity) {
				expr.bbox!.y = ymin;
				transform(expr, 1, (ymax - ymin) / expr.bbox!.h, 0, 0);
			}
		}
	}

	final bool hasTableSeparators =
			exprs.any((Expr e) => e.text == '&' || e.text == r'\\');
	if (!hasTableSeparators) {
		return;
	}

	final List<List<List<Expr>>> rows = <List<List<Expr>>>[];
	List<List<Expr>> currentRow = <List<Expr>>[];
	List<Expr> currentCell = <Expr>[];
	for (final Expr expr in exprs) {
		if (expr.text == '&') {
			currentRow.add(currentCell);
			currentCell = <Expr>[];
		} else if (expr.text == r'\\') {
			if (currentCell.isNotEmpty) {
				currentRow.add(currentCell);
				currentCell = <Expr>[];
			}
			rows.add(currentRow);
			currentRow = <List<Expr>>[];
		} else {
			currentCell.add(expr);
		}
	}
	if (currentCell.isNotEmpty) {
		currentRow.add(currentCell);
	}
	if (currentRow.isNotEmpty) {
		rows.add(currentRow);
	}

	final List<double> columnWidths = <double>[];
	final List<List<Expr?>> groupedRows = <List<Expr?>>[];
	for (final List<List<Expr>> row in rows) {
		final List<Expr?> grouped = <Expr?>[];
		for (int j = 0; j < row.length; j++) {
			final Expr? groupedExpr = group(row[j]);
			if (groupedExpr != null) {
				if (columnWidths.length <= j) {
					columnWidths.add(0);
				}
				columnWidths[j] = math.max(columnWidths[j], groupedExpr.bbox!.w + 1);
			}
			grouped.add(groupedExpr);
		}
		groupedRows.add(grouped);
	}

	final List<List<double>> rowBounds = <List<double>>[];
	for (final List<Expr?> row in groupedRows) {
		double ymin = double.infinity;
		double ymax = double.negativeInfinity;
		for (final Expr? cell in row) {
			if (cell?.bbox == null) {
				continue;
			}
			ymin = math.min(ymin, cell!.bbox!.y);
			ymax = math.max(ymax, cell.bbox!.y + cell.bbox!.h);
		}
		rowBounds.add(<double>[ymin, ymax]);
	}

	for (int i = 0; i < rowBounds.length; i++) {
		if (rowBounds[i][0] == double.infinity ||
				rowBounds[i][1] == double.infinity) {
			final double fallback =
					i == 0 ? 0 : rowBounds[i - 1][1];
			rowBounds[i][0] = fallback;
			rowBounds[i][1] = fallback + 2;
		}
	}

	for (int i = 1; i < groupedRows.length; i++) {
		final double shift =
				rowBounds[i - 1][1] - rowBounds[i][0] + _lineSpacing;
		for (final Expr? cell in groupedRows[i]) {
			if (cell?.bbox != null) {
				cell!.bbox!.y += shift;
			}
		}
		rowBounds[i][0] += shift;
		rowBounds[i][1] += shift;
	}

	exprs
		..clear()
		..length = 0;
	for (int i = 0; i < groupedRows.length; i++) {
		double dx = 0;
		for (int j = 0; j < groupedRows[i].length; j++) {
			final Expr? cell = groupedRows[i][j];
			if (cell == null || cell.bbox == null) {
				if (columnWidths.length > j) {
					dx += columnWidths[j];
				}
				continue;
			}
			cell.bbox!.x += dx;
			final double remaining = columnWidths[j] - cell.bbox!.w;
			if (alignment == 'center') {
				cell.bbox!.x += remaining / 2;
			} else if (alignment == 'right' ||
					(alignment == 'equation' && j != groupedRows[i].length - 1)) {
				cell.bbox!.x += remaining;
			}
			exprs.add(cell);
			dx += columnWidths[j];
		}
	}
}

void plan(Expr expr, [String mode = 'math']) {
	final Map<String, String> modeMap = <String, String>{
		r'\text': 'text',
		r'\mathnormal': 'math',
		r'\mathrm': 'rm',
		r'\mathit': 'it',
		r'\mathbf': 'bf',
		r'\mathsf': 'sf',
		r'\mathtt': 'tt',
		r'\mathfrak': 'frak',
		r'\mathcal': 'cal',
		r'\mathbb': 'bb',
		r'\mathscr': 'scr',
		r'\rm': 'rm',
		r'\it': 'it',
		r'\bf': 'bf',
		r'\sf': 'tt',
		r'\tt': 'tt',
		r'\frak': 'frak',
		r'\cal': 'cal',
		r'\bb': 'bb',
		r'\scr': 'scr',
	};
	final String nextMode = modeMap[expr.text] ?? mode;

	if (expr.chld.isEmpty) {
		final Symb? symb = SYMB[expr.text];
		if (symb != null) {
			if (symb.flags['big'] == true) {
				expr.bbox = symb.flags['txt'] == true
						? Bbox(x: 0, y: 0, w: 3.5, h: 2)
						: Bbox(x: 0, y: symb.flags['mat'] == true ? 0 : -0.5, w: 3, h: 3);
				if (expr.text == r'\lim') {
					expr.bbox = Bbox(x: 0, y: 0, w: 3.5, h: 2);
				}
			} else if (symb.flags['txt'] == true) {
				double width = 0;
				for (int i = 1; i < expr.text.length; i++) {
					final int? glyph = asciiMap(expr.text[i], 'text');
					if (glyph == null) {
						continue;
					}
					width += HERSHEY(glyph)?.width ?? 0;
				}
				width /= 16;
				expr.bbox = Bbox(x: 0, y: 0, w: width, h: 2);
			} else if (symb.glyph != 0) {
				double width = HERSHEY(symb.glyph)?.width.toDouble() ?? 0;
				width /= 16;
				if (expr.text == r'\int' || expr.text == r'\oint') {
					expr.bbox = Bbox(x: 0, y: -1.5, w: width, h: 5);
				} else {
					expr.bbox = Bbox(x: 0, y: 0, w: width, h: 2);
				}
			} else {
				expr.bbox = Bbox(x: 0, y: 0, w: 1, h: 2);
			}
		} else {
			double width = 0;
			for (int i = 0; i < expr.text.length; i++) {
				final int? glyph = asciiMap(expr.text[i], nextMode);
				if (glyph == null) {
					continue;
				}
				final HersheyEntry? entry = HERSHEY(glyph);
				if (entry == null) {
					continue;
				}
				width += nextMode == 'tt' ? 16 : entry.width;
			}
			width /= 16;
			expr.bbox = Bbox(x: 0, y: 0, w: width, h: 2);
		}
		expr.mode = nextMode;
		return;
	}

	if (expr.text == r'\frac') {
		final Expr numerator = expr.chld[0];
		final Expr denominator = expr.chld[1];
		plan(numerator);
		plan(denominator);
			numerator.bbox!
				..x = 0
				..y = 0;
			denominator.bbox!
				..x = 0
				..y = 0;
		final double maxWidth = math.max(numerator.bbox!.w, denominator.bbox!.w);
		transform(numerator, _fracScale, null, (maxWidth - numerator.bbox!.w) / 2, 0);
		transform(
			denominator,
			_fracScale,
			null,
			(maxWidth - denominator.bbox!.w) / 2,
			numerator.bbox!.h + _fracSpacing,
		);
		expr.bbox = Bbox(
			x: 0,
			y: -numerator.bbox!.h + 1 - _fracSpacing / 2,
			w: maxWidth,
			h: numerator.bbox!.h + denominator.bbox!.h + _fracSpacing,
		);
	} else if (expr.text == r'\binom') {
		final Expr top = expr.chld[0];
		final Expr bottom = expr.chld[1];
		plan(top);
		plan(bottom);
			top.bbox!
				..x = 0
				..y = 0;
			bottom.bbox!
				..x = 0
				..y = 0;
		final double maxWidth = math.max(top.bbox!.w, bottom.bbox!.w);
		transform(top, 1, null, (maxWidth - top.bbox!.w) / 2 + 1, 0);
		transform(bottom, 1, null, (maxWidth - bottom.bbox!.w) / 2 + 1, top.bbox!.h);
		expr.bbox = Bbox(x: 0, y: -top.bbox!.h + 1, w: maxWidth + 2, h: top.bbox!.h + bottom.bbox!.h);
	} else if (expr.text == r'\sqrt') {
		final Expr body = expr.chld[0];
		plan(body);
		Expr? degree = expr.chld.length > 1 ? expr.chld[1] : null;
		double prefixLength = 0;
		if (degree != null) {
			plan(degree);
			prefixLength = math.max(degree.bbox!.w * _sqrtMagScale - 0.5, 0);
			transform(degree, _sqrtMagScale, null, 0, 0.5);
		}
		transform(body, 1, null, 1 + prefixLength, 0.5);
		expr.bbox = Bbox(
			x: 0,
			y: 2 - body.bbox!.h - 0.5,
			w: body.bbox!.w + 1 + prefixLength,
			h: body.bbox!.h + 0.5,
		);
	} else if (SYMB[expr.text]?.flags['hat'] == true) {
		final Expr child = expr.chld[0];
		plan(child);
		final double offset = child.bbox!.y - 0.5;
		child.bbox!.y = 0.5;
		expr.bbox = Bbox(x: 0, y: offset, w: child.bbox!.w, h: child.bbox!.h + 0.5);
	} else if (SYMB[expr.text]?.flags['mat'] == true) {
		final Expr child = expr.chld[0];
		plan(child);
		expr.bbox = Bbox(x: 0, y: 0, w: child.bbox!.w, h: child.bbox!.h + 0.5);
	} else {
		double dx = 0;
		double dy = 0;
		double maxHeight = 1;
		for (int i = 0; i < expr.chld.length; i++) {
			final Expr child = expr.chld[i];
			final Map<String, double> spacing = <String, double>{
				r'\quad': 2,
				r'\,': 6 / 18,
				r'\:': 8 / 18,
				r'\;': 10 / 18,
				r'\!': -6 / 18,
			};
			final double? space = spacing[child.text];

			if (child.text == r'\\') {
				dy += maxHeight;
				dx = 0;
				maxHeight = 1;
				continue;
			} else if (child.text == '&') {
				continue;
			} else if (space != null) {
				dx += space;
				continue;
			}

			plan(child, nextMode);
			transform(child, 1, null, dx, dy);

			if (child.text == '^' || child.text == '_' || child.text == "'") {
				int j = i;
				while (j > 0 &&
						(expr.chld[j].text == '^' ||
								expr.chld[j].text == '_' ||
								expr.chld[j].text == "'")) {
					j--;
				}
				final Expr anchor = expr.chld[j];
				final Symb? anchorSymb = SYMB[anchor.text];
				final bool isBig = anchorSymb?.flags['big'] == true;
				if (child.text == "'") {
					int k = j + 1;
					int nth = 0;
					while (k < i) {
						if (expr.chld[k].text == "'") {
							nth++;
						}
						k++;
					}
					child.bbox!.x =
							anchor.bbox!.x + anchor.bbox!.w + child.bbox!.w * nth;
					dx = math.max(dx, child.bbox!.x + child.bbox!.w);
				} else {
					if (isBig) {
						final double offset = anchor.bbox!.x +
								(anchor.bbox!.w - child.bbox!.w * _subSupScale) / 2;
						child.bbox!.x = offset;
						dx = math.max(
							dx,
							anchor.bbox!.x +
									anchor.bbox!.w +
									(child.bbox!.w * _subSupScale - anchor.bbox!.w) / 2,
						);
					} else {
						child.bbox!.x = anchor.bbox!.x + anchor.bbox!.w;
						dx = math.max(dx, child.bbox!.x + child.bbox!.w * _subSupScale);
					}
				}
			} else {
				dx += child.bbox!.w;
			}

			if (nextMode == 'text') {
				dx += 1;
			}
			maxHeight = math.max(child.bbox!.y + child.bbox!.h - dy, maxHeight);
		}
		dy += maxHeight;

		final Map<String, List<String>> matrixParens = <String, List<String>>{
			'bmatrix': <String>['[', ']'],
			'pmatrix': <String>['(', ')'],
			'Bmatrix': <String>[r'\{', r'\}'],
			'cases': <String>[r'\{'],
		};
		final Map<String, String> alignmentMap = <String, String>{
			'bmatrix': 'center',
			'pmatrix': 'center',
			'Bmatrix': 'center',
			'cases': 'left',
			'matrix': 'center',
			'aligned': 'equation',
		};
		final String tableAlignment = alignmentMap[expr.text] ?? 'left';
		final bool hasLeftParen = matrixParens.containsKey(expr.text);
		final bool hasRightParen =
				matrixParens[expr.text]?.length == 2;

		align(expr.chld, tableAlignment);
		final Bbox contentBbox = computeBbox(expr.chld);
		if (expr.text == r'\text') {
			contentBbox.x -= 1;
			contentBbox.w += 2;
		}

		for (final Expr child in expr.chld) {
			transform(
				child,
				1,
				null,
				-contentBbox.x + (hasLeftParen ? 1.5 : 0),
				-contentBbox.y,
			);
		}

		expr.bbox = Bbox(
			x: 0,
			y: 0,
			w: contentBbox.w + 1.5 * (hasLeftParen ? 1 : 0) +
					1.5 * (hasRightParen ? 1 : 0),
			h: contentBbox.h,
		);

		if (hasLeftParen) {
			expr.chld.insert(
				0,
				Expr(
					type: 'symb',
					text: matrixParens[expr.text]![0],
					mode: expr.mode,
					children: <Expr>[],
					bbox: Bbox(x: 0, y: 0, w: 1, h: contentBbox.h),
				),
			);
		}
		if (hasRightParen) {
			expr.chld.add(
				Expr(
					type: 'symb',
					text: matrixParens[expr.text]![1],
					mode: expr.mode,
					children: <Expr>[],
					bbox: Bbox(x: contentBbox.w + 2, y: 0, w: 1, h: contentBbox.h),
				),
			);
		}
		if (hasLeftParen || hasRightParen || expr.text == 'matrix') {
			expr
				..type = 'node'
				..text = ''
				..bbox = Bbox(
					x: 0,
					y: expr.bbox!.y - (expr.bbox!.h - 2) / 2,
					w: expr.bbox!.w,
					h: expr.bbox!.h,
				);
		}
	}
	expr.mode = nextMode;
}

void flatten(Expr expr) {
	List<Expr> flat(Expr node, double dx, double dy) {
		final List<Expr> flattened = <Expr>[];
		if (node.bbox != null) {
			dx += node.bbox!.x;
			dy += node.bbox!.y;
			if (node.text == r'\frac') {
				final double h =
						node.chld[1].bbox!.y -
								(node.chld[0].bbox!.y + node.chld[0].bbox!.h);
				flattened.add(
					Expr(
						type: 'symb',
						text: r'\bar',
						mode: node.mode,
						children: <Expr>[],
						bbox: Bbox(
							x: dx,
							y: dy +
									(node.chld[1].bbox!.y - h / 2) -
									h / 2,
							w: node.bbox!.w,
							h: h,
						),
					),
				);
				flattened.add(
					Expr(
						type: 'symb',
						text: r'\bar',
						mode: node.mode,
						children: <Expr>[],
						bbox: Bbox(
							x: dx + node.chld[0].bbox!.x,
							y: dy,
							w: node.bbox!.w - node.chld[0].bbox!.x,
							h: node.chld[0].bbox!.y,
						),
					),
				);
			} else if (node.text == r'\sqrt') {
				final double h = node.chld[0].bbox!.y;
				final double xx = math.max(0, node.chld[0].bbox!.x - node.chld[0].bbox!.h / 2);
				flattened.add(
					Expr(
						type: 'symb',
						text: r'\sqrt',
						mode: node.mode,
						children: <Expr>[],
						bbox: Bbox(
							x: dx + xx,
							y: dy + h / 2,
							w: node.chld[0].bbox!.x - xx,
							h: node.bbox!.h - h / 2,
						),
					),
				);
			} else if (node.text == r'\binom') {
				final double w = math.min(node.chld[0].bbox!.x, node.chld[1].bbox!.x);
				flattened.add(
					Expr(
						type: 'symb',
						text: '(',
						mode: node.mode,
						children: <Expr>[],
						bbox: Bbox(x: dx, y: dy, w: w, h: node.bbox!.h),
					),
				);
				flattened.add(
					Expr(
						type: 'symb',
						text: ')',
						mode: node.mode,
						children: <Expr>[],
						bbox: Bbox(
							x: dx + node.bbox!.w - w,
							y: dy,
							w: w,
							h: node.bbox!.h,
						),
					),
				);
			} else if (SYMB[node.text]?.flags['hat'] == true) {
				final double h = node.chld[0].bbox!.y;
				flattened.add(
					Expr(
						type: 'symb',
						text: node.text,
						mode: node.mode,
						children: <Expr>[],
						bbox: Bbox(x: dx, y: dy, w: node.bbox!.w, h: h),
					),
				);
			} else if (SYMB[node.text]?.flags['mat'] == true) {
				final double h = node.chld[0].bbox!.h;
				flattened.add(
					Expr(
						type: 'symb',
						text: node.text,
						mode: node.mode,
						children: <Expr>[],
						bbox: Bbox(
							x: dx,
							y: dy + h,
							w: node.bbox!.w,
							h: node.bbox!.h - h,
						),
					),
				);
			} else if (node.type != 'node' && node.text != '^' && node.text != '_') {
				flattened.add(
					Expr(
						type: node.type == 'func' ? 'symb' : node.type,
						text: node.text,
						mode: node.mode,
						children: <Expr>[],
						bbox: Bbox(
							x: dx,
							y: dy,
							w: node.bbox!.w,
							h: node.bbox!.h,
						),
					),
				);
			}
		}
		for (final Expr child in node.chld) {
			flattened.addAll(flat(child, dx, dy));
		}
		return flattened;
	}

	final List<Expr> flattened = flat(expr, -expr.bbox!.x, -expr.bbox!.y);
	expr
		..type = 'node'
		..text = ''
		..chld = flattened;
}

List<List<List<double>>> render(Expr expr) {
		final List<List<List<double>>> output = <List<List<double>>>[];
	for (final Expr child in expr.chld) {
		final Bbox? bbox = child.bbox;
		if (bbox == null) {
			continue;
		}
		double s = bbox.h / 2;
		bool isSmallHat = false;
		final Symb? symb = SYMB[child.text];
		if (symb != null &&
				symb.flags['hat'] == true &&
				symb.flags['xfl'] != true &&
				symb.flags['yfl'] != true) {
			s *= 4;
			isSmallHat = true;
		}
		if (symb != null && symb.glyph != 0) {
			final HersheyEntry? data = HERSHEY(symb.glyph);
			if (data == null) {
				continue;
			}
			for (final List<List<int>> polyline in data.polylines) {
			final List<List<double>> line = <List<double>>[];
				for (final List<int> point in polyline) {
					double x = point[0].toDouble();
					double y = point[1].toDouble();
					if (symb.flags['xfl'] == true) {
						x = ((x - data.xmin) /
										math.max(data.xmax - data.xmin, 1)) *
								bbox.w;
						x += bbox.x;
					} else if ((data.width / 16) * s > bbox.w) {
						x = (x / math.max(data.width, 1)) * bbox.w;
						x += bbox.x;
					} else {
						x = (x / 16) * s;
						final double padding = (bbox.w - (data.width / 16) * s) / 2;
						x += bbox.x + padding;
					}
					if (symb.flags['yfl'] == true) {
						y = ((y - data.ymin) /
										math.max(data.ymax - data.ymin, 1)) *
								bbox.h;
						y += bbox.y;
					} else {
						y = (y / 16) * s;
						if (isSmallHat) {
							final double center = (data.ymax + data.ymin) / 2;
							y -= (center / 16) * s;
						}
						y += bbox.y + bbox.h / 2;
					}
					line.add(<double>[x, y]);
				}
				output.add(line);
			}
		} else if ((symb != null && symb.flags['txt'] == true) ||
				child.type == 'char') {
					double x0 = bbox.x;
					final bool isVerb = symb?.flags['txt'] == true;
					final int start = isVerb ? 1 : 0;
					for (int i = start; i < child.text.length; i++) {
						final int? glyph = asciiMap(child.text[i], isVerb ? 'text' : child.mode);
						if (glyph == null) {
							window.console.warn('unmapped character: ${child.text[i]}');
							continue;
						}
						final HersheyEntry? data = HERSHEY(glyph);
				if (data == null) {
					window.console.warn('unmapped character: ${child.text[i]}');
					continue;
				}
				for (final List<List<int>> polyline in data.polylines) {
							final List<List<double>> line = <List<double>>[];
					for (final List<int> point in polyline) {
						double x = point[0] / 16 * s;
						double y = point[1] / 16 * s;
						if (child.mode == 'tt') {
							if (data.width > 16) {
								x *= 16 / data.width;
							} else {
								x += (16 - data.width) / 32;
							}
						}
						x += x0;
						y += bbox.y + bbox.h / 2;
						line.add(<double>[x, y]);
					}
					output.add(line);
				}
				if (child.mode == 'tt') {
					x0 += s;
				} else {
					x0 += (data.width / 16) * s;
				}
			}
		}
	}
	return output;
}

double _nf(double value) => (value * 100).round() / 100;

class ExportOpt {
	const ExportOpt({
		this.minCharHeight,
		this.maxWidth,
		this.maxHeight,
		this.marginX,
		this.marginY,
		this.scaleX,
		this.scaleY,
		this.strokeWidth,
		this.fgColor,
		this.bgColor,
	});

	final double? minCharHeight;
	final double? maxWidth;
	final double? maxHeight;
	final double? marginX;
	final double? marginY;
	final double? scaleX;
	final double? scaleY;
	final double? strokeWidth;
	final String? fgColor;
	final String? bgColor;
}

class LaTexSvg {
	LaTexSvg({required this.svg, required this.width, required this.height});

	final String svg;
	final int width;
	final int height;
}

class LaTexUtils {
	factory LaTexUtils(String latex) {
		final List<String> tokens = tokenize(latex);
		final Expr tree = parse(List<String>.from(tokens));
		environments(tree.chld);
		plan(tree);
		flatten(tree);
		final List<List<List<double>>> polylines = render(tree);
		return LaTexUtils._(latex, tokens, tree, polylines);
	}

	LaTexUtils._(this._latex, this._tokens, this._tree, this._polylines);

		// ignore: unused_field
		final String _latex;
		// ignore: unused_field
		final List<String> _tokens;
	final Expr _tree;
	final List<List<List<double>>> _polylines;

	List<double> _resolveScale([ExportOpt? opt]) {
		opt ??= const ExportOpt();
		double sclx = opt.scaleX ?? 16;
		double scly = opt.scaleY ?? 16;

		if (opt.minCharHeight != null) {
			double minHeight = double.infinity;
			for (final Expr child in _tree.chld) {
				if (child.bbox == null) {
					continue;
				}
				if (child.type == 'char' ||
						(SYMB[child.text] != null &&
								(SYMB[child.text]!.flags['txt'] == true ||
										SYMB[child.text]!.flags.isEmpty))) {
					minHeight = math.min(minHeight, child.bbox!.h);
				}
			}
			if (minHeight != double.infinity && minHeight > 0) {
				final double scale = math.max(1, opt.minCharHeight! / minHeight);
				sclx *= scale;
				scly *= scale;
			}
		}
		if (opt.maxWidth != null && _tree.bbox != null && _tree.bbox!.w > 0) {
			final double original = sclx;
			sclx = math.min(sclx, opt.maxWidth! / _tree.bbox!.w);
			scly *= sclx / original;
		}
		if (opt.maxHeight != null && _tree.bbox != null && _tree.bbox!.h > 0) {
			final double original = scly;
			scly = math.min(scly, opt.maxHeight! / _tree.bbox!.h);
			sclx *= scly / original;
		}
		final double px = opt.marginX ?? sclx;
		final double py = opt.marginY ?? scly;
		return <double>[px, py, sclx, scly];
	}

	List<List<List<double>>> polylines([ExportOpt? opt]) {
		final List<double> scale = _resolveScale(opt);
		final double px = scale[0];
		final double py = scale[1];
		final double sclx = scale[2];
		final double scly = scale[3];
		final List<List<List<double>>> result = <List<List<double>>>[];
		for (final List<List<double>> polyline in _polylines) {
		final List<List<double>> line = <List<double>>[];
			for (final List<double> point in polyline) {
				final double x = px + point[0] * sclx;
				final double y = py + point[1] * scly;
				line.add(<double>[x, y]);
			}
			result.add(line);
		}
		return result;
	}

	String pathd([ExportOpt? opt]) {
		final StringBuffer buffer = StringBuffer();
		final List<double> scale = _resolveScale(opt);
		final double px = scale[0];
		final double py = scale[1];
		final double sclx = scale[2];
		final double scly = scale[3];
		for (final List<List<double>> polyline in _polylines) {
			for (int i = 0; i < polyline.length; i++) {
				final double x = px + polyline[i][0] * sclx;
				final double y = py + polyline[i][1] * scly;
				buffer
					..write(i == 0 ? 'M' : 'L')
					..write(_nf(x))
					..write(' ')
					..write(_nf(y));
			}
		}
		return buffer.toString();
	}

	LaTexSvg svg([ExportOpt? opt]) {
		final List<double> scale = _resolveScale(opt);
		final double px = scale[0];
		final double py = scale[1];
		final double sclx = scale[2];
		final double scly = scale[3];
		final double width = _nf(_tree.bbox!.w * sclx + px * 2);
		final double height = _nf(_tree.bbox!.h * scly + py * 2);
		final double strokeWidth = opt?.strokeWidth ?? 1;
		final String fgColor = opt?.fgColor ?? 'black';
		final StringBuffer buffer = StringBuffer();
		buffer.write('''<svg
			xmlns="http://www.w3.org/2000/svg"
			width="$width" height="$height"
			fill="none" stroke="$fgColor" stroke-width="$strokeWidth"
			stroke-linecap="round" stroke-linejoin="round"
		>''');
		if (opt?.bgColor != null) {
			buffer.write(
					'<rect x="0" y="0" width="$width" height="$height" fill="${opt!.bgColor}" stroke="none"></rect>');
		}
		buffer.write('<path d="');
		for (final List<List<double>> polyline in _polylines) {
			buffer.write('M');
			for (final List<double> point in polyline) {
				final double x = px + point[0] * sclx;
				final double y = py + point[1] * scly;
				buffer
					..write(_nf(x))
					..write(' ')
					..write(_nf(y))
					..write(' ');
			}
		}
		buffer.write('"/>');
		buffer.write('</svg>');
		final String encoded = base64Encode(utf8.encode(buffer.toString()));
		return LaTexSvg(
			svg: 'data:image/svg+xml;base64,$encoded',
			width: width.ceil(),
			height: height.ceil(),
		);
	}

	String pdf([ExportOpt? opt]) {
		final List<double> scale = _resolveScale(opt);
		final double px = scale[0];
		final double py = scale[1];
		final double sclx = scale[2];
		final double scly = scale[3];
		final double width = _nf(_tree.bbox!.w * sclx + px * 2);
		final double height = _nf(_tree.bbox!.h * scly + py * 2);
		final double strokeWidth = opt?.strokeWidth ?? 1;

		final StringBuffer header = StringBuffer(
				'%PDF-1.1\n%%¥±ë\n1 0 obj\n<< /Type /Catalog\n/Pages 2 0 R\n>>endobj\n'
				'2 0 obj\n<< /Type /Pages\n/Kids [3 0 R]\n/Count 1\n/MediaBox [0 0 $width $height]\n>>\nendobj\n'
				'3 0 obj\n<< /Type /Page\n/Parent 2 0 R\n/Resources\n<< /Font\n<< /F1\n<< /Type /Font\n'
				'/Subtype /Type1\n/BaseFont /Times-Roman\n>>\n>>\n>>\n/Contents [');

		final StringBuffer body = StringBuffer();
		int objIndex = 4;
		for (final List<List<double>> polyline in _polylines) {
			body.write('$objIndex 0 obj \n<< /Length 0 >>\n stream\n 1 j 1 J $strokeWidth w\n');
			for (int i = 0; i < polyline.length; i++) {
				final double x = px + polyline[i][0] * sclx;
				final double y = height - (py + polyline[i][1] * scly);
				body
					..write('${_nf(x)} ${_nf(y)} ')
					..write(i == 0 ? 'm ' : 'l ');
			}
			body.write('\nS\nendstream\nendobj\n');
			header.write('$objIndex 0 R ');
			objIndex++;
		}
		header.write(']\n>>\nendobj\n');
		body.write('\ntrailer\n<< /Root 1 0 R \n /Size 0\n >>startxref\n\n%%EOF\n');
		return header.toString() + body.toString();
	}

	List<Bbox> boxes([ExportOpt? opt]) {
		final List<double> scale = _resolveScale(opt);
		final double px = scale[0];
		final double py = scale[1];
		final double sclx = scale[2];
		final double scly = scale[3];
		final List<Bbox> boxes = <Bbox>[];
		for (final Expr child in _tree.chld) {
			final Bbox? bbox = child.bbox;
			if (bbox == null) {
				continue;
			}
			boxes.add(
				Bbox(
					x: px + bbox.x * sclx,
					y: py + bbox.y * scly,
					w: bbox.w * sclx,
					h: bbox.h * scly,
				),
			);
		}
		return boxes;
	}

	Bbox box([ExportOpt? opt]) {
		final List<double> scale = _resolveScale(opt);
		final double px = scale[0];
		final double py = scale[1];
		final double sclx = scale[2];
		final double scly = scale[3];
		return Bbox(
			x: px + _tree.bbox!.x * sclx,
			y: py + _tree.bbox!.y * scly,
			w: _tree.bbox!.w * sclx,
			h: _tree.bbox!.h * scly,
		);
	}
}

final Map<String, Function> latexImpl = <String, Function>{
	'tokenize': tokenize,
	'parse': parse,
	'environments': environments,
	'plan': plan,
	'flatten': flatten,
	'render': render,
};
