self.addEventListener('install', (e) => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
    const options = {
        body: '국방부 교육 수강신청 기간입니다. 잊지 말고 신청하세요!',
        icon: 'https://cdn-icons-png.flaticon.com/512/869/869869.png',
        badge: 'https://cdn-icons-png.flaticon.com/512/869/869869.png'
    };
    event.waitUntil(self.registration.showNotification('ROKA EDU-PASS', options));
});
