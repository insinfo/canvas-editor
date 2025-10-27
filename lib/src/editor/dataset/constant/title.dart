import '../../interface/title.dart';
import '../enum/title.dart';

/// Default size configuration for each heading level.
final ITitleOption defaultTitleOption = ITitleOption(
  defaultFirstSize: 26,
  defaultSecondSize: 24,
  defaultThirdSize: 22,
  defaultFourthSize: 20,
  defaultFifthSize: 18,
  defaultSixthSize: 16,
);

/// Maps a title level to the corresponding size option key.
const Map<TitleLevel, String> titleSizeMapping = {
  TitleLevel.first: 'defaultFirstSize',
  TitleLevel.second: 'defaultSecondSize',
  TitleLevel.third: 'defaultThirdSize',
  TitleLevel.fourth: 'defaultFourthSize',
  TitleLevel.fifth: 'defaultFifthSize',
  TitleLevel.sixth: 'defaultSixthSize',
};

/// Maps a title level to its order number when generating catalogs.
const Map<TitleLevel, int> titleOrderNumberMapping = {
  TitleLevel.first: 1,
  TitleLevel.second: 2,
  TitleLevel.third: 3,
  TitleLevel.fourth: 4,
  TitleLevel.fifth: 5,
  TitleLevel.sixth: 6,
};

/// Maps HTML heading tag names to the corresponding title level.
const Map<String, TitleLevel> titleNodeNameMapping = {
  'H1': TitleLevel.first,
  'H2': TitleLevel.second,
  'H3': TitleLevel.third,
  'H4': TitleLevel.fourth,
  'H5': TitleLevel.fifth,
  'H6': TitleLevel.sixth,
};
