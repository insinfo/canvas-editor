import '../../editor/index.dart'
    show Editor, ElementType, IElement, ListType, TitleLevel;

const Map<String, TitleLevel> titleNodeNameMapping = <String, TitleLevel>{
  '1': TitleLevel.first,
  '2': TitleLevel.second,
  '3': TitleLevel.third,
  '4': TitleLevel.fourth,
  '5': TitleLevel.fifth,
  '6': TitleLevel.sixth,
};

List<IElement> convertMarkdownToElement(String markdown) {
  final List<IElement> elementList = <IElement>[];
  final List<String> lines = markdown.trim().split('\n');

  final RegExp orderedListReg = RegExp(r'^\d+\.\s');
  final RegExp hyperlinkReg = RegExp(r'^\[(.*?)\]\((.*?)\)$');
  final RegExp boldReg = RegExp(r'^\*\*(.*?)\*\*$');
  final RegExp italicReg = RegExp(r'^\*(.*?)\*$');
  final RegExp underlineReg = RegExp(r'^__(.*?)__$');
  final RegExp strikeoutReg = RegExp(r'^~~(.*?)~~$');

  for (final String rawLine in lines) {
    final String line = rawLine;
    if (line.startsWith('#')) {
      final int levelIndex = line.indexOf(' ');
      if (levelIndex > 0) {
        final TitleLevel? level = titleNodeNameMapping['$levelIndex'];
        final String content = line.substring(levelIndex + 1).trimRight();
        elementList.add(
          IElement(
            type: ElementType.title,
            level: level,
            value: '',
            valueList: <IElement>[
              IElement(type: ElementType.text, value: content),
            ],
          ),
        );
        continue;
      }
    }

    if (line.startsWith('- ')) {
      final String content = line.substring(2);
      elementList.add(
        IElement(
          type: ElementType.list,
          listType: ListType.unordered,
          value: '',
          valueList: <IElement>[
            IElement(type: ElementType.text, value: content),
          ],
        ),
      );
      continue;
    }

    if (orderedListReg.hasMatch(line)) {
      final String content = line.replaceFirst(orderedListReg, '');
      elementList.add(
        IElement(
          type: ElementType.list,
          listType: ListType.ordered,
          value: '',
          valueList: <IElement>[
            IElement(type: ElementType.text, value: content),
          ],
        ),
      );
      continue;
    }

    final RegExpMatch? hyperlinkMatch = hyperlinkReg.firstMatch(line);
    if (hyperlinkMatch != null) {
      final String text = hyperlinkMatch.group(1) ?? '';
      final String url = hyperlinkMatch.group(2) ?? '';
      elementList.add(
        IElement(
          type: ElementType.hyperlink,
          value: '',
          valueList: <IElement>[
            IElement(type: ElementType.text, value: text),
          ],
          url: url,
        ),
      );
      continue;
    }

    final RegExpMatch? boldMatch = boldReg.firstMatch(line);
    if (boldMatch != null) {
      final String content = boldMatch.group(1) ?? '';
      elementList.add(
        IElement(
          type: ElementType.text,
          value: content,
          bold: true,
        ),
      );
      continue;
    }

    final RegExpMatch? italicMatch = italicReg.firstMatch(line);
    if (italicMatch != null) {
      final String content = italicMatch.group(1) ?? '';
      elementList.add(
        IElement(
          type: ElementType.text,
          value: content,
          italic: true,
        ),
      );
      continue;
    }

    final RegExpMatch? underlineMatch = underlineReg.firstMatch(line);
    if (underlineMatch != null) {
      final String content = underlineMatch.group(1) ?? '';
      elementList.add(
        IElement(
          type: ElementType.text,
          value: content,
          underline: true,
        ),
      );
      continue;
    }

    final RegExpMatch? strikeoutMatch = strikeoutReg.firstMatch(line);
    if (strikeoutMatch != null) {
      final String content = strikeoutMatch.group(1) ?? '';
      elementList.add(
        IElement(
          type: ElementType.text,
          value: content,
          strikeout: true,
        ),
      );
      continue;
    }

    elementList.add(
      IElement(type: ElementType.text, value: line),
    );
  }

  return elementList;
}

void markdownPlugin(Editor editor) {
  editor.command.setInsertMarkdownHandler((String markdown) {
    final List<IElement> elementList = convertMarkdownToElement(markdown);
    if (elementList.isNotEmpty) {
      editor.command.executeInsertElementList(elementList);
    }
  });
}