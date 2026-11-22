bool isAllowedExternalUri(Uri uri) {
  final raw = uri.toString();
  if (raw.contains('\r') || raw.contains('\n') || raw.contains('\u0000')) {
    return false;
  }

  final scheme = uri.scheme.toLowerCase();
  return switch (scheme) {
    'https' || 'http' => uri.hasAuthority && uri.host.trim().isNotEmpty,
    'tel' || 'mailto' => _hasNonEmptyTargetPath(uri.path),
    _ => false,
  };
}

bool _hasNonEmptyTargetPath(String rawPath) {
  if (rawPath.trim().isEmpty) {
    return false;
  }
  try {
    return Uri.decodeComponent(rawPath).trim().isNotEmpty;
  } on ArgumentError {
    return false;
  }
}
