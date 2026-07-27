import '../../dataset/enum/table/table.dart';

/// Estilo de tabela da galeria (equivalente aos "Estilos de Tabela" do Word).
///
/// O modelo do editor não tem estilos nomeados de tabela; aplicar um estilo
/// grava as propriedades resultantes (bordas da tabela + preenchimento das
/// células + negrito do cabeçalho), como o Word faz ao aplicar um estilo sem
/// vínculo dinâmico.
class ITableStyle {
  const ITableStyle({
    required this.id,
    required this.label,
    required this.borderType,
    this.borderColor,
    this.headerFill,
    this.headerBold = false,
    this.bandFill,
    this.cellFill,
  });

  final String id;
  final String label;

  /// Bordas da tabela (all/external/internal/empty/dash).
  final TableBorder borderType;
  final String? borderColor;

  /// Preenchimento da primeira linha (cabeçalho) e negrito no seu texto.
  final String? headerFill;
  final bool headerBold;

  /// Preenchimento alternado das demais linhas (faixas) e preenchimento base.
  final String? bandFill;
  final String? cellFill;
}

/// Galeria padrão — nomes e aparência espelham os estilos mais usados do Word.
const List<ITableStyle> defaultTableStyleGallery = <ITableStyle>[
  ITableStyle(
    id: 'plain',
    label: 'Tabela simples',
    borderType: TableBorder.empty,
  ),
  ITableStyle(
    id: 'grid',
    label: 'Tabela com grade',
    borderType: TableBorder.all,
    borderColor: '#000000',
  ),
  ITableStyle(
    id: 'grid-light',
    label: 'Tabela com grade clara',
    borderType: TableBorder.all,
    borderColor: '#BFBFBF',
  ),
  ITableStyle(
    id: 'header-gray',
    label: 'Cabeçalho cinza',
    borderType: TableBorder.all,
    borderColor: '#BFBFBF',
    headerFill: '#D9D9D9',
    headerBold: true,
  ),
  ITableStyle(
    id: 'banded-gray',
    label: 'Linhas em faixas (cinza)',
    borderType: TableBorder.all,
    borderColor: '#BFBFBF',
    headerFill: '#D9D9D9',
    headerBold: true,
    bandFill: '#F2F2F2',
  ),
  ITableStyle(
    id: 'accent-blue',
    label: 'Ênfase azul',
    borderType: TableBorder.all,
    borderColor: '#8EAADB',
    headerFill: '#4472C4',
    headerBold: true,
    bandFill: '#D9E2F3',
  ),
  ITableStyle(
    id: 'accent-orange',
    label: 'Ênfase laranja',
    borderType: TableBorder.all,
    borderColor: '#F4B183',
    headerFill: '#ED7D31',
    headerBold: true,
    bandFill: '#FBE5D6',
  ),
  ITableStyle(
    id: 'accent-green',
    label: 'Ênfase verde',
    borderType: TableBorder.all,
    borderColor: '#A9D18E',
    headerFill: '#70AD47',
    headerBold: true,
    bandFill: '#E2F0D9',
  ),
  ITableStyle(
    id: 'lines-only',
    label: 'Somente linhas horizontais',
    borderType: TableBorder.internal,
    borderColor: '#BFBFBF',
    headerFill: '#D9D9D9',
    headerBold: true,
  ),
];
