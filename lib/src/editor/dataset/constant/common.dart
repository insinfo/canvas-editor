import '../enum/common.dart';

const String ZERO = '\u200B';
const String WRAP = '\n';
const String HORIZON_TAB = '\t';
const String NBSP = '\u0020';
const String NON_BREAKING_SPACE = '&nbsp;';
const List<String> PUNCTUATION_LIST = [
  '·',
  '、',
  ':',
  '：',
  ',',
  '，',
  '.',
  '。',
  ';',
  '；',
  '?',
  '？',
  '!',
  '！'
];

const Map<MaxHeightRatio, double> maxHeightRadioMapping = {
  MaxHeightRatio.half: 1 / 2,
  MaxHeightRatio.oneThird: 1 / 3,
  MaxHeightRatio.quarter: 1 / 4
};

class LetterClass {
  static const String ENGLISH = 'A-Za-z';
  static const String SPANISH = 'A-Za-zÁÉÍÓÚáéíóúÑñÜü';
  static const String FRENCH = 'A-Za-zÀÂÇàâçÉéÈèÊêËëÎîÏïÔôÙùÛûŸÿ';
  static const String GERMAN = 'A-Za-zÄäÖöÜüß';
  static const String RUSSIAN = 'А-Яа-яЁё';
  static const String PORTUGUESE = 'A-Za-zÁÉÍÓÚáéíóúÃÕãõÇç';
  static const String ITALIAN = 'A-Za-zÀàÈèÉéÌìÍíÎîÓóÒòÙù';
  static const String DUTCH = 'A-Za-zÀàÁáÂâÄäÈèÉéÊêËëÌìÍíÎîÏïÓóÒòÔôÖöÙùÛûÜü';
  static const String SWEDISH = 'A-Za-zÅåÄäÖö';
  static const String GREEK = 'ΑαΒβΓγΔδΕεΖζΗηΘθΙιΚκΛλΜμΝνΞξΟοΠπΡρΣσςΤτΥυΦφΧχΨψΩω';
}

const String METRICS_BASIS_TEXT = '日';