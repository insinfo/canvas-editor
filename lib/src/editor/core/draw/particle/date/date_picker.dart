import 'dart:html';

import '../../../../dataset/constant/editor.dart';
import '../../../../dataset/enum/editor.dart';
import '../../../../interface/element.dart';
import '../../draw.dart';

class DatePickerWeeksLang {
  const DatePickerWeeksLang({
    required this.sun,
    required this.mon,
    required this.tue,
    required this.wed,
    required this.thu,
    required this.fri,
    required this.sat,
  });

  final String sun;
  final String mon;
  final String tue;
  final String wed;
  final String thu;
  final String fri;
  final String sat;
}

class IDatePickerLang {
  const IDatePickerLang({
    required this.now,
    required this.confirm,
    required this.returnText,
    required this.timeSelect,
    required this.weeks,
    required this.year,
    required this.month,
    required this.hour,
    required this.minute,
    required this.second,
  });

  final String now;
  final String confirm;
  final String returnText;
  final String timeSelect;
  final DatePickerWeeksLang weeks;
  final String year;
  final String month;
  final String hour;
  final String minute;
  final String second;
}

typedef DatePickerSubmit = void Function(String date);

class IDatePickerOption {
  const IDatePickerOption({this.onSubmit});

  final DatePickerSubmit? onSubmit;
}

class _DatePickerTitleDom {
  const _DatePickerTitleDom({
    required this.preYear,
    required this.preMonth,
    required this.now,
    required this.nextMonth,
    required this.nextYear,
  });

  final SpanElement preYear;
  final SpanElement preMonth;
  final SpanElement now;
  final SpanElement nextMonth;
  final SpanElement nextYear;
}

class _DatePickerTimeDom {
  const _DatePickerTimeDom({
    required this.hour,
    required this.minute,
    required this.second,
  });

  final OListElement hour;
  final OListElement minute;
  final OListElement second;
}

class _DatePickerMenuDom {
  const _DatePickerMenuDom({
    required this.time,
    required this.now,
    required this.submit,
  });

  final ButtonElement time;
  final ButtonElement now;
  final ButtonElement submit;
}

class _DatePickerDom {
  const _DatePickerDom({
    required this.container,
    required this.dateWrap,
    required this.weekItems,
    required this.timeWrap,
    required this.timeLabels,
    required this.title,
    required this.day,
    required this.time,
    required this.menu,
  });

  final DivElement container;
  final DivElement dateWrap;
  final List<SpanElement> weekItems;
  final UListElement timeWrap;
  final List<SpanElement> timeLabels;
  final _DatePickerTitleDom title;
  final DivElement day;
  final _DatePickerTimeDom time;
  final _DatePickerMenuDom menu;
}

class DatePickerRenderOption {
  DatePickerRenderOption({
    required this.value,
    required this.position,
    this.dateFormat,
  });

  String value;
  IElementPosition position;
  String? dateFormat;
}

class DatePicker {
  DatePicker(this._draw, [IDatePickerOption options = const IDatePickerOption()])
    : _options = options,
      _lang = const IDatePickerLang(
        now: '',
        confirm: '',
        returnText: '',
        timeSelect: '',
        weeks: DatePickerWeeksLang(
          sun: '',
          mon: '',
          tue: '',
          wed: '',
          thu: '',
          fri: '',
          sat: '',
        ),
        year: '',
        month: '',
        hour: '',
        minute: '',
        second: '',
      ),
      _now = DateTime.now(),
      _renderOptions = null,
      _isDatePicker = true,
      _pickDate = null {
    _dom = _createDom();
    _bindEvent();
  }

  final Draw _draw;
  final IDatePickerOption _options;
  late IDatePickerLang _lang;
  DateTime _now;
  late final _DatePickerDom _dom;
  DatePickerRenderOption? _renderOptions;
  bool _isDatePicker;
  DateTime? _pickDate;

