// Web Push registration helper.
// In a full implementation, this would use the browser's Notification API
// and service worker to register for push notifications.
// For now, this is a placeholder that can be wired up when VAPID keys are configured.

import '../services/supabase_service.dart';

Future<void> registerPushToken() async {
  // Web Push requires:
  // 1. Notification.requestPermission()
  // 2. ServiceWorkerRegistration.pushManager.subscribe()
  // 3. Store the subscription JSON in profiles.push_token
  //
  // This is a browser API and requires dart:js_interop for Flutter web.
  // Implementation deferred until VAPID keys are configured.
}

Future<void> savePushToken(String tokenJson) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;
  await supabase
      .from('profiles')
      .update({'push_token': tokenJson})
      .eq('id', userId);
}
