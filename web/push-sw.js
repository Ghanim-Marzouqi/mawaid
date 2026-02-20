// Push notification service worker for مواعيد (Mawa'id)

self.addEventListener('push', (event) => {
  let data = { title: 'مواعيد', body: '' };
  if (event.data) {
    try {
      data = event.data.json();
    } catch (_) {
      data.body = event.data.text();
    }
  }

  const options = {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    dir: 'rtl',
    data: data.data || {},
  };

  event.waitUntil(self.registration.showNotification(data.title || 'مواعيد', options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const appointmentId = event.notification.data?.appointmentId;
  // Build a path to the appointment detail — the app router will resolve the
  // correct role prefix (coordinator / manager) once the app is focused.
  const urlPath = appointmentId ? `/appointment/${appointmentId}` : '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // If the app is already open, focus it and navigate.
      for (const client of windowClients) {
        if (new URL(client.url).origin === self.location.origin) {
          client.focus();
          client.postMessage({ type: 'NOTIFICATION_CLICK', path: urlPath });
          return;
        }
      }
      // Otherwise open a new window.
      return clients.openWindow(urlPath);
    }),
  );
});
