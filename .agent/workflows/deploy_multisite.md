---
description: How to deploy univfoods.in and admin.univfoods.in to Firebase
---

This workflow guides you through setting up multi-site hosting for your project.

### Prerequisites
- Ensure `admin-panel` is built: `cd admin-panel && npm run build`

### Step 1: Login and Select Project
### Step 1: Login to Client Account
You must be logged in as `univfoods@gmail.com`.
```bash
firebase logout
firebase login
```

### Step 2: Select the Correct Project
We have pre-configured the project `univfoods-967a6`.
```bash
firebase use default
```

### Step 3: Apply Hosting Targets
The configuration is already set up for project `univfoods-967a6`.
We have mapped:
- `univfoods-967a6` (Main Site)
- `univfoods-admin-panel-3970d` (Admin Site)

If you need to re-apply them manually:
```bash
firebase target:apply hosting univfoods univfoods-967a6
firebase target:apply hosting univfoods-admin univfoods-admin-panel-3970d
```

### Step 3: Connect Custom Domains (Firebase Console)
1. Go to **Hosting** in Firebase Console.
2. For the **Main Site**:
   - Click "Add Custom Domain".
   - Enter `univfoods.in`.
   - Configure DNS (A records) as instructed.
3. For the **Admin Site** (switch site using the dropdown at the top of Hosting page):
   - Click "Add Custom Domain".
   - Enter `admin.univfoods.in`.
   - Configure DNS as instructed.

### Step 4: Deploy
Once targets are applied:
```bash
firebase deploy --only hosting
```

This will deploy:
- `landing_website` -> `univfoods.in`
- `admin-panel/dist` -> `admin.univfoods.in`
