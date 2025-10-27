import '../enum/list.dart';

const Map<UlStyle, String> ulStyleMapping = {
  UlStyle.disc: '•',
  UlStyle.circle: '◦',
  UlStyle.square: '▫︎',
  UlStyle.checkbox: '☑️',
};

const Map<ListType, String> listTypeElementMapping = {
  ListType.ordered: 'ol',
  ListType.unordered: 'ul',
};

const Map<ListStyle, String> listStyleCssMapping = {
  ListStyle.disc: 'disc',
  ListStyle.circle: 'circle',
  ListStyle.square: 'square',
  ListStyle.decimal: 'decimal',
  ListStyle.checkbox: 'checkbox',
};