  _DatePickerDom _createDom() {
    final DivElement container = DivElement()
      ..classes.add('${editorPrefix}-date-container')
      ..setAttribute(editorComponent, EditorComponent.popup.name);

    final DivElement dateWrap = DivElement()
      ..classes.add('${editorPrefix}-date-wrap');
    final DivElement titleWrap = DivElement()
      ..classes.add('${editorPrefix}-date-title');

    final SpanElement preYear = SpanElement()
      ..classes.add('${editorPrefix}-date-title__pre-year')
      ..innerText = '<<';
    final SpanElement preMonth = SpanElement()
      ..classes.add('${editorPrefix}-date-title__pre-month')
      ..innerText = '<';
    final SpanElement nowTitle = SpanElement()
      ..classes.add('${editorPrefix}-date-title__now');
    final SpanElement nextMonth = SpanElement()
      ..classes.add('${editorPrefix}-date-title__next-month')
      ..innerText = '>';
    final SpanElement nextYear = SpanElement()
      ..classes.add('${editorPrefix}-date-title__next-year')
      ..innerText = '>>';

    titleWrap
      ..append(preYear)
      ..append(preMonth)
      ..append(nowTitle)
      ..append(nextMonth)
      ..append(nextYear);

    final DivElement weekWrap = DivElement()
      ..classes.add('${editorPrefix}-date-week');
    final List<SpanElement> weekItems = <SpanElement>[];
    for (int i = 0; i < 7; i++) {
      final SpanElement weekSpan = SpanElement();
      weekItems.add(weekSpan);
      weekWrap.append(weekSpan);
    }

    final DivElement dayWrap = DivElement()
      ..classes.add('${editorPrefix}-date-day');

    dateWrap
      ..append(titleWrap)
      ..append(weekWrap)
      ..append(dayWrap);

    final UListElement timeWrap = UListElement()
      ..classes.add('${editorPrefix}-time-wrap');
    final List<SpanElement> timeLabels = <SpanElement>[];
    final List<OListElement> timeColumns = <OListElement>[];
    for (int i = 0; i < 3; i++) {
      final LIElement li = LIElement();
      final SpanElement text = SpanElement();
      timeLabels.add(text);
      li.append(text);
      final OListElement ol = OListElement();
      final int endIndex = i == 0 ? 24 : 60;
      for (int j = 0; j < endIndex; j++) {
        final LIElement item = LIElement()
          ..innerText = j.toString().padLeft(2, '0')
          ..setAttribute('data-id', '$j');
        ol.append(item);
      }
      timeColumns.add(ol);
      li.append(ol);
      timeWrap.append(li);
    }

    final DivElement menuWrap = DivElement()
      ..classes.add('${editorPrefix}-date-menu');
    final ButtonElement timeBtn = ButtonElement()
      ..classes.add('${editorPrefix}-date-menu__time');
    final ButtonElement nowBtn = ButtonElement()
      ..classes.add('${editorPrefix}-date-menu__now');
    final ButtonElement submitBtn = ButtonElement()
      ..classes.add('${editorPrefix}-date-menu__submit');
    menuWrap
      ..append(timeBtn)
      ..append(nowBtn)
      ..append(submitBtn);

    container
      ..append(dateWrap)
      ..append(timeWrap)
      ..append(menuWrap);
    _draw.getContainer().append(container);

    return _DatePickerDom(
      container: container,
      dateWrap: dateWrap,
      weekItems: weekItems,
      timeWrap: timeWrap,
      timeLabels: timeLabels,
      title: _DatePickerTitleDom(
        preYear: preYear,
        preMonth: preMonth,
        now: nowTitle,
        nextMonth: nextMonth,
        nextYear: nextYear,
      ),
      day: dayWrap,
      time: _DatePickerTimeDom(
        hour: timeColumns[0],
        minute: timeColumns[1],
        second: timeColumns[2],
      ),
      menu: _DatePickerMenuDom(
        time: timeBtn,
        now: nowBtn,
        submit: submitBtn,
      ),
    );
  }

