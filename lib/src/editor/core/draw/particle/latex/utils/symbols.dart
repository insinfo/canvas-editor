class Symb {
	const Symb({
		required this.glyph,
		this.arity,
		this.flags = const <String, bool>{},
	});

	final int glyph;
	final int? arity;
	final Map<String, bool> flags;
}

const Map<String, Symb> SYMB = <String, Symb>{
	r"\frac": Symb(glyph: 0, arity: 2),
	r"\binom": Symb(glyph: 0, arity: 2),
	r"\sqrt": Symb(
		glyph: 2267,
		arity: 1,
		flags: <String, bool>{'opt': true, 'xfl': true, 'yfl': true},
	),
	'^': Symb(glyph: 0, arity: 1),
	'_': Symb(glyph: 0, arity: 1),
	'(': Symb(glyph: 2221, flags: <String, bool>{'yfl': true}),
	')': Symb(glyph: 2222, flags: <String, bool>{'yfl': true}),
	'[': Symb(glyph: 2223, flags: <String, bool>{'yfl': true}),
	']': Symb(glyph: 2224, flags: <String, bool>{'yfl': true}),
	r"\langle": Symb(glyph: 2227, flags: <String, bool>{'yfl': true}),
	r"\rangle": Symb(glyph: 2228, flags: <String, bool>{'yfl': true}),
	'|': Symb(glyph: 2229, flags: <String, bool>{'yfl': true}),
	r"\|": Symb(glyph: 2230, flags: <String, bool>{'yfl': true}),
	r"\{": Symb(glyph: 2225, flags: <String, bool>{'yfl': true}),
	r"\}": Symb(glyph: 2226, flags: <String, bool>{'yfl': true}),
	r"\#": Symb(glyph: 2275),
	r"\$": Symb(glyph: 2274),
	r"\&": Symb(glyph: 2273),
	r"\%": Symb(glyph: 2271),
	r"\begin": Symb(glyph: 0, arity: 1),
	r"\end": Symb(glyph: 0, arity: 1),
	r"\left": Symb(glyph: 0, arity: 1),
	r"\right": Symb(glyph: 0, arity: 1),
	r"\middle": Symb(glyph: 0, arity: 1),
	r"\cdot": Symb(glyph: 2236),
	r"\pm": Symb(glyph: 2233),
	r"\mp": Symb(glyph: 2234),
	r"\times": Symb(glyph: 2235),
	r"\div": Symb(glyph: 2237),
	r"\leqq": Symb(glyph: 2243),
	r"\geqq": Symb(glyph: 2244),
	r"\leq": Symb(glyph: 2243),
	r"\geq": Symb(glyph: 2244),
	r"\propto": Symb(glyph: 2245),
	r"\sim": Symb(glyph: 2246),
	r"\equiv": Symb(glyph: 2240),
	r"\dagger": Symb(glyph: 2277),
	r"\ddagger": Symb(glyph: 2278),
	r"\ell": Symb(glyph: 662),
	r"\vec": Symb(
		glyph: 2261,
		arity: 1,
		flags: <String, bool>{'hat': true, 'xfl': true, 'yfl': true},
	),
	r"\overrightarrow": Symb(
		glyph: 2261,
		arity: 1,
		flags: <String, bool>{'hat': true, 'xfl': true, 'yfl': true},
	),
	r"\overleftarrow": Symb(
		glyph: 2263,
		arity: 1,
		flags: <String, bool>{'hat': true, 'xfl': true, 'yfl': true},
	),
	r"\bar": Symb(
		glyph: 2231,
		arity: 1,
		flags: <String, bool>{'hat': true, 'xfl': true},
	),
	r"\overline": Symb(
		glyph: 2231,
		arity: 1,
		flags: <String, bool>{'hat': true, 'xfl': true},
	),
	r"\widehat": Symb(
		glyph: 2247,
		arity: 1,
		flags: <String, bool>{'hat': true, 'xfl': true, 'yfl': true},
	),
	r"\hat": Symb(
		glyph: 2247,
		arity: 1,
		flags: <String, bool>{'hat': true},
	),
	r"\acute": Symb(
		glyph: 2248,
		arity: 1,
		flags: <String, bool>{'hat': true},
	),
	r"\grave": Symb(
		glyph: 2249,
		arity: 1,
		flags: <String, bool>{'hat': true},
	),
	r"\breve": Symb(
		glyph: 2250,
		arity: 1,
		flags: <String, bool>{'hat': true},
	),
	r"\tilde": Symb(
		glyph: 2246,
		arity: 1,
		flags: <String, bool>{'hat': true},
	),
	r"\underline": Symb(
		glyph: 2231,
		arity: 1,
		flags: <String, bool>{'mat': true, 'xfl': true},
	),
	r"\not": Symb(glyph: 2220, arity: 1),
	r"\neq": Symb(glyph: 2239, arity: 1),
	r"\ne": Symb(glyph: 2239, arity: 1),
	r"\exists": Symb(glyph: 2279),
	r"\in": Symb(glyph: 2260),
	r"\subset": Symb(glyph: 2256),
	r"\supset": Symb(glyph: 2258),
	r"\cup": Symb(glyph: 2257),
	r"\cap": Symb(glyph: 2259),
	r"\infty": Symb(glyph: 2270),
	r"\partial": Symb(glyph: 2265),
	r"\nabla": Symb(glyph: 2266),
	r"\aleph": Symb(glyph: 2077),
	r"\wp": Symb(glyph: 2190),
	r"\therefore": Symb(glyph: 740),
	r"\mid": Symb(glyph: 2229),
	r"\sum": Symb(glyph: 2402, flags: <String, bool>{'big': true}),
	r"\prod": Symb(glyph: 2401, flags: <String, bool>{'big': true}),
	r"\bigoplus": Symb(glyph: 2284, flags: <String, bool>{'big': true}),
	r"\bigodot": Symb(glyph: 2281, flags: <String, bool>{'big': true}),
	r"\int": Symb(glyph: 2412, flags: <String, bool>{'yfl': true}),
	r"\oint": Symb(glyph: 2269, flags: <String, bool>{'yfl': true}),
	r"\oplus": Symb(glyph: 1284),
	r"\odot": Symb(glyph: 1281),
	r"\perp": Symb(glyph: 738),
	r"\angle": Symb(glyph: 739),
	r"\triangle": Symb(glyph: 842),
	r"\Box": Symb(glyph: 841),
	r"\rightarrow": Symb(glyph: 2261),
	r"\to": Symb(glyph: 2261),
	r"\leftarrow": Symb(glyph: 2263),
	r"\gets": Symb(glyph: 2263),
	r"\circ": Symb(glyph: 902),
	r"\bigcirc": Symb(glyph: 904),
	r"\bullet": Symb(glyph: 828),
	r"\star": Symb(glyph: 856),
	r"\diamond": Symb(glyph: 743),
	r"\ast": Symb(glyph: 728),
		r"\log": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\ln": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\exp": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\mod": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\lim": Symb(glyph: 0, flags: <String, bool>{'txt': true, 'big': true}),
		r"\sin": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\cos": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\tan": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\csc": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\sec": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\cot": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\sinh": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\cosh": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\tanh": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\csch": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\sech": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\coth": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\arcsin": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\arccos": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\arctan": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\arccsc": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\arcsec": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
		r"\arccot": Symb(glyph: 0, flags: <String, bool>{'txt': true}),
	r"\text": Symb(glyph: 0, arity: 1),
	r"\mathnormal": Symb(glyph: 0, arity: 1),
	r"\mathrm": Symb(glyph: 0, arity: 1),
	r"\mathit": Symb(glyph: 0, arity: 1),
	r"\mathbf": Symb(glyph: 0, arity: 1),
	r"\mathsf": Symb(glyph: 0, arity: 1),
	r"\mathtt": Symb(glyph: 0, arity: 1),
	r"\mathfrak": Symb(glyph: 0, arity: 1),
	r"\mathcal": Symb(glyph: 0, arity: 1),
	r"\mathbb": Symb(glyph: 0, arity: 1),
	r"\mathscr": Symb(glyph: 0, arity: 1),
	r"\rm": Symb(glyph: 0, arity: 1),
	r"\it": Symb(glyph: 0, arity: 1),
	r"\bf": Symb(glyph: 0, arity: 1),
	r"\sf": Symb(glyph: 0, arity: 1),
	r"\tt": Symb(glyph: 0, arity: 1),
	r"\frak": Symb(glyph: 0, arity: 1),
	r"\cal": Symb(glyph: 0, arity: 1),
	r"\bb": Symb(glyph: 0, arity: 1),
	r"\scr": Symb(glyph: 0, arity: 1),
	r"\quad": Symb(glyph: 0),
	r"\,": Symb(glyph: 0),
	r"\.": Symb(glyph: 0),
	r"\;": Symb(glyph: 0),
	r"\!": Symb(glyph: 0),
	r"\alpha": Symb(glyph: 2127),
	r"\beta": Symb(glyph: 2128),
	r"\gamma": Symb(glyph: 2129),
	r"\delta": Symb(glyph: 2130),
	r"\varepsilon": Symb(glyph: 2131),
	r"\zeta": Symb(glyph: 2132),
	r"\eta": Symb(glyph: 2133),
	r"\vartheta": Symb(glyph: 2134),
	r"\iota": Symb(glyph: 2135),
	r"\kappa": Symb(glyph: 2136),
	r"\lambda": Symb(glyph: 2137),
	r"\mu": Symb(glyph: 2138),
	r"\nu": Symb(glyph: 2139),
	r"\xi": Symb(glyph: 2140),
	r"\omicron": Symb(glyph: 2141),
	r"\pi": Symb(glyph: 2142),
	r"\rho": Symb(glyph: 2143),
	r"\sigma": Symb(glyph: 2144),
	r"\tau": Symb(glyph: 2145),
	r"\upsilon": Symb(glyph: 2146),
	r"\varphi": Symb(glyph: 2147),
	r"\chi": Symb(glyph: 2148),
	r"\psi": Symb(glyph: 2149),
	r"\omega": Symb(glyph: 2150),
	r"\epsilon": Symb(glyph: 2184),
	r"\theta": Symb(glyph: 2185),
	r"\phi": Symb(glyph: 2186),
	r"\varsigma": Symb(glyph: 2187),
	r"\Alpha": Symb(glyph: 2027),
	r"\Beta": Symb(glyph: 2028),
	r"\Gamma": Symb(glyph: 2029),
	r"\Delta": Symb(glyph: 2030),
	r"\Epsilon": Symb(glyph: 2031),
	r"\Zeta": Symb(glyph: 2032),
	r"\Eta": Symb(glyph: 2033),
	r"\Theta": Symb(glyph: 2034),
	r"\Iota": Symb(glyph: 2035),
	r"\Kappa": Symb(glyph: 2036),
	r"\Lambda": Symb(glyph: 2037),
	r"\Mu": Symb(glyph: 2038),
	r"\Nu": Symb(glyph: 2039),
	r"\Xi": Symb(glyph: 2040),
	r"\Omicron": Symb(glyph: 2041),
	r"\Pi": Symb(glyph: 2042),
	r"\Rho": Symb(glyph: 2043),
	r"\Sigma": Symb(glyph: 2044),
	r"\Tau": Symb(glyph: 2045),
	r"\Upsilon": Symb(glyph: 2046),
	r"\Phi": Symb(glyph: 2047),
	r"\Chi": Symb(glyph: 2048),
	r"\Psi": Symb(glyph: 2049),
	r"\Omega": Symb(glyph: 2050),
};

