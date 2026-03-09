import React, { useEffect, useState } from 'react';
import { Routes, Route, useNavigate, Navigate } from 'react-router-dom';
import Layout from './components/Layout/Layout';
import Dashboard from './pages/Dashboard';
import Vendors from './pages/Vendors';
import Products from './pages/Products';
import Categories from './pages/Categories';
import Orders from './pages/Orders';
import Customers from './pages/Customers';
import DeliveryTeam from './pages/DeliveryTeam';
import DeliveryZones from './pages/DeliveryZones';
import Payments from './pages/Payments';
import LegalPolicies from './pages/LegalPolicies';
import Reports from './pages/Reports';
import Promotions from './pages/Promotions';
import RegistrationRequestsV2 from './pages/RegistrationRequestsV2';
import Settlements from './pages/Settlements';
import MediaLibrary from './pages/MediaLibrary';
import Notifications from './pages/Notifications';
import AuditLogs from './pages/AuditLogs';
import Login from './pages/Login';
import SystemSettings from './pages/SystemSettings';
import SupportTickets from './pages/SupportTickets';
import Refunds from './pages/Refunds';
import FraudMonitor from './pages/FraudMonitor';
import Faqs from './pages/Faqs';
import { supabase } from './supabase';

function App() {
  const navigate = useNavigate();
  const [init, setInit] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      // If no session and not already on login page (handled by router but good to check)
      // Actually main router handles /login separately, so checking session here is for Protected Routes.
      // But App wraps everything.
      // We will let the useEffect handle redirect if path is not /login
      if (!session && window.location.pathname !== '/login') {
        navigate('/login');
      }
      setInit(true);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!session) {
        navigate('/login');
      }
    });

    // 🛎️ GLOBAL REALTIME NOTIFICATION LISTENER
    // This catches "New Order" alerts from the database triggers 
    // and shows them as a toast notification in the admin panel.
    const notifSub = supabase.channel('admin-global-notifs')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications'
      }, (payload) => {
        const { title, body, target_type } = payload.new;
        // Only show for Global or Admin-specific alerts
        if (target_type === 'all' || target_type === 'admin') {
          import('react-hot-toast').then(({ toast }) => {
            toast.custom((t) => (
              <div className={`${t.visible ? 'animate-enter' : 'animate-leave'} glass-panel`}
                style={{
                  padding: '16px 24px', background: 'rgba(15, 23, 42, 0.95)',
                  color: 'white', borderRadius: '16px', border: '1px solid #FFD600',
                  boxShadow: '0 10px 40px rgba(0,0,0,0.2)', display: 'flex', gap: '12px'
                }}>
                <div style={{ background: '#FFD600', width: '4px', borderRadius: '2px' }} />
                <div>
                  <div style={{ fontWeight: '900', color: '#FFD600', fontSize: '0.9rem' }}>{title}</div>
                  <div style={{ fontSize: '0.8rem', opacity: 0.9 }}>{body}</div>
                </div>
              </div>
            ), { duration: 6000 });
          });
        }
      })
      .subscribe();

    return () => {
      subscription.unsubscribe();
      notifSub.unsubscribe();
    };
  }, []);

  if (!init) return <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', background: '#f0fdf4', color: '#1B5E20' }}>Loading Curry Platform...</div>;

  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/" element={<Layout />}>
        <Route index element={<Dashboard />} />
        <Route path="vendors" element={<Vendors />} />
        <Route path="categories" element={<Categories />} />
        <Route path="menu" element={<Products />} />
        <Route path="orders" element={<Orders />} />
        <Route path="delivery" element={<DeliveryTeam />} />
        <Route path="customers" element={<Customers />} />
        <Route path="zones" element={<DeliveryZones />} />
        <Route path="payments" element={<Payments />} />
        <Route path="legal" element={<LegalPolicies />} />
        <Route path="reports" element={<Reports />} />
        <Route path="promotions" element={<Promotions />} />
        <Route path="registrations" element={<RegistrationRequestsV2 />} />
        <Route path="media" element={<MediaLibrary />} />
        <Route path="notifications" element={<Notifications />} />
        <Route path="settlements" element={<Settlements />} />
        <Route path="settings" element={<SystemSettings />} />
        <Route path="audit" element={<AuditLogs />} />
        <Route path="support" element={<SupportTickets />} />
        <Route path="refunds" element={<Refunds />} />
        <Route path="fraud" element={<FraudMonitor />} />
        <Route path="faqs" element={<Faqs />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}

export default App;
