String formatPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11) {
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
  }
  if (digits.length == 10) {
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
  }
  return raw;
}

String formatPhoneInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length <= 2) return '(${digits}';
  if (digits.length <= 6) return '(${digits.substring(0, 2)}) ${digits.substring(2)}';
  final isCell = digits.length > 10 || (digits.length > 6 && digits[2] == '9');
  if (isCell) {
    if (digits.length <= 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, digits.length > 7 ? 7 : digits.length)}${digits.length > 7 ? '-${digits.substring(7)}' : ''}';
    }
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7, 11)}';
  } else {
    if (digits.length <= 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, digits.length > 6 ? 6 : digits.length)}${digits.length > 6 ? '-${digits.substring(6)}' : ''}';
    }
    return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6, 10)}';
  }
}
