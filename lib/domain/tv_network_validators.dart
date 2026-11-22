/// Pure network, PIN, MAC address, and TV text input validators (Layer 0).
class TvNetworkValidators {
  TvNetworkValidators._();

  static final RegExp _safeIpRegex = RegExp(
    r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$',
  );
  static final RegExp _safePinRegex = RegExp(r'^\d{6}$');
  static final RegExp _safeHexPinRegex = RegExp(r'^[0-9a-fA-F]{4,8}$');
  static final RegExp _safeMacRegex = RegExp(
    r'^([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}$',
  );
  static final RegExp _safeUrlRegex = RegExp(r'^[a-zA-Z0-9:/?&%=._~+#-]+$');
  static final RegExp _safePackageRegex = RegExp(r'^[a-zA-Z0-9._]+$');
  static final RegExp _safeActivityRegex = RegExp(r'^[a-zA-Z0-9._/]+$');

  /// Validates an IPv4 address string.
  static bool isValidIp(String ip) => _safeIpRegex.hasMatch(ip.trim());

  /// True if [ip] belongs to a private RFC-1918 or link-local LAN range (`10.x`, `172.16-31.x`, `192.168.x`, `169.254.x`).
  static bool isPrivateLanIp(String ip) {
    final clean = ip.trim();
    if (!isValidIp(clean)) return false;
    final parts = clean.split('.').map(int.parse).toList();
    if (parts[0] == 10 || parts[0] == 127) return true;
    if (parts[0] == 192 && parts[1] == 168) return true;
    if (parts[0] == 169 && parts[1] == 254) return true;
    if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true;
    return false;
  }

  /// Validates a strict 6-digit numeric PIN.
  static bool isValidSixDigitPin(String pin) =>
      _safePinRegex.hasMatch(pin.trim());

  /// Validates either a 6-digit numeric PIN or a 4..8-char hexadecimal pairing PIN.
  static bool isValidPairingPinCode(String pin) =>
      _safeHexPinRegex.hasMatch(pin.trim());

  /// Normalizes a MAC address string (colon, hyphen, dot, or bare 12-hex) into
  /// uppercase colon-separated `AA:BB:CC:DD:EE:FF`, rejecting invalid, all-zero,
  /// and broadcast (`FF:FF:FF:FF:FF:FF`) addresses.
  static String normalizeMacAddress(String mac) {
    final cleanHex = mac.trim().replaceAll(RegExp(r'[:\-\.\s]'), '').toUpperCase();
    if (cleanHex.length != 12 || !RegExp(r'^[0-9A-F]{12}$').hasMatch(cleanHex)) {
      return '';
    }
    if (cleanHex == '000000000000' || cleanHex == 'FFFFFFFFFFFF') {
      return '';
    }
    final octets = <String>[
      for (var i = 0; i < 12; i += 2) cleanHex.substring(i, i + 2),
    ];
    return octets.join(':');
  }

  /// Validates a standard colon- or hyphen-separated MAC address (`AA:BB:CC:DD:EE:FF`).
  static bool isValidMacAddress(String mac) =>
      _safeMacRegex.hasMatch(mac.trim()) && normalizeMacAddress(mac).isNotEmpty;

  static bool isSafeUrl(String url) => _safeUrlRegex.hasMatch(url);

  static bool isSafePackage(String pkg) => _safePackageRegex.hasMatch(pkg);

  static bool isSafeActivity(String activity) =>
      _safeActivityRegex.hasMatch(activity);

  /// Normalizes Turkish characters to 7-bit ASCII equivalents and escapes spaces
  /// as `%s` so Android's `input text` types cleanly without dropping characters.
  static String normalizeForTvInputText(String rawText) {
    const trMap = <String, String>{
      'ğ': 'g',
      'Ğ': 'G',
      'ü': 'u',
      'Ü': 'U',
      'ş': 's',
      'Ş': 'S',
      'ı': 'i',
      'İ': 'I',
      'ö': 'o',
      'Ö': 'O',
      'ç': 'c',
      'Ç': 'C',
    };
    final buf = StringBuffer();
    for (var i = 0; i < rawText.length; i++) {
      final ch = rawText[i];
      buf.write(trMap[ch] ?? ch);
    }
    return buf
        .toString()
        .replaceAll(RegExp(r'[^a-zA-Z0-9 .,:@/_?!+-]'), '')
        .replaceAll(' ', '%s');
  }
}