const Map<String, int> _asciiFallback = <String, int>{
	'.': 2210,
	',': 2211,
	':': 2212,
	';': 2213,
	'!': 2214,
	'?': 2215,
	"'": 2216,
	'"': 2217,
	'*': 2219,
	'/': 2220,
	'-': 2231,
	'+': 2232,
	'=': 2238,
	'<': 2241,
	'>': 2242,
	'~': 2246,
	'@': 2273,
		'\\': 804,
};

int? asciiMap(String x, [String mode = 'math']) {
	if (x.isEmpty) {
		return null;
	}

	final int c = x.codeUnitAt(0);
	if (c >= 65 && c <= 90) {
		final int d = c - 65;
		switch (mode) {
			case 'text':
			case 'rm':
				return d + 2001;
			case 'tt':
				return d + 501;
			case 'bf':
			case 'bb':
				return d + 3001;
			case 'sf':
				return d + 2501;
			case 'frak':
				return d + 3301;
			case 'scr':
			case 'cal':
				return d + 2551;
			default:
				return d + 2051;
		}
	}

	if (c >= 97 && c <= 122) {
		final int d = c - 97;
		switch (mode) {
			case 'text':
			case 'rm':
				return d + 2101;
			case 'tt':
				return d + 601;
			case 'bf':
			case 'bb':
				return d + 3101;
			case 'sf':
				return d + 2601;
			case 'frak':
				return d + 3401;
			case 'scr':
			case 'cal':
				return d + 2651;
			default:
				return d + 2151;
		}
	}

	if (c >= 48 && c <= 57) {
		final int d = c - 48;
		switch (mode) {
			case 'it':
				return d + 2750;
			case 'bf':
				return d + 3200;
			case 'tt':
				return d + 700;
			default:
				return d + 2200;
		}
	}

	return _asciiFallback[x];
}
