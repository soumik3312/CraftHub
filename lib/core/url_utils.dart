final RegExp _schemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');

String normalizeWebUrl(String raw, {String? defaultHost}) {
  var value = raw.trim();
  if (value.isEmpty) return '';

  value = value.replaceAll(RegExp(r'\s+'), '');
  if (!_schemePattern.hasMatch(value)) {
    final slashParts = value.split('/').where((part) => part.isNotEmpty).length;
    if (defaultHost != null && !value.contains('.') && slashParts >= 2) {
      value = '$defaultHost/$value';
    } else if (defaultHost != null && !value.contains('.')) {
      return '';
    }
    value = 'https://$value';
  }

  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return '';
  if (uri.scheme != 'http' && uri.scheme != 'https') return '';
  return uri.toString();
}

Uri? parseWebUrl(String raw, {String? defaultHost}) {
  final normalized = normalizeWebUrl(raw, defaultHost: defaultHost);
  if (normalized.isEmpty) return null;
  return Uri.tryParse(normalized);
}

String normalizeGithubUrl(String raw) {
  return normalizeWebUrl(raw, defaultHost: 'github.com');
}

Uri? parseGithubUrl(String raw) {
  return parseWebUrl(raw, defaultHost: 'github.com');
}
