---
description: How to deploy to Netlify (Free Alternative)
---

If Firebase requires a billing account or is not working for you, **Netlify** is a fantastic, completely free alternative for static websites like yours.

### Phase 1: Deploy the Website
1.  Go to [app.netlify.com](https://app.netlify.com) and Sign Up (it's free).
2.  Once logged in, go to the **Team Overview** or **Sites** page.
3.  You will see a box that says **"Drag and drop your site output folder here"**.
    *   *(Note: If you don't see it, look for "Add new site" -> "Deploy manually")*
4.  Open your file explorer on your computer.
5.  Locate the `landing_website` folder inside `curry-delivery-platform`.
6.  **Drag and drop the entire `landing_website` folder** into that area in your browser.
7.  Netlify will upload the files (including the APK) and your site will be live instantly on a random URL (like `jolly-panda-123456.netlify.app`).

### Phase 2: Connect Your Domain (univfoods.in)
1.  Click on **"Domain settings"** (or "Set up a custom domain") on your new site's dashboard.
2.  Click **"Add custom domain"**.
3.  Enter `univfoods.in` and click **Verify**.
4.  Netlify will give you **DNS Records** to add.
    *   Usually, it asks for an **A Record** pointing to `75.2.60.5` (Netlify's Load Balancer).
    *   And a **CNAME** for `www` pointing to your Netlify site URL.
5.  Log in to where you bought your domain (e.g., GoDaddy, Namecheap).
6.  Go to **DNS Management** for `univfoods.in`.
7.  Add the records Netlify provided.
8.  Wait a few minutes (up to 24h) for it to verify. Netlify will automatically provision a free SSL certificate (HTTPS) for you.

You are done! Your site is hosted for free.
