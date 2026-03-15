self.addEventListener('install', (e) => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

// 푸시 알림 수신 대기 및 앱 실행 로직 보강
self.addEventListener('push', (event) => {
    const options = {
        body: event.data ? event.data.text() : '교육 신청 기간입니다. 확인해주세요!',
        icon: 'data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><rect width=%22100%22 height=%22100%22 fill=%22white%22/><text y=%2250%%22 x=%2250%%22 dominant-baseline=%22central%22 text-anchor=%22middle%22 font-size=%2260%22 fill=%22%23FF9800%22>☀️</text></svg>',
        badge: 'data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%2250%%22 x=%2250%%22 dominant-baseline=%22central%22 text-anchor=%22middle%22 font-size=%2260%22 fill=%22%23FF9800%22>☀️</text></svg>',
        vibrate: [200, 100, 200],
        data: {
            url: self.location.origin
        }
    };
    event.waitUntil(self.registration.showNotification('ROKA EDU-PASS', options));
});

// 알림 클릭 시 웹사이트/앱 열기
self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    event.waitUntil(
        clients.matchAll({ type: 'window' }).then(windowClients => {
            for (var i = 0; i < windowClients.length; i++) {
                var client = windowClients[i];
                if (client.url === event.notification.data.url && 'focus' in client) {
                    return client.focus();
                }
            }
            if (clients.openWindow) {
                return clients.openWindow(event.notification.data.url);
            }
        })
    );
});
