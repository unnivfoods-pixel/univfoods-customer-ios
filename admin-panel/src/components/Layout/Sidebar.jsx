import React, { useState, useEffect } from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import { LayoutDashboard, Store, ShoppingBag, Settings, LogOut, Menu, X, Users, UtensilsCrossed, MapPin, Map as MapIcon, CreditCard, FileText, Megaphone, BarChart, FileClock, UserPlus, Landmark, Bell, Truck, Image as ImageIcon, Layers, MessageSquare, RefreshCw, AlertTriangle, HelpCircle } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { supabase } from '../../supabase';
import logo from '../../assets/univ_logo.png';
import './Sidebar.css';

const Sidebar = ({ isOpen, toggleSidebar }) => {
  const location = useLocation();

  const [dbStatus, setDbStatus] = useState('connecting');
  const [openTickets, setOpenTickets] = useState(0);

  useEffect(() => {
    fetchOpenTickets();
    const sub = supabase.channel('tickets-badge')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'support_tickets' }, fetchOpenTickets)
      .subscribe();
    return () => supabase.removeChannel(sub);
  }, []);

  const fetchOpenTickets = async () => {
    const { count } = await supabase
      .from('support_tickets')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'OPEN');
    setOpenTickets(count || 0);
  };

  useEffect(() => {
    const checkPulse = async () => {
      try {
        const { error } = await supabase.from('vendors').select('id').limit(1);
        if (error) setDbStatus('offline');
        else setDbStatus('online');
      } catch {
        setDbStatus('offline');
      }
    };
    checkPulse();
    const interval = setInterval(checkPulse, 10000);
    return () => {
      clearInterval(interval);
      if (window.innerWidth <= 1024 && isOpen) {
        if (toggleSidebar) toggleSidebar();
      }
    };
  }, [location]);

  const handleLogout = async () => {
    await supabase.auth.signOut();
    window.location.href = '/login';
  };

  const navItems = [
    { icon: LayoutDashboard, label: 'Dashboard', path: '/' },
    { icon: ShoppingBag, label: 'Orders', path: '/orders' },
    { icon: Store, label: 'Vendors', path: '/vendors' },
    { icon: UtensilsCrossed, label: 'Products', path: '/menu' },
    { icon: ImageIcon, label: 'Media Library', path: '/media' },
    { icon: BarChart, label: 'Reports', path: '/reports' },
    { icon: Layers, label: 'Categories', path: '/categories' },
    { icon: FileText, label: 'Legal & Policies', path: '/legal' },
    { icon: UserPlus, label: 'Partner Registrations', path: '/registrations' },
    { icon: Users, label: 'Customers', path: '/customers' },
    { icon: Truck, label: 'Delivery Team', path: '/delivery' },
    { icon: MapPin, label: 'Delivery Zones', path: '/zones' },
    { icon: Bell, label: 'Notifications', path: '/notifications' },
    { icon: Landmark, label: 'Settlements', path: '/settlements' },
    { icon: CreditCard, label: 'Payments', path: '/payments' },
    { icon: RefreshCw, label: 'Refunds', path: '/refunds' },
    { icon: MessageSquare, label: 'Support Tickets', path: '/support' },
    { icon: HelpCircle, label: 'Manage FAQs', path: '/faqs' },
    { icon: Settings, label: 'System Settings', path: '/settings' },
    { icon: AlertTriangle, label: 'Fraud Shield', path: '/fraud' },
    { icon: FileClock, label: 'Audit Logs', path: '/audit' },
  ];

  return (
    <>
      {/* Mobile Overlay */}
      {isOpen && (
        <div
          className="sidebar-overlay"
          onClick={toggleSidebar}
          style={{
            position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 90
          }}
        />
      )}

      <motion.aside
        className={`sidebar glass-panel ${isOpen ? 'open' : ''}`}
        initial={false}
      >
        <div className="sidebar-header">
          <div className="logo-container">
            <img src={logo} alt="UNIV FOODS" className="brand-logo" />
          </div>
          <div className="logo-text-container">
            <span className="logo-text">UNIV <span>FOODS</span></span>
            <span className="logo-subtitle">Admin Terminal</span>
          </div>

          {/* Mobile Close Button */}
          <button className="mobile-close-btn" onClick={toggleSidebar} style={{ marginLeft: 'auto', background: 'none', border: 'none', color: 'white', display: window.innerWidth <= 1024 ? 'block' : 'none' }}>
            <X size={24} />
          </button>
        </div>

        <nav className="sidebar-nav">
          {navItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
            >
              <item.icon size={20} />
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', width: '100%' }}>
                <span>{item.label}</span>
                {item.path === '/support' && openTickets > 0 && (
                  <span style={{
                    background: '#ef4444',
                    color: 'white',
                    fontSize: '0.65rem',
                    fontWeight: '900',
                    padding: '2px 8px',
                    borderRadius: '10px',
                    boxShadow: '0 0 10px rgba(239, 68, 68, 0.5)'
                  }}>
                    {openTickets}
                  </span>
                )}
              </div>
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-footer">
          {/* Connection Pulse */}
          <div style={{ marginBottom: '16px', padding: '12px', background: 'rgba(255,255,255,0.05)', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.1)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
              <div className={`pulse-${dbStatus === 'online' ? 'green' : 'red'}`} style={{ width: '8px', height: '8px', borderRadius: '50%', background: dbStatus === 'online' ? '#10B981' : '#EF4444' }} />
              <span style={{ fontSize: '0.65rem', fontWeight: '800', color: dbStatus === 'online' ? '#10B981' : '#EF4444', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                {dbStatus === 'online' ? 'System Active' : 'Signal Lost'}
              </span>
            </div>
            <p style={{ fontSize: '0.6rem', color: 'rgba(255,255,255,0.4)', margin: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              dxqcruvarqgnscenixzf.supabase.co
            </p>
          </div>

          <div className="user-profile">
            <div className="user-avatar">AU</div>
            <div className="user-info">
              <p className="user-name">Root Admin</p>
              <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
                <p className="user-role">System Master</p>
              </div>
            </div>
          </div>
          <button onClick={handleLogout} className="logout-btn">
            <LogOut size={16} /> End Session
          </button>
        </div>
      </motion.aside>
    </>
  );
};

export default Sidebar;
