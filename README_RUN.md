# Curry Delivery Platform - Running Instructions

The platform consists of 4 applications. Here is how to run them locally:

## 1. Prerequisites
- Flutter SDK (3.x)
- Node.js (v18+)
- Supabase Project (Keys configured in `lib/core/supabase_config.dart` and `src/supabase.js`)

## 2. Running the Admin Panel (Web)
```bash
cd admin-panel
npm install
npm run dev
```
- Access at: `http://localhost:5173`

## 3. Running the Mobile Apps (Flutter Web)

We recommend running them on formatted ports for easy access.

### Vendor App (Restaurant Partner)
```bash
cd vendor_app
flutter run -d chrome --web-port 5001
```
- Access at: `http://localhost:5001`
- **Features:** Manage Menu, View Incoming Orders, Dashboard Stats.
- **Theme:** Professional Amber/Orange.

### Customer App (Client)
```bash
cd customer_app
flutter run -d chrome --web-port 5002
```
- Access at: `http://localhost:5002`
- **Features:** Browse Vendors, Add to Cart, Place Orders, Live Map.
- **Theme:** Warm Foodie Orange.

### Delivery App (Rider)
```bash
cd delivery_app
flutter run -d chrome --web-port 5003
```
- Access at: `http://localhost:5003`
- **Features:** Go Online/Offline, Accept Available Orders, Delivery Dashboard.
- **Theme:** High-Visibility Teal/Green.

## 4. Troubleshooting
- If you see "Target of URI doesn't exist", run `flutter pub get` in the respective directory.
- If `supabase_config.dart` is missing, ensure you have copied it to `lib/core/` of each app.
