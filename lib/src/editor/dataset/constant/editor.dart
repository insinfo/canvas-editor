import '../../interface/editor.dart';

const String editorComponent = 'editor-component';
const String editorPrefix = 'ce';
const String editorClipboard = '$editorPrefix-clipboard';

const String EDITOR_COMPONENT = editorComponent;
const String EDITOR_PREFIX = editorPrefix;
const String EDITOR_CLIPBOARD = editorClipboard;

final IModeRule defaultModeRuleOption = IModeRule(
	print: IPrintModeRule(imagePreviewerDisabled: false),
	readonly: IReadonlyModeRule(imagePreviewerDisabled: false),
	form: IFormModeRule(controlDeletableDisabled: false),
);