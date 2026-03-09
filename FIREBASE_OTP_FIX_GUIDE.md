# 🔥 Firebase OTP Chrome Issue - Complete Fix Guide

## 📋 Your Project Information

**Package Name:** `com.univfoods.curry`  
**Firebase Project:** `univfoods-967a6`

### 🔑 Your SHA Fingerprints (Debug Build)

```
SHA-1:   AE:4C:1C:20:50:86:55:2E:16:A3:A5:B5:B6:0E:51:8A:BD:6C:65:61
SHA-256: CB:BA:2E:2E:69:0F:B0:A4:25:58:CC:39:64:92:B7:A9:15:E4:41:41:F7:9F:18:97:6D:BC:78:84:7E:39:36:14
```

---

## ✅ Step-by-Step Fix Instructions

### 1️⃣ Add SHA Fingerprints to Firebase Console

1. **Open Firebase Console:**  
   Go to: https://console.firebase.google.com/project/univfoods-967a6/settings/general

2. **Navigate to Your Android App:**
   - Scroll down to "Your apps"
   - Find the app with package name: `com.univfoods.curry`

3. **Add SHA Fingerprints:**
   - Click "Add fingerprint"
   - Paste SHA-1: `AE:4C:1C:20:50:86:55:2E:16:A3:A5:B5:B6:0E:51:8A:BD:6C:65:61`
   - Click "Add fingerprint" again
   - Paste SHA-256: `CB:BA:2E:2E:69:0F:B0:A4:25:58:CC:39:64:92:B7:A9:15:E4:41:41:F7:9F:18:97:6D:BC:78:84:7E:39:36:14`
   - Click **Save**

4. **Download Updated google-services.json:**
   - After saving, download the new `google-services.json` file
   - Replace the file at: `customer_app/android/app/google-services.json`

---

### 2️⃣ Enable Phone Authentication

1. **Go to Firebase Console:**  
   https://console.firebase.google.com/project/univfoods-967a6/authentication/providers

2. **Enable Phone Sign-in:**
   - Click on "Phone" provider
   - Toggle "Enable"
   - Click "Save"

---

### 3️⃣ Enable Play Integrity API (CRITICAL!)

**This is the most commonly missed step that causes Chrome to open!**

#### Option A: Via Firebase Console
1. Go to: https://console.firebase.google.com/project/univfoods-967a6/appcheck
2. Click "Get Started" or "Apps"
3. Select your Android app
4. Choose "Play Integrity" as the provider
5. Click "Save"

#### Option B: Via Google Cloud Console (Recommended)
1. Go to: https://console.cloud.google.com/apis/library/playintegrity.googleapis.com?project=univfoods-967a6
2. Click **"ENABLE"**
3. Wait for confirmation

---

### 4️⃣ Verify Package Name Consistency

✅ Already verified - all locations use: `com.univfoods.curry`
- `android/app/build.gradle` ✓
- `AndroidManifest.xml` ✓
- Firebase Console ✓

---

### 5️⃣ Clean Build & Reinstall

Run these commands in order:

```bash
# 1. Stop the running app
# Press 'q' in the terminal running flutter

# 2. Clean the project
cd customer_app
flutter clean

# 3. Get dependencies
flutter pub get

# 4. Uninstall old app from device
# Manually uninstall "UNIV Foods" from your phone

# 5. Build and install fresh
flutter run
```

---

### 6️⃣ Update Google Play Services on Device

**On your physical Android device:**
1. Open **Settings** → **Apps** → **Google Play Services**
2. Check for updates
3. Update if available
4. Restart device

---

## 🎯 Expected Result

After completing all steps:

✅ Enter phone number  
✅ **NO Chrome browser opens**  
✅ **NO reCAPTCHA verification**  
✅ OTP sent directly via SMS  
✅ Silent verification works automatically  

---

## 🚨 Important Notes

### Device Requirements
- ❌ **Standard Android Emulator** → Will always open Chrome
- ✅ **Real Physical Device** → Recommended (best experience)
- ✅ **Google Play System Image Emulator** → Works

### If Chrome Still Opens
1. Ensure Play Integrity API is enabled in Google Cloud Console
2. Wait 5-10 minutes after adding SHA keys (Firebase needs to propagate)
3. Completely uninstall and reinstall the app
4. Check that you downloaded the NEW google-services.json after adding SHA keys
5. Verify you're testing on a real device, not a standard emulator

### Testing Tips
- Use a real phone number for testing
- Ensure device has active internet connection
- Check Firebase Console → Authentication → Users to see if sign-ins are being recorded

---

## 📝 Code Changes Already Applied

✅ Added `timeout: const Duration(seconds: 60)` to `verifyPhoneNumber()`  
✅ Verified `INTERNET` permission in AndroidManifest.xml  
✅ Package name consistency verified  

---

## 🔗 Quick Links

- **Firebase Console:** https://console.firebase.google.com/project/univfoods-967a6
- **Google Cloud Console:** https://console.cloud.google.com/apis/dashboard?project=univfoods-967a6
- **Play Integrity API:** https://console.cloud.google.com/apis/library/playintegrity.googleapis.com?project=univfoods-967a6

---

**Last Updated:** 2026-02-14  
**Status:** Ready for manual Firebase configuration
