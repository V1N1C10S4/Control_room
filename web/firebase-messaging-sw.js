// Import Firebase compat SDKs (ES5 compatible)
importScripts('https://www.gstatic.com/firebasejs/9.21.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.21.0/firebase-messaging-compat.js');

// Inicializar Firebase
firebase.initializeApp({
  apiKey: "AIzaSyCJycpIn0CzrANDmkUj2I2xok6BhMk-y8g",
  authDomain: "appenitaxiusuarios.firebaseapp.com",
  projectId: "appenitaxiusuarios",
  messagingSenderId: "841314423983",
  appId: "1:841314423983:web:67f4c5d20bd10e4373705a",
});

// Inicializar messaging
const messaging = firebase.messaging();

// Manejar mensajes en background
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Mensaje recibido en background:', payload);

  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: 'icons/Icon-192.png',
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});