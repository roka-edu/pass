self.addEventListener('install', (e) => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

// 푸시 알림 수신 대기
self.addEventListener('push', (event) => {
    const options = {
        body: event.data ? event.data.text() : '교육 신청 기간입니다. 확인해주세요!',
        icon: 'data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><rect width=%22100%22 height=%22100%22 fill=%22%23FF9800%22/><text y=%22.9em%22 x=%225%22 font-size=%2280%22 fill=%22white%22>☀️</text></svg>',
        badge: '☀️'
    };
    event.waitUntil(self.registration.showNotification('ROKA EDU-PASS', options));
});
