class UrlNormalizer {
  UrlNormalizer._();

  static String normalize(String input) {
    var value = input.trim();
    if (value.isEmpty) {
      return value;
    }

    value = value.replaceAll(RegExp(r'/+$'), '');

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.trim().isEmpty) {
      return value;
    }

    return uri
        .replace(path: uri.path.replaceAll(RegExp(r'/+$'), ''))
        .toString();
  }

  static bool isProbablyValid(String input) {
    final value = normalize(input);
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.trim().isNotEmpty;
  }
}
