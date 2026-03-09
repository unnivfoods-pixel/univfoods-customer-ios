---
description: How to connect univfoods.in to Firebase Hosting
---

This workflow guides you through deploying the `landing_website` to Firebase Hosting and connecting your custom domain `univfoods.in`.

1. **Install Firebase Tools** (if not already installed)
   In your terminal, run:
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**
   ```bash
   firebase login
   ```

3. **Initialize/Select Project**
   Since we created `firebase.json` for you, you just need to associate it with a Firebase project.
   Run:
   ```bash
   firebase use --add
   ```
   - Select your existing project (e.g. `ecomartx...` or similar if you are reusing it, or create a new one in the Firebase Console first).
   - Alias it as `default`.

4. **Deploy the Website**
   ```bash
   firebase deploy --only hosting
   ```
   This will upload the `landing_website` folder content.

5. **Connect Domain**
   - Go to the [Firebase Console](https://console.firebase.google.com/)
   - Select your project.
   - Go to **Hosting**.
   - Click **Add Custom Domain**.
   - Enter `univfoods.in`.
   - Follow the instructions to add the `TXT` and `A` records to your GoDaddy (or other registrar) DNS settings.
     - You will likely need to add a `TXT` record for verification.
     - Then add `A` records (IP addresses) provided by Firebase.
   - Wait for propagation (can take up to 24h, but usually fast).

✅ **Done!** Your site should be live at `https://univfoods.in`.
