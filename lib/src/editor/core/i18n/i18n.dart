import 'dart:convert';

import '../../interface/common.dart';
import '../../interface/i18n/i18n.dart';
import '../../utils/index.dart' show mergeObject;

class I18n {
  I18n(String locale)
      : _currentLocale = locale,
        _langMap = <String, Map<String, dynamic>>{
          'zhCN': _deepCopy(_zhCnLang),
          'en': _deepCopy(_enLang),
        };

  String _currentLocale;
  final Map<String, Map<String, dynamic>> _langMap;

  void registerLangMap(String locale, DeepPartial<ILang> lang) {
    final Map<String, dynamic> base = _langMap[locale] ?? _deepCopy(_zhCnLang);
    final Map<String, dynamic> merged = mergeObject(
      _deepCopy(base),
      _deepCopy(Map<String, dynamic>.from(lang)),
    ) as Map<String, dynamic>;
    _langMap[locale] = merged;
  }

  String getLocale() => _currentLocale;

  void setLocale(String locale) {
    _currentLocale = locale;
  }

  Map<String, dynamic> getLang() =>
      _langMap[_currentLocale] ?? _langMap['zhCN']!;

  String t(String path) {
    final keys = path.split('.');
    dynamic value = getLang();
    for (final key in keys) {
      if (value is Map<String, dynamic> && value.containsKey(key)) {
        value = value[key];
      } else {
        return '';
      }
    }
    return value is String ? value : '';
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> source) =>
      jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
}

const Map<String, dynamic> _zhCnLang = {
  'contextmenu': {
    'global': {
      'cut': '剪切',
      'copy': '复制',
      'paste': '粘贴',
      'selectAll': '全选',
      'print': '打印',
    },
    'control': {
      'delete': '删除控件',
    },
    'hyperlink': {
      'delete': '删除链接',
      'cancel': '取消链接',
      'edit': '编辑链接',
    },
    'image': {
      'change': '更改图片',
      'saveAs': '另存为图片',
      'textWrap': '文字环绕',
      'textWrapType': {
        'embed': '嵌入型',
        'upDown': '上下型环绕',
        'surround': '四周型环绕',
        'floatTop': '浮于文字上方',
        'floatBottom': '衬于文字下方',
      },
    },
    'table': {
      'insertRowCol': '插入行列',
      'insertTopRow': '上方插入1行',
      'insertBottomRow': '下方插入1行',
      'insertLeftCol': '左侧插入1列',
      'insertRightCol': '右侧插入1列',
      'deleteRowCol': '删除行列',
      'deleteRow': '删除1行',
      'deleteCol': '删除1列',
      'deleteTable': '删除整个表格',
      'mergeCell': '合并单元格',
      'mergeCancelCell': '取消合并',
      'verticalAlign': '垂直对齐',
      'verticalAlignTop': '顶端对齐',
      'verticalAlignMiddle': '垂直居中',
      'verticalAlignBottom': '底端对齐',
      'border': '表格边框',
      'borderAll': '所有框线',
      'borderEmpty': '无框线',
      'borderDash': '虚框线',
      'borderExternal': '外侧框线',
      'borderInternal': '内侧框线',
      'borderTd': '单元格边框',
      'borderTdTop': '上边框',
      'borderTdRight': '右边框',
      'borderTdBottom': '下边框',
      'borderTdLeft': '左边框',
      'borderTdForward': '正斜线',
      'borderTdBack': '反斜线',
    },
  },
  'datePicker': {
    'now': '此刻',
    'confirm': '确定',
    'return': '返回日期',
    'timeSelect': '时间选择',
    'weeks': {
      'sun': '日',
      'mon': '一',
      'tue': '二',
      'wed': '三',
      'thu': '四',
      'fri': '五',
      'sat': '六',
    },
    'year': '年',
    'month': '月',
    'hour': '时',
    'minute': '分',
    'second': '秒',
  },
  'frame': {
    'header': '页眉',
    'footer': '页脚',
  },
  'pageBreak': {
    'displayName': '分页符',
  },
  'zone': {
    'headerTip': '双击编辑页眉',
    'footerTip': '双击编辑页脚',
  },
};

const Map<String, dynamic> _enLang = {
  'contextmenu': {
    'global': {
      'cut': 'Cut',
      'copy': 'Copy',
      'paste': 'Paste',
      'selectAll': 'Select all',
      'print': 'Print',
    },
    'control': {
      'delete': 'Delete control',
    },
    'hyperlink': {
      'delete': 'Delete hyperlink',
      'cancel': 'Cancel hyperlink',
      'edit': 'Edit hyperlink',
    },
    'image': {
      'change': 'Change image',
      'saveAs': 'Save as image',
      'textWrap': 'Text wrap',
      'textWrapType': {
        'embed': 'Embed',
        'upDown': 'Up down',
        'surround': 'Surround',
        'floatTop': 'Float above text',
        'floatBottom': 'Float below text',
      },
    },
    'table': {
      'insertRowCol': 'Insert row col',
      'insertTopRow': 'Insert top 1 row',
      'insertBottomRow': 'Insert bottom 1 row',
      'insertLeftCol': 'Insert left 1 col',
      'insertRightCol': 'Insert right 1 col',
      'deleteRowCol': 'Delete row col',
      'deleteRow': 'Delete 1 row',
      'deleteCol': 'Delete 1 col',
      'deleteTable': 'Delete table',
      'mergeCell': 'Merge cell',
      'mergeCancelCell': 'Cancel merge cell',
      'verticalAlign': 'Vertical align',
      'verticalAlignTop': 'Top',
      'verticalAlignMiddle': 'Middle',
      'verticalAlignBottom': 'Bottom',
      'border': 'Table border',
      'borderAll': 'All',
      'borderEmpty': 'Empty',
      'borderDash': 'Dash',
      'borderExternal': 'External',
      'borderInternal': 'Internal',
      'borderTd': 'Table cell border',
      'borderTdTop': 'Top',
      'borderTdRight': 'Right',
      'borderTdBottom': 'Bottom',
      'borderTdLeft': 'Left',
      'borderTdForward': 'Forward',
      'borderTdBack': 'Back',
    },
  },
  'datePicker': {
    'now': 'Now',
    'confirm': 'Confirm',
    'return': 'Return',
    'timeSelect': 'Time select',
    'weeks': {
      'sun': 'Sun',
      'mon': 'Mon',
      'tue': 'Tue',
      'wed': 'Wed',
      'thu': 'Thu',
      'fri': 'Fri',
      'sat': 'Sat',
    },
    'year': ' ',
    'month': ' ',
    'hour': 'Hour',
    'minute': 'Minute',
    'second': 'Second',
  },
  'frame': {
    'header': 'Header',
    'footer': 'Footer',
  },
  'pageBreak': {
    'displayName': 'Page Break',
  },
  'zone': {
    'headerTip': 'Double click to edit header',
    'footerTip': 'Double click to edit footer',
  },
};
