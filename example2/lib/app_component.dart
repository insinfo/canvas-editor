import 'dart:convert';
import 'dart:html';
import 'dart:js_util' as js_util;

import 'package:canvas_text_editor/canvas_text_editor.dart';
import 'package:limitless_ui/limitless_ui.dart';
import 'package:ngdart/angular.dart';

@Component(
  selector: 'my-app',
  templateUrl: 'app_component.html',
  styleUrls: <String>['app_component.css'],
  directives: <Object>[
    coreDirectives,
    LiDropdownMenuComponent,
  ],
  //encapsulation: ViewEncapsulation.none,
)
class AppComponent implements AfterViewInit, OnDestroy {
  @ViewChild('editorHost')
  DivElement? editorHost;

  CanvasEditorWidget? _canvasEditor;

  String mode = 'editor';
  String status = 'Editor pronto para uso';

  final List<LiDropdownMenuOption> modeOptions = const <LiDropdownMenuOption>[
    LiDropdownMenuOption(
      value: 'editor',
      label: 'Editor',
      iconClass: 'ph-pencil-simple',
      description: 'Edição e formatação habilitadas',
    ),
    LiDropdownMenuOption(
      value: 'viewer',
      label: 'Visualizador',
      iconClass: 'ph-eye',
      description: 'Documento totalmente somente leitura',
    ),
  ];

  @override
  void ngAfterViewInit() {
    final DivElement? host = editorHost;
    if (host == null) {
      throw StateError('O host do editor não foi criado pelo AngularDart.');
    }
    _canvasEditor = CanvasEditorWidget(
      host,
      config: CanvasEditorConfig(
        appearance: CanvasEditorAppearance.word,
        height: '560px',
        documentTitle: 'Documento clínico — Canvas Editor',
        onDocumentLoaded: (String fileName) {
          status = 'DOCX carregado: $fileName';
        },
        onError: (Object error) {
          status = 'Falha ao abrir DOCX: $error';
        },
        data: IEditorData(main: _sampleDocument()),
        editorOptions: IEditorOption(
          margins: <double>[76, 82, 76, 82],
          placeholder: IPlaceholder(data: 'Digite o conteúdo do documento'),
          historyMaxRecordCount: 50,
        ),
      ),
    );
    _installTestHooks();
  }

  void _installTestHooks() {
    final CanvasEditorWidget? widget = _canvasEditor;
    if (widget == null) return;
    js_util.setProperty(
      window,
      '__canvasEditorTest',
      js_util.jsify(<String, Object>{
        'resetHistoryText': js_util.allowInterop(() {
          widget.command.executeSetValue(
            IEditorData(
              main: splitText('Teste negrito')
                  .map((String value) => IElement(value: value))
                  .toList(growable: false),
            ),
          );
          widget.command.executeSetRange(0, 7);
        }),
        'mainJson':
            js_util.allowInterop(() => jsonEncode(<Map<String, Object?>>[
                  for (final IElement element in widget.value.data.main)
                    <String, Object?>{
                      'value': element.value,
                      'bold': element.bold,
                    },
                ])),
        'canUndo': js_util.allowInterop(
            () => widget.editor.getDraw().getHistoryManager().isCanUndo()),
        'canRedo': js_util.allowInterop(
            () => widget.editor.getDraw().getHistoryManager().isCanRedo()),
      }),
    );
    js_util.setProperty(window, '__canvasEditorReady', true);
  }

  void onModeChange(String value) {
    mode = value;
    final CanvasEditorWidgetMode widgetMode = value == 'viewer'
        ? CanvasEditorWidgetMode.viewer
        : CanvasEditorWidgetMode.editor;
    _canvasEditor?.setMode(widgetMode);
    status = value == 'viewer'
        ? 'Visualizador: edição e digitação bloqueadas'
        : 'Editor: edição e formatação habilitadas';
  }

  void openDocx(MouseEvent _) {
    _canvasEditor?.openFilePicker();
  }

  List<IElement> _sampleDocument() {
    final List<IElement> elements = <IElement>[
      IElement(
        value: '',
        type: ElementType.title,
        level: TitleLevel.first,
        valueList: <IElement>[
          IElement(value: 'Editor DOCX embutido', size: 26, bold: true),
        ],
      ),
      IElement(
        value:
            '\nEste editor está dentro de um card Limitless UI em uma aplicação AngularDart 8. A página externa e a área do documento possuem ciclos de rolagem independentes.',
      ),
    ];
    for (int index = 1; index <= 28; index++) {
      elements.add(
        IElement(
          value:
              '\nParágrafo $index — conteúdo de demonstração para comprovar que a rolagem permanece dentro do componente, inclusive quando ele é usado em cards, grids ou modais.',
        ),
      );
    }
    return elements;
  }

  @override
  void ngOnDestroy() {
    _canvasEditor?.destroy();
  }
}
