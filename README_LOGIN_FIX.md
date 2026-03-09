
# 🚨 URGENT: FIXING LOGIN (403 ERROR)

You are seeing a `403` error because Supabase is trying to send a real SMS via Twilio, but your Twilio setup is incomplete (missing DLT for India).

**The Solution:** Bypass real SMS by using "Test Numbers".

## STEP 1: Go to Supabase Dashboard
1. Open your project in Supabase.
2. Click on **Authentication** (icon on the left).
3. Click on **Providers** under Configuration.
4. Select **Phone**.

## STEP 2: Configure Test Number
1. Ensure **Enable Phone Provider** is toggled **ON**.
2. Scroll down to the section **"Phone Numbers for Testing"**.
3. Click **"Add Phone Number"**.
4. Enter your number: `8897868951` (Use the exact format, e.g., with or without +91 as shown in your app input).
   - *Recommendation:* Enter `8897868951` (no plus) if your app adds the country code automatically, or `+918897868951` if you type it all.
   - The app currently adds `+91` automatically, so you should ensure the final format matches. 
   - **Safest bet:** Add `8897868951` and the app sends `+918897868951`. Wait, looking at code: `phone: "+91$phone"`.
   - So in Supabase, add `+918897868951`.
5. Enter a **Test OTP**: `123456`.
6. Click **Save**.

## STEP 3: Login
1. Open the App.
2. Enter `8897868951`.
3. Click "Send OTP".
4. **Supabase will NOT send an SMS.** instead, it treats it as a successful send.
5. In the OTP field, enter `123456`.
6. Click "Verify". **Login will succeed.**

---
**Why this works:**
It completely bypasses the Twilio/SMS network. It is the standard way to deveop apps without burning SMS credits or dealing with DLT regulations.
