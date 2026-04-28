import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treescape/features/shared/tree_resource_palette.dart';

void main() {
  test('log items map to the same tint colors as their tree resources', () {
    expect(logItemTintColor('logs'), isNull);
    expect(logItemTintColor('wood'), isNull);
    expect(logItemTintColor('oak_logs'), const Color(0xFFD7A45F));
    expect(logItemTintColor('willow_logs'), const Color(0xFF81C784));
    expect(logItemTintColor('maple_logs'), const Color(0xFFE67E45));
    expect(logItemTintColor('yew_logs'), const Color(0xFF4E7A4A));
    expect(logItemTintColor('magic_logs'), const Color(0xFF7CC7D9));
    expect(logItemTintColor('unknown_item'), isNull);
  });
}
