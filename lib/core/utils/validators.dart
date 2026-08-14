class Validators {
  Validators._();

  static String? required(String? value, {String? message}) {
    if (value == null || value.trim().isEmpty) {
      return message ?? '此字段不能为空';
    }
    return null;
  }

  static String? email(String? value, {String? message}) {
    if (value == null || value.trim().isEmpty) {
      return message ?? '请输入邮箱';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return message ?? '请输入有效的邮箱地址';
    }
    return null;
  }

  static String? password(String? value, {String? message, int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return message ?? '请输入密码';
    }
    if (value.length < minLength) {
      return message ?? '密码长度至少为$minLength位';
    }
    return null;
  }

  static String? minLength(String? value, int min, {String? message}) {
    if (value == null || value.length < min) {
      return message ?? '最少需要$min个字符';
    }
    return null;
  }

  static String? maxLength(String? value, int max, {String? message}) {
    if (value != null && value.length > max) {
      return message ?? '最多允许$max个字符';
    }
    return null;
  }

  static String? url(String? value, {String? message}) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final urlRegex = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
    );
    if (!urlRegex.hasMatch(value)) {
      return message ?? '请输入有效的URL';
    }
    return null;
  }

  static String? phone(String? value, {String? message}) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return message ?? '请输入有效的手机号码';
    }
    return null;
  }

  static String? compose(String? value, List<String? Function(String?)> validators) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) {
        return error;
      }
    }
    return null;
  }
}