  void _bindEvent() {
    _dom.title.preYear.onClick.listen((_) => _changeYear(-1));
    _dom.title.preMonth.onClick.listen((_) => _changeMonth(-1));
    _dom.title.nextMonth.onClick.listen((_) => _changeMonth(1));
    _dom.title.nextYear.onClick.listen((_) => _changeYear(1));
    _dom.menu.time.onClick.listen((_) {
      _isDatePicker = !_isDatePicker;
      _toggleDateTimePicker();
    });
    _dom.menu.now.onClick.listen((_) {
      _nowNow();
      _submit();
    });
    _dom.menu.submit.onClick.listen((_) {
      dispose();
      _submit();
    });
    _dom.time.hour.onClick.listen((Event evt) {
      if (_pickDate == null) {
        return;
      }
      final Element? target =
        (evt.target as Element?)?.closest('li');
      final String? id = target?.getAttribute('data-id');
      if (id == null) {
        return;
      }
      _pickDate = DateTime(
        _pickDate!.year,
        _pickDate!.month,
        _pickDate!.day,
        int.parse(id),
        _pickDate!.minute,
        _pickDate!.second,
        _pickDate!.millisecond,
      );
      _setTimePick(false);
    });
    _dom.time.minute.onClick.listen((Event evt) {
      if (_pickDate == null) {
        return;
      }
      final Element? target =
        (evt.target as Element?)?.closest('li');
      final String? id = target?.getAttribute('data-id');
      if (id == null) {
        return;
      }
      _pickDate = DateTime(
        _pickDate!.year,
        _pickDate!.month,
        _pickDate!.day,
        _pickDate!.hour,
        int.parse(id),
        _pickDate!.second,
        _pickDate!.millisecond,
      );
      _setTimePick(false);
    });
    _dom.time.second.onClick.listen((Event evt) {
      if (_pickDate == null) {
        return;
      }
      final Element? target =
        (evt.target as Element?)?.closest('li');
      final String? id = target?.getAttribute('data-id');
      if (id == null) {
        return;
      }
      _pickDate = DateTime(
        _pickDate!.year,
        _pickDate!.month,
        _pickDate!.day,
        _pickDate!.hour,
        _pickDate!.minute,
        int.parse(id),
        _pickDate!.millisecond,
      );
      _setTimePick(false);
    });
  }

  void _changeMonth(int delta) {
    _now = DateTime(_now.year, _now.month + delta, _now.day,
      _now.hour, _now.minute, _now.second, _now.millisecond);
    _update();
  }

  void _changeYear(int delta) {
    _now = DateTime(_now.year + delta, _now.month, _now.day,
      _now.hour, _now.minute, _now.second, _now.millisecond);
    _update();
  }

  void _setPosition() {
    final DatePickerRenderOption? options = _renderOptions;
    if (options == null) {
      return;
    }
    final IElementPosition position = options.position;
    final List<double>? leftTop =
      position.coordinate['leftTop']?.cast<double>();
    final double left = leftTop != null && leftTop.isNotEmpty ? leftTop[0] : 0;
    final double top = leftTop != null && leftTop.length > 1 ? leftTop[1] : 0;
    final double lineHeight = position.lineHeight;
    final double height = _draw.getHeight();
    final double pageGap = _draw.getPageGap();
    final int currentPageNo = position.pageNo;
    final double preY = currentPageNo * (height + pageGap);
    _dom.container.style
      ..left = '${left}px'
      ..top = '${top + preY + lineHeight}px';
  }

  void _setValue() {
    final String value = _renderOptions?.value ?? '';
    final DateTime? parsed = _parseDate(value);
    _now = parsed ?? DateTime.now();
    _pickDate = DateTime.fromMillisecondsSinceEpoch(
      _now.millisecondsSinceEpoch,
    );
  }

  DateTime? _parseDate(String value) {
    if (value.isEmpty) {
      return null;
    }
    DateTime? parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
    parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    return parsed;
  }

  IDatePickerLang _getLang() {
    final dynamic i18n = _draw.getI18n();
    String translate(String key) => i18n.t(key) as String;
    return IDatePickerLang(
      now: translate('datePicker.now'),
      confirm: translate('datePicker.confirm'),
      returnText: translate('datePicker.return'),
      timeSelect: translate('datePicker.timeSelect'),
      weeks: DatePickerWeeksLang(
        sun: translate('datePicker.weeks.sun'),
        mon: translate('datePicker.weeks.mon'),
        tue: translate('datePicker.weeks.tue'),
        wed: translate('datePicker.weeks.wed'),
        thu: translate('datePicker.weeks.thu'),
        fri: translate('datePicker.weeks.fri'),
        sat: translate('datePicker.weeks.sat'),
      ),
      year: translate('datePicker.year'),
      month: translate('datePicker.month'),
      hour: translate('datePicker.hour'),
      minute: translate('datePicker.minute'),
      second: translate('datePicker.second'),
    );
  }

