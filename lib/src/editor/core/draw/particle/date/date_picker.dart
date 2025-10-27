class DatePickerWeeksLang {
  String sun;
  String mon;
  String tue;
  String wed;
  String thu;
  String fri;
  String sat;

  DatePickerWeeksLang({
    required this.sun,
    required this.mon,
    required this.tue,
    required this.wed,
    required this.thu,
    required this.fri,
    required this.sat,
  });
}

class IDatePickerLang {
  String now;
  String confirm;
  String returnText;
  String timeSelect;
  DatePickerWeeksLang weeks;
  String year;
  String month;
  String hour;
  String minute;
  String second;

  IDatePickerLang({
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
}

typedef DatePickerSubmit = dynamic Function(String date);

class IDatePickerOption {
  DatePickerSubmit? onSubmit;

  IDatePickerOption({this.onSubmit});
}

// TODO: Translate remaining DatePicker implementation from TypeScript.
