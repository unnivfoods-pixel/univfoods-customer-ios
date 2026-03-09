import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";
import { getStorage } from "firebase/storage";
import { getAnalytics } from "firebase/analytics";

const firebaseConfig = {
    apiKey: "AIzaSyDt6W42XHG09_e2PpOH5loSxkjRY43EhQY",
    authDomain: "curypoint-f0274.firebaseapp.com",
    projectId: "curypoint-f0274",
    storageBucket: "curypoint-f0274.firebasestorage.app",
    messagingSenderId: "106238487896",
    appId: "1:106238487896:web:16434b08e4b8c2b3a4092d"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);
export const storage = getStorage(app);
export const analytics = getAnalytics(app);
