// create_structure.dart
import 'dart:io';
import 'package:path/path.dart' as p;

String toSnakeCase(String pascalCase) {
  return pascalCase
      .splitMapJoin(
        RegExp(r'[A-Z]'),
        onMatch: (m) => '_${m.group(0)!.toLowerCase()}',
        onNonMatch: (n) => n,
      )
      .replaceFirst(RegExp(r'^_'), '');
}

void main() {
  // ATENÇÃO: Adicione aqui os caminhos relativos de todos os seus 218 arquivos .ts
  // Exemplo baseado nos arquivos que você forneceu.

  final tsFilePaths = [
    r'C:\MyTsProjects\canvas-editor\src\components\dialog\Dialog.ts',
    r'C:\MyTsProjects\canvas-editor\src\components\signature\Signature.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\actuator\Actuator.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\actuator\handlers\positionContextChange.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\command\Command.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\command\CommandAdapt.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\contextmenu\ContextMenu.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\contextmenu\menus\controlMenus.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\contextmenu\menus\globalMenus.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\contextmenu\menus\hyperlinkMenus.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\contextmenu\menus\imageMenus.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\contextmenu\menus\tableMenus.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\cursor\Cursor.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\cursor\CursorAgent.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\Draw.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\control\Control.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\control\checkbox\CheckboxControl.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\control\date\DateControl.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\control\interactive\ControlSearch.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\control\number\NumberControl.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\control\radio\RadioControl.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\control\richtext\Border.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\control\select\SelectControl.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\control\text\TextControl.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\frame\Background.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\frame\Badge.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\frame\Footer.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\frame\Header.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\frame\LineNumber.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\frame\Margin.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\frame\PageBorder.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\frame\PageNumber.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\frame\Placeholder.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\frame\Watermark.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\interactive\Area.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\interactive\Group.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\interactive\Search.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\CheckboxParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\HyperlinkParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\ImageParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\LineBreakParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\ListParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\PageBreakParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\RadioParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\SeparatorParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\SubscriptParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\SuperscriptParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\TextParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\block\BlockParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\block\modules\BaseBlock.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\block\modules\IFrameBlock.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\block\modules\VideoBlock.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\date\DateParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\date\DatePicker.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\latex\LaTexParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\latex\utils\LaTexUtils.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\latex\utils\hershey.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\latex\utils\symbols.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\previewer\Previewer.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\table\TableOperate.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\table\TableParticle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\particle\table\TableTool.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\richtext\AbstractRichText.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\richtext\Highlight.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\richtext\Strikeout.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\draw\richtext\Underline.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\CanvasEvent.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\GlobalEvent.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\eventbus\EventBus.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\click.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\composition.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\copy.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\cut.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\drag.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\drop.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\input.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\keydown\backspace.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\keydown\delete.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\keydown\enter.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\keydown\index.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\keydown\left.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\keydown\right.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\keydown\tab.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\keydown\updown.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\mousedown.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\mouseleave.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\mousemove.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\mouseup.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\event\handlers\paste.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\history\HistoryManager.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\i18n\I18n.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\listener\Listener.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\observer\ImageObserver.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\observer\MouseObserver.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\observer\ScrollObserver.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\observer\SelectionObserver.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\override\Override.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\plugin\Plugin.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\position\Position.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\range\RangeManager.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\register\Register.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\shortcut\Shortcut.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\shortcut\keys\listKeys.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\shortcut\keys\richtextKeys.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\shortcut\keys\titleKeys.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\worker\WorkerManager.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\worker\works\catalog.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\worker\works\group.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\worker\works\value.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\worker\works\wordCount.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\zone\Zone.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\core\zone\ZoneTip.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Background.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Badge.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Checkbox.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Common.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\ContextMenu.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Control.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Cursor.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Editor.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Element.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Footer.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Group.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Header.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\LineBreak.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\LineNumber.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\List.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\PageBorder.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\PageBreak.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\PageNumber.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Placeholder.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Radio.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Regular.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Separator.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Shortcut.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Table.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Title.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Watermark.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\constant\Zone.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Area.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Background.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Block.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Common.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Control.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Editor.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Element.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\ElementStyle.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Event.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\KeyMap.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\LineNumber.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\List.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Observer.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Row.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Text.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Title.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\VerticalAlign.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\Watermark.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\table\Table.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\dataset\enum\table\TableTool.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\index.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Area.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Background.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Badge.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Block.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Catalog.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Checkbox.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Command.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Common.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Control.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Cursor.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Draw.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Editor.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Element.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Event.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\EventBus.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Footer.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Group.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Header.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\LineBreak.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\LineNumber.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Listener.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Margin.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\PageBorder.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\PageBreak.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\PageNumber.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Placeholder.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Plugin.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Position.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Previewer.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Radio.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Range.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Row.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Search.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Separator.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Text.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Title.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Watermark.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\Zone.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\contextmenu\ContextMenu.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\i18n\I18n.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\shortcut\Shortcut.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\table\Colgroup.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\table\Table.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\table\Td.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\interface\table\Tr.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\utils\clipboard.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\utils\element.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\utils\hotkey.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\utils\index.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\utils\option.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\utils\print.ts',
    r'C:\MyTsProjects\canvas-editor\src\editor\utils\ua.ts',
    r'C:\MyTsProjects\canvas-editor\src\main.ts',
    r'C:\MyTsProjects\canvas-editor\src\mock.ts',
    r'C:\MyTsProjects\canvas-editor\src\plugins\copy\index.ts',
    r'C:\MyTsProjects\canvas-editor\src\plugins\markdown\index.ts',
    r'C:\MyTsProjects\canvas-editor\src\utils\index.ts',
    r'C:\MyTsProjects\canvas-editor\src\utils\prism.ts',
  ];

  final String projectRoot =
      r'C:\MyTsProjects\canvas-editor\dart_editor\lib\src';
  final String originalProjectRoot = r'C:\MyTsProjects\canvas-editor';

  for (final tsPath in tsFilePaths) {
    // Normaliza o caminho para usar barras "/" e remove a raiz 'src'
    final relativeTsPath = tsPath
        .replaceFirst(r'C:\MyTsProjects\canvas-editor\src\', '')
        .replaceAll(r'\', '/');

    // Extrai o diretório e o nome base do arquivo
    final dir = p.dirname(relativeTsPath);
    final base = p.basenameWithoutExtension(relativeTsPath);

    // Converte o nome base para snake_case
    final snakeBase = toSnakeCase(base);

    // Constrói o novo nome do arquivo Dart
    final dartFile = '$snakeBase.dart';
    final dartRelative = p.join(dir, dartFile);

    // Constrói o caminho de destino em Dart
    final dartPath = p.join(projectRoot, dartRelative);

    // Cria o arquivo e os diretórios
    final file = File(dartPath);
    file.createSync(recursive: true);

    // Constrói o caminho original completo para o comentário
    final originalFullPath = p.join(originalProjectRoot, tsPath);

    // Escreve o conteúdo no arquivo
    file.writeAsStringSync(
        '// TODO: Translate from ${originalFullPath.replaceAll(r'\', r'\\')}');

    print('Created: $dartPath');
  }

  print('\nProject structure created successfully!');
}
