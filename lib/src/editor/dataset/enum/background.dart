enum BackgroundSize {
  contain('contain'),
  cover('cover');

  final String value;

  const BackgroundSize(this.value);
}

enum BackgroundRepeat {
  repeat('repeat'),
  noRepeat('no-repeat'),
  repeatX('repeat-x'),
  repeatY('repeat-y');

  final String value;

  const BackgroundRepeat(this.value);
}
