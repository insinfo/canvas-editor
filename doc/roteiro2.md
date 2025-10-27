Roteiro Detalhado para Tradução de TypeScript para Dart puro (Web)

Este roteiro é focado em uma migração 1-para-1 sempre que possível.
Este roteiro deve ser atualizado para cada etapa concluida 
sempre em cada etapa utiliza dart analyze para checar os problemas de sintaxe e corrigir 
tambem utiliza webdev build  para ver se compila

Passo 0: Configuração do Projeto
Crie um projeto Dart para Web: Use o comando dart create -t web C:\MyDartProjects\canvas-editor-port.
ja foi criado C:\MyDartProjects\canvas-editor-port\lib\src 
e ja tem varios arquivos criados so faltando a implementação
Entenda o dart:html: Esta é a biblioteca principal. Ela fornece tipos e funções para interagir com o DOM. As correspondências são diretas:
HTMLDivElement -> DivElement
HTMLCanvasElement -> CanvasElement
CanvasRenderingContext2D -> CanvasRenderingContext2D
document.body -> document.body
element.addEventListener('click', ...) -> element.onClick.listen(...)
Passo 1: Tradução dos Modelos de Dados (Interfaces -> Classes)
Crie a pasta lib/src/models.
Converta todas as interfaces TypeScript (IElement, IRange, IDialogData, etc.) para classes Dart. Use construtores nomeados e parâmetros anuláveis (?). Isso é praticamente uma tradução de sintaxe.
export interface IElement { ... } -> class Element { ... }
value?: string -> String? value
options?: { label: string; value: string }[] -> List<Map<String, String>>? options
Passo 2: Traduzir a Lógica de Renderização (Classe Draw)
Crie o arquivo lib/src/core/draw/draw.dart.
Traduza a classe Draw. O construtor receberá um HtmlElement.
Os métodos que criam elementos DOM (_createPage, _wrapContainer) serão traduzidos usando os construtores do dart:html (ex: DivElement(), CanvasElement()).
O método principal render() terá sua lógica interna traduzida. As chamadas à API do Canvas são quase idênticas:
ctx.fillText(...) -> ctx.fillText(...)
ctx.fillRect(...) -> ctx.fillRect(...)
ctx.measureText(...) -> ctx.measureText(...)
ctx.font = '...' -> ctx.font = '...'
A lógica de paginação, quebra de linha e cálculo de layout (computeRowList) pode ser traduzida com poucas alterações, pois a medição de texto (measureText) funciona da mesma forma.
Passo 3: Traduzir o Gerenciamento de Eventos (Classe CanvasEvent)
Crie o arquivo lib/src/core/event/canvas_event.dart.
Traduza a classe CanvasEvent.
Substitua addEventListener pelo sistema de Stream do Dart:
pageContainer.addEventListener('mousedown', ...) -> pageContainer.onMouseDown.listen(...)
agentDom.onkeydown = ... -> agentDom.onKeyDown.listen(...)
A lógica interna dos manipuladores de eventos (mousedown, mousemove, keydown, etc.) pode ser traduzida diretamente. A técnica do <textarea> oculto (TextAreaElement em Dart) funcionará exatamente da mesma forma.
Passo 4: Traduzir o Restante do Core
Position.ts e RangeManager.ts: A lógica matemática e de manipulação de índices é independente de linguagem. A tradução será direta.
Command.ts e CommandAdapt.ts: A estrutura de classes e a delegação de métodos são traduzidas diretamente.
ContextMenu.ts, Dialog.ts, etc.: A lógica de criação e manipulação de elementos HTML para a UI é portada usando dart:html.
Tradução para Dart (MVP - Mínimo Produto Viável)
Aqui estão as partes essenciais traduzidas para Dart Web, focando em seus requisitos para um MVP funcional.
1. Modelo de Dados (lib/src/models/element.dart)
code
Dart
// lib/src/models/element.dart

// Para simplificar, não usaremos enum aqui, mas strings como no JS.
typedef ElementType = String;

class Element {
  String value;
  ElementType? type;
  double? size;
  bool? bold;
  String? color;
  String? highlight;
  bool? italic;
  bool? underline;
  bool? strikeout;
  String? rowFlex;
  
  // Construtor
  Element({
    required this.value,
    this.type,
    this.size,
    this.bold,
    this.color,
    this.highlight,
    this.italic,
    this.underline,
    this.strikeout,
    this.rowFlex
  });

  // Método de clonagem para manter a imutabilidade quando necessário
  Element copyWith({
    String? value,
    ElementType? type,
    double? size,
    bool? bold,
    String? color,
  }) {
    return Element(
      value: value ?? this.value,
      type: type ?? this.type,
      size: size ?? this.size,
      bold: bold ?? this.bold,
      color: color ?? this.color,
    );
  }
}

class EditorRange {
  int startIndex;
  int endIndex;

