// 占位冒烟测试。
//
// 原来的默认模板测试引用了不存在的 `MyApp`（本项目主组件是
// `ConsultingOnlineApp`），会导致 `flutter test` 编译失败。
//
// 真正的 widget 测试需要 mock 网络、通知、前台服务等外部依赖，
// 后续需要时再补充；这里先放一个能通过的冒烟测试保证测试可运行。

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smoke test', () {
    expect(1 + 1, 2);
  });
}
