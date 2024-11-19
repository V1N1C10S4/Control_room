// Import Firebase scripts
importScripts('https://www.gstatic.com/firebasejs/9.21.0/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/9.21.0/firebase-messaging.js');

// Firebase configuration
firebase.initializeApp({
  apiKey: "AIzaSyCJycpIn0CzrANDmkUj2I2xok6BhMk-y8g",
  authDomain: "appenitaxiusuarios.firebaseapp.com",
  projectId: "appenitaxiusuarios",
  messagingSenderId: "841314423983",
  appId: "1:841314423983:web:67f4c5d20bd10e4373705a",
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('Received background message: ', payload);

  // Customize the notification
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: 'icons/Icon-192.png',
  };

  // Show notification
  self.registration.showNotification(notificationTitle, notificationOptions);
});