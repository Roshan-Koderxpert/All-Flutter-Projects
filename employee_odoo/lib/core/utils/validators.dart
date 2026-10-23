class Validators {
  Validators._();

  static String? emailOrMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email or mobile number is required';
    }
    final input = value.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final mobileRegex = RegExp(r'^[0-9]{10,15}$');
    if (!emailRegex.hasMatch(input) && !mobileRegex.hasMatch(input.replaceAll(RegExp(r'[\s\-\+]'), ''))) {
      return 'Enter a valid email or mobile number';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}
