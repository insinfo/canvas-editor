import '../../dataset/enum/background.dart';
import '../../interface/background.dart';

final IBackgroundOption defaultBackground = IBackgroundOption(
	color: '#FFFFFF',
	image: '',
	size: BackgroundSize.cover,
	repeat: BackgroundRepeat.noRepeat,
	applyPageNumbers: List<int>.unmodifiable(const <int>[]),
);