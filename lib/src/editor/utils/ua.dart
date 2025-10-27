import 'dart:html' as html;

bool get isApple => _userAgent.contains('Mac OS X');

bool get isIOS => _userAgent.contains('iPad') || _userAgent.contains('iPhone');

bool get isMobile => RegExp(
      r'Mobile|Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini',
      caseSensitive: false,
    ).hasMatch(_userAgent);

bool get isFirefox => _userAgent.contains('Firefox');

String get _userAgent {
  try {
    return html.window.navigator.userAgent;
  } catch (_) {
    return '';
  }
}
