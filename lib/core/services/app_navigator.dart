import 'package:flutter/material.dart';

/// Global navigator key allowing headless/background service handlers
/// to push diversion screens (PDF guide, reality check) from anywhere in the app.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
