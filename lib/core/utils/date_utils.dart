import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('HH:mm').format(dateTime.toLocal());
  }

  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime.toLocal());
  }

  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final local = dateTime.toLocal();

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '今天';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return '昨天';
    }

    if (now.difference(local).inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[local.weekday - 1];
    }

    if (local.year == now.year) {
      return DateFormat('MM-dd').format(local);
    }

    return DateFormat('yyyy-MM-dd').format(local);
  }

  static String formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final diff = now.difference(local);

    if (diff.inSeconds < 60) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return formatDate(dateTime);
    }
  }

  static String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}小时${duration.inMinutes % 60}分钟';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}分钟';
    } else {
      return '${duration.inSeconds}秒';
    }
  }

  static String formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final local = dateTime.toLocal();

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat('HH:mm').format(local);
    }

    return '${formatDate(local)} ${DateFormat('HH:mm').format(local)}';
  }
}
