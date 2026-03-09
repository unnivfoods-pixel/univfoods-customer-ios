# CURRY POINT – FINAL PRODUCT VISION

Curry Point is a real-time hyperlocal food ordering system where every role reacts instantly to actions of other roles, with zero manual refresh, clear ownership, and smooth professional UX.

## 🧩 SYSTEM ROLES

### 1. ADMIN PANEL (Controller + Enforcer)
**Workflow:**
*   **Vendor Lifecycle:** Apply -> Review -> Approve (Live) -> Commission/Radius Set.
    *   *Rule:* Block Vendor -> Disappears instantly from Customer App.
*   **Order Control:** View -> Cancel (Any stage) -> Reassign -> Refund.
*   **Dashboard:** Real-time numbers, animated changes, no reload button.

### 2. VENDOR APP (Fast Action)
**Workflow:**
*   **New Order:** Sound + Vibration -> Countdown (30s) -> Accept -> "Preparing".
*   **Handoff:** "Ready" -> Notify Delivery.
*   *Rule:* No action -> Auto-cancel.
*   *Rule:* Cannot see customer phone. Cannot edit completed orders.

### 3. CUSTOMER APP (Fast, Alive, Clear)
**Workflow:**
*   **Discovery:** Location detected -> Nearby Vendors.
*   **Order:** Cart -> Place Order -> Live Tracking.
*   *Rule:* Vendor offline -> Disappears.
*   *Rule:* Order status changes -> UI updates instantly.

### 4. DELIVERY PARTNER APP (Speed + Clarity)
**Workflow:**
*   **Assignment:** Notification -> Accept -> Navigate Vendor -> Pickup -> Navigate Customer -> Drop.
*   *Rule:* Every step updates Admin, Customer, and Vendor immediately.

## ⚡ REAL-TIME IMPLEMENTATION RULES
*   **Listeners Required:** Order Status, Vendor Availability, Delivery Location, Dashboard Metrics.
*   **Strictly Forbidden:** Polling, Manual Refresh, Fake "Realtime".
*   **Latency:** Actions must reflect in 1-2 seconds across all apps.

## 🎨 DESIGN & ANIMATION RULES
*   **UI:** Rounded cards, soft shadows, no sharp borders, clean typography.
*   **Animations:** Button feedback, New Order slide/pop, Status color morph, Number count-up.
*   **Reject If:** Static UI, Dead Screens, Inconsistent styles.

## ✅ ACCEPTANCE CRITERIA
*   [ ] All roles update live (1-2s latency).
*   [ ] Order workflows enforced (timeouts, blocking).
*   [ ] UI is smooth with animations.
*   [ ] No manual refresh buttons.
