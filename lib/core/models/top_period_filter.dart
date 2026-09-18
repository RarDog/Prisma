enum TopPeriodFilter {
  none,
  day,
  week,
  month,
  year,
  allTime;

  String get label {
    return switch (this) {
      TopPeriodFilter.none => 'Latest',
      TopPeriodFilter.day => 'Top day',
      TopPeriodFilter.week => 'Top week',
      TopPeriodFilter.month => 'Top month',
      TopPeriodFilter.year => 'Top year',
      TopPeriodFilter.allTime => 'Top all time',
    };
  }

  String get labelRu {
    return switch (this) {
      TopPeriodFilter.none => 'Свежее',
      TopPeriodFilter.day => 'Топ дня',
      TopPeriodFilter.week => 'Топ недели',
      TopPeriodFilter.month => 'Топ месяца',
      TopPeriodFilter.year => 'Топ года',
      TopPeriodFilter.allTime => 'За всё время',
    };
  }

  String localizedLabel(bool isRu) => isRu ? labelRu : label;
}
