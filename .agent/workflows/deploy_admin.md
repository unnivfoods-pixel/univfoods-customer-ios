---
description: How to deploy the Admin Panel to Netlify
---

This workflow guides you through deploying the `admin-panel` (React/Vite app) to Netlify.

1.  **Build the Project**
    I have already added a `_redirects` file for you so that refreshing pages (like `/orders`) works on Netlify.
    Run these commands in your terminal:

    ```bash
    cd admin-panel
    npm install
    npm run build
    ```

2.  **Locate the Output**
    After the build finishes, you will see a new folder called **`dist`** inside the `admin-panel` folder.
    *   Path: `curry-delivery-platform/admin-panel/dist`

3.  **Deploy to Netlify**
    *   Go to [app.netlify.com](https://app.netlify.com)
    *   **Drag and drop the `dist` folder** (NOT the whole admin-panel folder) into the Netlify "Sites" area.
    *   It will deploy instantly.

4.  **Connect Admin Subdomain**
    *   Go to **Domain Settings** for this new admin site.
    *   Click **Add custom domain**.
    *   Enter: `admin.univfoods.in` (Since you own `univfoods.in`).
    *   Netlify will verify it.
    *   **Add the CNAME Record**: Go to your domain registrar (e.g., GoDaddy) and add a **CNAME** record:
        *   **Host**: `admin`
        *   **Value**: `[your-admin-site-name].netlify.app`
    *   Wait for SSL to provision.

✅ **Done!** You can now manage your platform at `https://admin.univfoods.in`.
