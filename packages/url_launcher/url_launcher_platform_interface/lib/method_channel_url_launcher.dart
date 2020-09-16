// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart' show required;

import 'url_launcher_platform_interface.dart';

const MethodChannel _channel = MethodChannel('plugins.flutter.io/url_launcher');
/// An implementation of [UrlLauncherPlatform] that uses method channels.
class MethodChannelUrlLauncher extends UrlLauncherPlatform {
  /// A list of callbacks to be fired when the platform sends
  /// an interceptUrl call
  List<Function(String)> urlInterceptionListeners = [];

  /// Default constructor. Initializes the MethodCallHandler for receiving
  /// calls from the platform
  MethodChannelUrlLauncher() {
    _channel.setMethodCallHandler((call) {
      switch(call.method) {
        case 'interceptUrl':
          final url = call.arguments as String;
          for (var f in urlInterceptionListeners) {
            f(url);
          }
          break;
        default:
          break;;
      }
      return;
    });
  }

  /// Register a callback for url interception calls
  void registerUrlInterceptionListener(Function(String) f) {
    urlInterceptionListeners.add(f);
  }
  /// Deregister a callback from url interception calls
  void deregisterUrlInterceptionListener(Function(String) f) {
    urlInterceptionListeners.remove(f);
  }

  @override
  Future<bool> canLaunch(String url) {
    return _channel.invokeMethod<bool>(
      'canLaunch',
      <String, Object>{'url': url},
    );
  }

  @override
  Future<void> closeWebView() {
    return _channel.invokeMethod<void>('closeWebView');
  }

  @override
  Future<bool> launch(
      String url, {
        @required bool useSafariVC,
        @required bool useWebView,
        @required bool enableJavaScript,
        @required bool enableDomStorage,
        @required bool universalLinksOnly,
        @required bool interceptStartsWith,
        @required bool interceptContains,
        @required Map<String, String> headers,
        @required String webUrlInterceptionPattern,
        String webOnlyWindowName,
      }) {
    return _channel.invokeMethod<bool>(
      'launch',
      <String, Object>{
        'url': url,
        'useSafariVC': useSafariVC,
        'useWebView': useWebView,
        'enableJavaScript': enableJavaScript,
        'enableDomStorage': enableDomStorage,
        'universalLinksOnly': universalLinksOnly,
        'interceptStartsWith': interceptStartsWith,
        'interceptContains': interceptContains,
        'webUrlInterceptionPattern': webUrlInterceptionPattern,
        'headers': headers,
      },
    );
  }
}
