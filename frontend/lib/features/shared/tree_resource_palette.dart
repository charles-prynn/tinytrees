import 'package:flutter/material.dart';

const Map<String, Color?> treeResourceTintColors = {
  'tree': null,
  'oak_tree': Color(0xFFD7A45F),
  'willow_tree': Color(0xFF81C784),
  'maple_tree': Color(0xFFE67E45),
  'yew_tree': Color(0xFF4E7A4A),
  'magic_tree': Color(0xFF7CC7D9),
};

const Map<String, String> logItemResourceKeys = {
  'logs': 'tree',
  'wood': 'tree',
  'oak_logs': 'oak_tree',
  'willow_logs': 'willow_tree',
  'maple_logs': 'maple_tree',
  'yew_logs': 'yew_tree',
  'magic_logs': 'magic_tree',
};

Color? logItemTintColor(String itemKey) {
  final resourceKey = logItemResourceKeys[itemKey];
  if (resourceKey == null) {
    return null;
  }
  return treeResourceTintColors[resourceKey];
}