  void _setLangChange() {
    _dom.menu.time.innerText =
      _isDatePicker ? _lang.timeSelect : _lang.returnText;
    _dom.menu.now.innerText = _lang.now;
    _dom.menu.submit.innerText = _lang.confirm;
    final List<String> weekList = <String>[
      _lang.weeks.sun,
      _lang.weeks.mon,
      _lang.weeks.tue,
      _lang.weeks.wed,
      _lang.weeks.thu,
      _lang.weeks.fri,
      _lang.weeks.sat,
    ];
    for (int i = 0; i < _dom.weekItems.length; i++) {
      _dom.weekItems[i].innerText = weekList[i];
    }
    final List<String> timeTexts = <String>[
      _lang.hour,
      _lang.minute,
      _lang.second,
    ];
    for (int i = 0; i < _dom.timeLabels.length; i++) {
      _dom.timeLabels[i].innerText = timeTexts[i];
    }
  }

  void _update() {
    final DateTime local = DateTime.now();
    final int localYear = local.year;
    final int localMonth = local.month;
    final int localDay = local.day;

    final DateTime? pick = _pickDate;
    final int? pickYear = pick?.year;
    final int? pickMonth = pick?.month;
    final int? pickDay = pick?.day;

    final int year = _now.year;
    final int month = _now.month;
    _dom.title.now.innerText =
      '$year${_lang.year} ${month.toString().padLeft(2, '0')}${_lang.month}';

    final DateTime currentMonthLastDay = DateTime(year, month + 1, 0);
    final int currentMonthTotal = currentMonthLastDay.day;

    int firstWeekday = DateTime(year, month, 1).weekday;
    if (firstWeekday == DateTime.sunday) {
      firstWeekday = 7;
    }
    final int previousMonthTotal = DateTime(year, month, 0).day;

    _dom.day.children.clear();

    final int preStartDay = previousMonthTotal - firstWeekday + 1;
    for (int i = preStartDay; i <= previousMonthTotal; i++) {
      _dom.day.append(_buildDayCell(
        i,
        isDisabled: true,
        onClick: () {
          _setDatePick(DateTime(year, month - 1, i));
        },
      ));
    }

    for (int i = 1; i <= currentMonthTotal; i++) {
      final bool isToday =
        localYear == year && localMonth == month && localDay == i;
      final bool isSelected = pickYear == year && pickMonth == month && pickDay == i;
      _dom.day.append(_buildDayCell(
        i,
        isToday: isToday,
        isSelected: isSelected,
        onClick: () {
          _setDatePick(DateTime(year, month, i));
        },
      ));
    }

    final int nextCells = 42 - firstWeekday - currentMonthTotal;
    for (int i = 1; i <= nextCells; i++) {
      _dom.day.append(_buildDayCell(
        i,
        isDisabled: true,
        onClick: () {
          _setDatePick(DateTime(year, month + 1, i));
        },
      ));
    }
  }

  DivElement _buildDayCell(
    int day, {
    bool isDisabled = false,
    bool isToday = false,
    bool isSelected = false,
    void Function()? onClick,
  }) {
    final DivElement cell = DivElement()
      ..innerText = '$day';
    if (isDisabled) {
      cell.classes.add('disable');
    }
    if (isToday) {
      cell.classes.add('active');
    }
    if (isSelected) {
      cell.classes.add('select');
    }
    if (onClick != null) {
      cell.onClick.listen((Event evt) {
        onClick();
        evt.stopPropagation();
      });
    }
    return cell;
  }

  void _setDatePick(DateTime date) {
    _now = DateTime(
      date.year,
      date.month,
      date.day,
      _now.hour,
      _now.minute,
      _now.second,
      _now.millisecond,
    );
    if (_pickDate != null) {
      _pickDate = DateTime(
        date.year,
        date.month,
        date.day,
        _pickDate!.hour,
        _pickDate!.minute,
        _pickDate!.second,
        _pickDate!.millisecond,
      );
    } else {
      _pickDate = DateTime.fromMillisecondsSinceEpoch(
        date.millisecondsSinceEpoch,
      );
    }
    _update();
  }

