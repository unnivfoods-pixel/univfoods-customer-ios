# implementation_plan
# FULL PRODUCTION FLOW - UNIV FOODS

## 1. Database & Schema Alignment
- Ensure `orders` table has:
  - `payment_method`: 'online' | 'cod'
  - `payment_status`: 'unpaid' | 'paid' | 'refund_initiated' | 'refunded'
  - `status`: 'placed' | 'accepted' | 'preparing' | 'ready' | 'picked_up' | 'on_the_way' | 'delivered' | 'cancelled'
- Ensure `delivery_riders` table has:
  - `latitude`, `longitude` (for real-time tracking)
  - `last_updated` (timestamp)
- Policy Setup:
  - Enable RLS but ensure Apps can read/write their specific domains.

## 2. Customer App (Flutter)
### A) Address & Range Check
- Implement Haversine distance check (15km) between Vendor and Customer.
- Save lat/lng with address.
### B) Checkout Flow
- Add Radio buttons for 'Online Payment' and 'Cash on Delivery'.
- Integrate Razorpay flow logic:
  - Online: Razorpay -> Success -> DB Insert.
  - COD: DB Insert immediately.
### C) Cancellation Logic
- Button visible ONLY if `status` is 'placed' or 'accepted'.
- If 'preparing' or beyond, disable/hide button.
### D) Live Tracking
- Map view fetching Rider location from `delivery_riders` DB table.
- Static pins for Vendor/User.

## 3. Vendor App (Flutter)
### A) Status Transition
- Flow: `accepted` -> `preparing` (This must trigger 'No Refund' flag in logic).
- `preparing` -> `ready`.
### B) UI Feedback
- Display Payment Type (COD vs Online) clearly to Vendor.

## 4. Delivery App (Flutter)
### A) GPS Polling
- Implement background/foreground timer to update `delivery_riders` table every 10s with current GPS.
### B) Delivery Completion
- For COD: Add 'Collect Cash/UPI' prompt.
- Status update to `delivered` and `payment_status = paid`.
- Add 'Customer Refused' status.

## 5. Admin Panel (React) - CURRENT FOCUS
### A) Dashboard & Orders
- Add columns for `Payment Type` and `Payment Status`.
- Add "Refund" button for Admin (only available for Online orders).
- Implement Refund API call (needs a helper or serverless function if RLS is strict, or direct via Secret Key if secure).

---

## EXECUTION STEP 1: DATABASE FINALIZATION
I will create a single SQL script to ensure ALL tables match these requirements exactly.