  EditorRange({required this.startIndex, required this.endIndex});

  bool get isCollapsed => startIndex == endIndex;
}
2. Core de Renderização com Paginação (lib/src/core/draw/draw.dart)
Esta classe é uma tradução direta da Draw.ts, focada na renderização, paginação e seleção.
code
Dart
// lib/src/core/draw/draw.dart
import 'dart:html';
import '../../models/element.dart';

const ZERO = '\u200B';

class Draw {
  DivElement container;
  DivElement pageContainer;
  List<CanvasElement> pageList = [];
  List<CanvasRenderingContext2D> ctxList = [];

  List<Element> elementList;
  EditorRange range;

  // Simplificação das opções para o MVP
  double pageHeight = 1123;
  double pageWidth = 794;
  double pageGap = 20;
  List<double> margins = [100, 120, 100, 120];
  String defaultFont = 'Microsoft YaHei';
  double defaultSize = 16;

  Draw(this.container, this.elementList, this.range)
      : pageContainer = DivElement() {
    container.style.position = 'relative';
    container.style.width = '${pageWidth}px';
    container.append(pageContainer);
    _createPage(0);
  }

  void _createPage(int pageNo) {
    final canvas = CanvasElement()
      ..style.width = '${pageWidth}px'
      ..style.height = '${pageHeight}px'
      ..style.display = 'block'
      ..style.backgroundColor = '#ffffff'
      ..style.marginBottom = '${pageGap}px'
      ..dataset['index'] = pageNo.toString();
    
    final dpr = window.devicePixelRatio;
    canvas.width = (pageWidth * dpr).toInt();
    canvas.height = (pageHeight * dpr).toInt();
    
    pageContainer.append(canvas);
    pageList.add(canvas);
    
    final ctx = canvas.context2D;
    ctx.scale(dpr, dpr);
    ctxList.add(ctx);
  }

  String getElementFont(Element element) {
    final font = element.font ?? defaultFont;
    final size = element.size ?? defaultSize;
    final bold = (element.bold ?? false) ? 'bold ' : '';
    final italic = (element.italic ?? false) ? 'italic ' : '';
    return '$italic$bold${size}px $font';
  }
  
  // O método de renderização principal
  void render() {
    // Limpa todas as páginas
    for (int i = 0; i < ctxList.length; i++) {
        ctxList[i].clearRect(0, 0, pageList[i].width!, pageList[i].height!);
    }

    double currentX = margins[3];
    double currentY = margins[0];
    double lineHeight = 0;
    int pageNo = 0;

    // Garante que existe pelo menos uma página
    if (pageList.isEmpty) {
      _createPage(0);
    }
    var ctx = ctxList[pageNo];

    for (int i = 0; i < elementList.length; i++) {
      final element = elementList[i];

      if (element.value == ZERO) {
        // Quebra de parágrafo
        ctx.font = getElementFont(element);
        final textMetrics = ctx.measureText(" "); // Mede um espaço para altura da linha
        lineHeight = (element.size ?? defaultSize) * 1.2; // Simplificação da altura da linha

        currentX = margins[3];
        currentY += lineHeight;
        lineHeight = 0;
      } else {
        // Renderiza o texto
        ctx.font = getElementFont(element);
        final textMetrics = ctx.measureText(element.value);
        final textWidth = textMetrics.width!;
        final textHeight = (element.size ?? defaultSize) * 1.2;

        lineHeight = (lineHeight > textHeight) ? lineHeight : textHeight;

        // Quebra de linha (word wrap)
        if (currentX + textWidth > pageWidth - margins[1]) {
            currentX = margins[3];
            currentY += lineHeight;
            lineHeight = textHeight;
        }

        // Paginação
        if (currentY + lineHeight > pageHeight - margins[2]) {
            pageNo++;
            if (pageNo >= pageList.length) {
              _createPage(pageNo);
            }
            ctx = ctxList[pageNo];
            currentX = margins[3];
            currentY = margins[0];
        }

        // Desenha a seleção
        if (i >= range.startIndex && i < range.endIndex) {
            ctx.fillStyle = 'rgba(174, 203, 250, 0.6)'; // rangeColor com alpha
            ctx.fillRect(currentX, currentY, textWidth, lineHeight);
        }
        
        // Desenha o texto
        ctx.fillStyle = element.color ?? '#000000';
        ctx.fillText(element.value, currentX, currentY + (element.size ?? defaultSize));

        currentX += textWidth;
      }
    }
    // Lógica para remover páginas extras, se o conteúdo diminuir
  }
}
3. Gerenciador de Eventos e Lógica de Edição (lib/src/core/event/canvas_event.dart e web/main.dart)
Esta é a tradução da lógica de manipulação de input, incluindo o textarea oculto.
code
Dart
// lib/src/core/event/canvas_event.dart
import 'dart:html';
import '../../models/element.dart';
import '../draw/draw.dart';

