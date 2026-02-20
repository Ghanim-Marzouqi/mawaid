import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

import '../services/supabase_service.dart';

/// VAPID public key injected at build time via --dart-define.
const _vapidPublicKey = String.fromEnvironment('VAPID_PUBLIC_KEY');

/// Register for Web Push notifications and store the subscription in the DB.
///
/// This is best-effort — failures are silently ignored so push registration
/// never blocks the user experience.
Future<void> registerPushToken() async {
  try {
    if (_vapidPublicKey.isEmpty) return;

    // Check current permission state.
    final permission = web.Notification.permission;
    if (permission == 'denied') return;

    // Request permission if not yet granted.
    final result = await web.Notification.requestPermission().toDart;
    if (result.toDart != 'granted') return;

    // Register the push service worker.
    await web.window.navigator.serviceWorker
        .register('/push-sw.js'.toJS)
        .toDart;

    // Wait until the SW is active.
    final ready = await web.window.navigator.serviceWorker.ready.toDart;

    // Subscribe to push with the VAPID application server key.
    final applicationServerKey = _urlBase64ToUint8Array(_vapidPublicKey);
    final options = web.PushSubscriptionOptionsInit(
      userVisibleOnly: true,
      applicationServerKey: applicationServerKey,
    );
    final subscription =
        await ready.pushManager.subscribe(options).toDart;

    // Convert subscription to JSON string and persist it.
    final jsonString = _jsStringify(subscription);
    await savePushToken(jsonString);
  } catch (_) {
    // Push registration is best-effort. Don't let it break the app.
  }
}

/// Persist the push subscription JSON to the user's profile.
Future<void> savePushToken(String tokenJson) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;
  await supabase
      .from('profiles')
      .update({'push_token': tokenJson})
      .eq('id', userId);
}

/// Convert a URL-safe base64 string to a Uint8Array for the Push API.
JSUint8Array _urlBase64ToUint8Array(String base64String) {
  // Pad to standard base64.
  final padding = '=' * ((4 - base64String.length % 4) % 4);
  final base64 =
      (base64String + padding).replaceAll('-', '+').replaceAll('_', '/');

  final rawData = _atob(base64);
  final bytes = Uint8List(rawData.length);
  for (var i = 0; i < rawData.length; i++) {
    bytes[i] = rawData.codeUnitAt(i);
  }
  return bytes.toJS;
}

/// Call window.atob via JS interop.
String _atob(String encoded) {
  return _jsAtob(encoded.toJS).toDart;
}

@JS('atob')
external JSString _jsAtob(JSString encoded);

/// Call JSON.stringify on a JS object.
String _jsStringify(JSAny? obj) {
  return _jsJsonStringify(obj).toDart;
}

@JS('JSON.stringify')
external JSString _jsJsonStringify(JSAny? obj);
