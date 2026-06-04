importScripts('https://www.gstatic.com/firebasejs/11.1.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.1.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCg7lyjfVIiOFjQOxeaMwLarWgSFiiCV2k',
  authDomain: 'poketeamdex.firebaseapp.com',
  projectId: 'poketeamdex',
  storageBucket: 'poketeamdex.firebasestorage.app',
  messagingSenderId: '854467000036',
  appId: '1:854467000036:web:6b391b2b169c1611565ef1',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'PokeTeamDex';
  const body  = payload.notification?.body  ?? '';
  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
  });
});