class CanvasEvent {
  final Draw draw;
  final TextAreaElement agent; // O textarea oculto

  CanvasEvent(this.draw) : agent = TextAreaElement() {
    _setupAgent();
    _addListeners();
  }

  void _setupAgent() {
    agent.style
      ..position = 'absolute'
      ..left = '-9999px' // Esconde fora da tela
      ..opacity = '0';
    draw.container.append(agent);
  }

  void _addListeners() {
    draw.pageContainer.onMouseDown.listen(_handleMouseDown);
    draw.pageContainer.onMouseMove.listen(_handleMouseMove);
    window.onMouseUp.listen(_handleMouseUp); // Escuta no window para não perder o evento

    agent.onKeyDown.listen(_handleKeyDown);
    agent.onInput.listen(_handleInput);
  }

  void _handleMouseDown(MouseEvent evt) {
    // Lógica de posicionar o cursor e iniciar a seleção...
    // Simplificação: Foca no agente para capturar teclado
    agent.focus();
    
    // Simulação de posicionamento do cursor (precisa da lógica de Position.ts)
    // Por enquanto, vamos definir a seleção para o final
    final index = draw.elementList.length -1;
    draw.range.startIndex = index;
    draw.range.endIndex = index;
    draw.render();
  }
  
  void _handleMouseMove(MouseEvent evt) {
    // Lógica de arrastar para selecionar...
  }
  
  void _handleMouseUp(MouseEvent evt) {
    // Lógica para finalizar a seleção...
  }

  void _handleKeyDown(KeyboardEvent evt) {
    final range = draw.range;
    bool needsRender = false;

    // Lógica de Backspace
    if (evt.key == 'Backspace') {
      evt.preventDefault();
      if (range.isCollapsed) {
        if (range.startIndex > 0) {
          draw.elementList.removeAt(range.startIndex - 1);
          range.startIndex--;
          range.endIndex--;
          needsRender = true;
        }
      } else {
        draw.elementList.removeRange(range.startIndex, range.endIndex);
        range.endIndex = range.startIndex;
        needsRender = true;
      }
    }
    // Lógica de Delete
    else if (evt.key == 'Delete') {
       evt.preventDefault();
       if (range.isCollapsed) {
        if (range.startIndex < draw.elementList.length) {
          draw.elementList.removeAt(range.startIndex);
          needsRender = true;
        }
      } else {
        draw.elementList.removeRange(range.startIndex, range.endIndex);
        range.endIndex = range.startIndex;
        needsRender = true;
      }
    }
    // Lógica de Enter
    else if (evt.key == 'Enter') {
      evt.preventDefault();
      draw.elementList.insert(range.startIndex, Element(value: ZERO));
      range.startIndex++;
      range.endIndex++;
      needsRender = true;
    }
    // Lógica de Negrito
    else if ((evt.ctrlKey || evt.metaKey) && evt.key == 'b') {
        evt.preventDefault();
        if(!range.isCollapsed) {
            for(int i = range.startIndex; i < range.endIndex; i++) {
                final currentBold = draw.elementList[i].bold ?? false;
                draw.elementList[i].bold = !currentBold;
            }
            needsRender = true;
        }
    }

    if (needsRender) {
      draw.render();
    }
  }

  void _handleInput(Event evt) {
    final inputEvent = evt as InputEvent;
    final data = inputEvent.data;
    if (data != null && data.isNotEmpty) {
        draw.elementList.insert(draw.range.startIndex, Element(value: data));
        draw.range.startIndex++;
        draw.range.endIndex++;
        draw.render();
    }
    // Limpa o textarea para o próximo input
    agent.value = '';
  }
}

// Arquivo principal web/main.dart
void main() {
  final container = querySelector('#editor') as DivElement?;
  if (container == null) return;
  
  // Dados iniciais
  final elements = [
    Element(value: 'Olá'),
    Element(value: ' '),
    Element(value: 'Mundo'),
    Element(value: '\u200B'), // Quebra de parágrafo
  ];
  final range = EditorRange(startIndex: 0, endIndex: 0);
  
  // Inicia o editor
  final draw = Draw(container, elements, range);
  final canvasEvent = CanvasEvent(draw);

  // Renderiza pela primeira vez
  draw.render();
}
Como Usar este MVP:
Crie um projeto web com dart create -t web nome_do_projeto.
Crie os arquivos Dart dentro da pasta lib/src conforme as estruturas acima.
Substitua o conteúdo de web/main.dart com o código do main acima.
No arquivo web/index.html, crie o container do editor: <div id="editor"></div>.
Execute o projeto com dart run.
Este código MVP implementa os requisitos essenciais que você pediu de forma muito mais fiel à arquitetura original. A partir daqui, você pode seguir o roteiro e traduzir as outras classes (Position, Command, etc.) para adicionar funcionalidades mais complexas, como a seleção precisa com o mouse, desfazer/refazer e outros elementos.