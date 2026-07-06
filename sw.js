const CACHE = 'edu-pass-v15';

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(['./index.html','./icon.svg','./manifest.json']))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// 네비게이션(페이지 로드)은 항상 네트워크 우선 → 최신 index.html 보장
self.addEventListener('fetch', e => {
  if (e.request.mode === 'navigate') {
    e.respondWith(
      fetch(e.request, {cache: 'reload'})
        .then(r => {
          caches.open(CACHE).then(c => c.put(e.request, r.clone()));
          return r;
        })
        .catch(() => caches.match('./index.html'))
    );
  } else {
    e.respondWith(
      caches.match(e.request).then(r => r || fetch(e.request))
    );
  }
});

// 푸시 알림
self.addEventListener('push', e => {
  const options = {
    body: e.data ? e.data.text() : '교육 신청 기간입니다. 확인해주세요!',
    icon: './icon.svg',
    badge: './icon.svg',
    vibrate: [200, 100, 200],
    data: {url: self.location.origin}
  };
  e.waitUntil(self.registration.showNotification('MND EDU-PASS', options));
});

// 알림 클릭 시 앱 열기
self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(
    clients.matchAll({type:'window'}).then(list => {
      for (var i=0;i<list.length;i++){
        if (list[i].url===e.notification.data.url && 'focus' in list[i]) return list[i].focus();
      }
      if (clients.openWindow) return clients.openWindow(e.notification.data.url);
    })
  );
});
