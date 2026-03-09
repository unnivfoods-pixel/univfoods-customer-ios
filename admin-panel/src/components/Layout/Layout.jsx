import React, { useEffect, useState } from 'react';
import { Outlet } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Bell, Menu } from 'lucide-react'; // Added Menu import
import Sidebar from './Sidebar';
import './Layout.css';

import { supabase } from '../../supabase';

const Layout = () => {
    const [toast, setToast] = useState(null);
    const [isSidebarOpen, setIsSidebarOpen] = useState(false);

    useEffect(() => {
        // Listen for new orders via Supabase
        const channel = supabase.channel('realtime-orders')
            .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'orders' }, payload => {
                setToast({
                    title: 'New Order Received',
                    message: `Order #${payload.new.id.substring(0, 6)} needs attention`,
                    type: 'success'
                });
                setTimeout(() => setToast(null), 5000);
            })
            .subscribe();

        return () => {
            supabase.removeChannel(channel);
        };
    }, []);

    return (
        <div className="app-container">
            <Sidebar isOpen={isSidebarOpen} toggleSidebar={() => setIsSidebarOpen(!isSidebarOpen)} />

            <main className="main-content">
                <div className="mobile-header">
                    <button className="menu-btn" onClick={() => setIsSidebarOpen(true)}>
                        <Menu size={24} />
                    </button>
                    <span className="mobile-logo">UNIV <span className="text-primary">Foods</span></span>
                </div>
                <Outlet />
            </main>

            <AnimatePresence>
                {toast && (
                    <motion.div
                        className="toast-notification glass-panel"
                        initial={{ x: 100, opacity: 0 }}
                        animate={{ x: 0, opacity: 1 }}
                        exit={{ x: 100, opacity: 0 }}
                    >
                        <div className="toast-icon">
                            <Bell size={20} color="white" />
                        </div>
                        <div className="toast-content">
                            <h4>{toast.title}</h4>
                            <p>{toast.message}</p>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default Layout;
