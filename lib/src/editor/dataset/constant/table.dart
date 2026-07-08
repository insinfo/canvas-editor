import '../../interface/common.dart';
import '../../interface/table/table.dart';

final ITableOption defaultTableOption = ITableOption(
	// Margem de célula padrão do Word (sem tblCellMar): 0 em cima/baixo (o
	// bottom:5 anterior inflava cada linha em 5px vs o Word) e ~108 twips
	// (0,1") nas laterais.
	tdPadding: IPadding(top: 0, right: 5, bottom: 0, left: 5),
	defaultTrMinHeight: 42,
	defaultColMinWidth: 40,
	defaultBorderColor: '#000000',
	overflow: true,
);