---
description: Summary of Real-time Features and their implementation status
---

# Real-time Features Implementation Status

The following features have been upgraded to support real-time updates using Supabase Streams and Listeners.

## Customer App

1.  **Home Screen**
    *   **Active Order Banner:** Listens to `orders` table. Updates instantly when order status changes (e.g. from 'Preparing' to 'Ready').
    *   **Live Location:** Uses `LocationService` to detect GPS.
    *   **Search:** Real-time filtering of vendors based on search query.

2.  **Order Tracking**
    *   **Screens:** `OrdersScreen` & `OrderDetailsScreen`
    *   **Status:** Real-time updates via `StreamBuilder`.
    *   **Rider Location:** Live map tracking of rider coordinates on `OrderDetailsScreen` (when rider is assigned).

3.  **Profile & Settings**
    *   **Saved Addresses:** `SavedAddressesScreen` uses `StreamBuilder`. Adding/Deleting addresses updates UI instantly.
    *   **Favorites:** `FavoritesScreen` listens to `user_favorites` changes.
    *   **Notifications:** `NotificationsScreen` listens to new alerts in `notifications` table.

4.  **Cart**
    *   **Address Selection:** Pulls latest addresses from real-time stream.

## Testing Instructions

1.  **Order Flow:** Place an order -> See it appear in "Active Order" banner.
2.  **Tracking:** Open Order Details -> Change status in DB (admin) -> Watch status update in App.
3.  **Addresses:** Add address in Profile -> Go to Cart -> See new address available immediately.
4.  **Favorites:** Like a restaurant on Home -> Go to Favorites -> See it appear.

All requested features are now configured for real-time action.
