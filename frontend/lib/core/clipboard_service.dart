import 'dart:async';
import 'package:flutter/services.dart';

class ClipboardService {
  static Future<bool> hasStrings() async {
    try {
      return await Clipboard.hasStrings();
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getData() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setData(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } on PlatformException {
    } catch (_) {
    }
  }
}
