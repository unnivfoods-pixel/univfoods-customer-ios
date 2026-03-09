
# ⚡️ Critical Step: Populate Database with Real Data

To make "all apps operate with realtime features", the database must have data.
The Admin Panel and Customer App are code-ready, but they need data to function fully.

Please run the provided SQL script in your Supabase Dashboard:

1.  Go to your **Supabase Project**.
2.  Click on the **SQL Editor** (looks like a terminal icon) in the left sidebar.
3.  Click **New Query**.
4.  Copy the content of the file `REFRESH_DATA.sql` (already open in your editor).
5.  Paste it into the Supabase SQL Editor.
6.  Click **Run**.

### What this does:
*   **Clears old data**: Prevents duplicates.
*   **Creates Vendors**: "Spice Kingdom", "Curry House", etc.
*   **Creates Menu Items**: Full menu for each vendor.
*   **Creates Orders**: Mock orders for the Admin Panel to display immediately.

Once you run this, refresh:
*   **Admin Panel:** http://localhost:5173/orders -> You will see orders.
*   **Customer App:** http://localhost:5007 -> You will see vendors and menus.
