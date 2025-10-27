import '../../interface/editor.dart';

const String editorComponent = 'editor-component';
const String editorPrefix = 'ce';
const String editorClipboard = '$editorPrefix-clipboard';

final IModeRule defaultModeRuleOption = IModeRule(
	print: IPrintModeRule(imagePreviewerDisabled: false),
	readonly: IReadonlyModeRule(imagePreviewerDisabled: false),
	form: IFormModeRule(controlDeletableDisabled: false),
);