  void _setTimePick([bool isIntoView = true]) {
    _pickDate ??= DateTime.fromMillisecondsSinceEpoch(
      _now.millisecondsSinceEpoch,
    );
    final DateTime pick = _pickDate!;
    final int hour = pick.hour;
    final int minute = pick.minute;
    final int second = pick.second;
    final List<OListElement> domList = <OListElement>[
      _dom.time.hour,
      _dom.time.minute,
      _dom.time.second,
    ];
    for (final OListElement list in domList) {
      for (final Element child in list.children) {
        child.classes.remove('active');
      }
    }
    final List<int> times = <int>[hour, minute, second];
    for (int i = 0; i < domList.length; i++) {
      final OListElement list = domList[i];
      final Element? pickDom =
        list.querySelector("[data-id='${times[i]}']");
      if (pickDom is HtmlElement) {
        pickDom.classes.add('active');
        if (isIntoView) {
          _scrollIntoView(list, pickDom);
        }
      }
    }
  }

  void _scrollIntoView(HtmlElement container, HtmlElement selected) {
    int top = selected.offsetTop;
    HtmlElement? pointer = selected.offsetParent as HtmlElement?;
    while (pointer != null && pointer != container && container.contains(pointer)) {
      top += pointer.offsetTop;
      pointer = pointer.offsetParent as HtmlElement?;
    }
    final int bottom = top + selected.offsetHeight;
    final int viewTop = container.scrollTop;
    final int viewBottom = viewTop + container.clientHeight;
    if (top < viewTop) {
      container.scrollTop = top;
    } else if (bottom > viewBottom) {
      container.scrollTop = bottom - container.clientHeight;
    }
  }

  void _toggleDateTimePicker() {
    if (_isDatePicker) {
      _dom.dateWrap.classes.add('active');
      _dom.timeWrap.classes.remove('active');
      _dom.menu.time.innerText = _lang.timeSelect;
    } else {
      _dom.dateWrap.classes.remove('active');
      _dom.timeWrap.classes.add('active');
      _dom.menu.time.innerText = _lang.returnText;
      _setTimePick();
    }
  }

  void _nowNow() {
    _pickDate = DateTime.now();
    _now = DateTime.fromMillisecondsSinceEpoch(
      _pickDate!.millisecondsSinceEpoch,
    );
    dispose();
  }

  void _toggleVisible(bool isVisible) {
    if (isVisible) {
      _dom.container.classes.add('active');
    } else {
      _dom.container.classes.remove('active');
    }
  }

  void _submit() {
    final DatePickerSubmit? callback = _options.onSubmit;
    if (callback == null || _pickDate == null) {
      return;
    }
    final String format = _renderOptions?.dateFormat ?? 'YYYY-MM-DD HH:mm:ss';
    final String value = formatDate(_pickDate!, format);
    callback(value);
  }

  String formatDate(DateTime date, [String format = 'YYYY-MM-DD HH:mm:ss']) {
    String result = format;
    final Map<String, String> options = <String, String>{
      'y+': date.year.toString(),
      'Y+': date.year.toString(),
      'M+': date.month.toString(),
      'd+': date.day.toString(),
      'D+': date.day.toString(),
      'h+': _formatHour12(date.hour),
      'H+': date.hour.toString(),
      'm+': date.minute.toString(),
      's+': date.second.toString(),
      'S+': date.millisecond.toString(),
    };
    options.forEach((String pattern, String value) {
      result = result.replaceAllMapped(RegExp(pattern), (Match match) {
        final String token = match.group(0) ?? '';
        return token.length == 1
          ? value
          : value.padLeft(token.length, '0');
      });
    });
    return result;
  }

  String _formatHour12(int hour24) {
    final int hours12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return hours12.toString();
  }

  void render(DatePickerRenderOption option) {
    _renderOptions = option;
    _lang = _getLang();
    _isDatePicker = true;
    _setLangChange();
    _setValue();
    _update();
    _setPosition();
    _toggleDateTimePicker();
    _toggleVisible(true);
  }

  void dispose() {
    _toggleVisible(false);
  }

  void destroy() {
    _dom.container.remove();
  }
}
