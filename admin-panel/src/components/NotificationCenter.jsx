import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';
import { Bell, X, Info, CheckCircle, AlertTriangle, ExternalLink } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import './NotificationCenter.css';

const NotificationCenter = () => {
    const [notifications, setNotifications] = useState([]);
    const [isOpen, setIsOpen] = useState(false);
    const navigate = useNavigate();

    useEffect(() => {
        fetchInitialNotifications();

        const channel = supabase.channel('admin-grid-alerts')
            .on('postgres_changes', {
                event: 'INSERT',
                schema: 'public',
                table: 'notifications'
            }, (payload) => {
                const n = payload.new;
                // Only show for Admin or High-priority roles
                if (n.role === 'ADMIN' || n.event_type?.includes('FAIL') || n.event_type?.includes('ALERT')) {
                    setNotifications(prev => [n, ...prev].slice(0, 15));
                }
            })
            .subscribe();

        return () => channel.unsubscribe();
    }, []);

    const fetchInitialNotifications = async () => {
        const { data } = await supabase
            .from('notifications')
            .select('*')
            .or('role.eq.ADMIN,event_type.ilike.%ALERT%,event_type.ilike.%FAIL%')
            .order('created_at', { ascending: false })
            .limit(10);

        if (data) setNotifications(data);
    };

    const markAllRead = async () => {
        const { error } = await supabase.from('notifications').update({ is_read: true }).eq('role', 'ADMIN');
        if (!error) {
            setNotifications(prev => prev.map(n => ({ ...n, is_read: true })));
        }
    };

    const unreadCount = notifications.filter(n => !n.is_read).length;

    const goToNotificationsPage = () => {
        setIsOpen(false);
        navigate('/notifications');
    };

    return (
        <div style={{ position: 'relative' }}>
            <button
                className="icon-btn-light"
                onClick={() => setIsOpen(!isOpen)}
                style={{
                    position: 'relative',
                    background: unreadCount > 0 ? 'rgba(255, 214, 0, 0.1)' : 'white',
                    border: '1px solid rgba(0,0,0,0.05)',
                    padding: '10px',
                    borderRadius: '12px',
                    cursor: 'pointer',
                    transition: 'all 0.2s'
                }}
            >
                <Bell size={22} color={unreadCount > 0 ? '#0F172A' : '#94a3b8'} />
                {unreadCount > 0 && (
                    <span className="badge-notification" style={{ background: '#FF4D4D' }}>{unreadCount}</span>
                )}
            </button>

            <AnimatePresence>
                {isOpen && (
                    <motion.div
                        initial={{ opacity: 0, y: 15, scale: 0.95 }}
                        animate={{ opacity: 1, y: 0, scale: 1 }}
                        exit={{ opacity: 0, y: 10, scale: 0.95 }}
                        className="notification-panel shadow-lg"
                        style={{ position: 'absolute', top: '100%', right: 0, marginTop: '12px', width: '350px', zIndex: 1000 }}
                    >
                        <div className="notif-header" style={{ padding: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid #f1f5f9' }}>
                            <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: '800' }}>Admin Alert Grid</h3>
                            <div style={{ display: 'flex', gap: '10px' }}>
                                <button onClick={markAllRead} style={{ background: 'none', border: 'none', color: '#64748b', fontSize: '0.7rem', fontWeight: '800', cursor: 'pointer' }}>READ ALL</button>
                                <button onClick={() => setIsOpen(false)} style={{ background: 'none', border: 'none', color: '#64748b', cursor: 'pointer' }}><X size={16} /></button>
                            </div>
                        </div>

                        <div className="notif-list" style={{ maxHeight: '400px', overflowY: 'auto' }}>
                            {notifications.length === 0 ? (
                                <div style={{ padding: '40px', textAlign: 'center', color: '#94a3b8' }}>Grid Clear. No active alerts.</div>
                            ) : (
                                notifications.map(n => (
                                    <div
                                        key={n.id}
                                        className={`notif-item ${!n.is_read ? 'unread' : ''}`}
                                        style={{ padding: '16px 20px', borderBottom: '1px solid #f8fafc', background: n.is_read ? 'white' : '#fffbeb', transition: 'all 0.2s' }}
                                    >
                                        <div style={{ display: 'flex', gap: '15px' }}>
                                            <div style={{
                                                width: '36px', height: '36px', borderRadius: '10px', display: 'grid', placeItems: 'center',
                                                background: n.event_type?.includes('FAIL') ? '#fee2e2' : '#f0fdf4'
                                            }}>
                                                {n.event_type?.includes('FAIL') ? <AlertTriangle size={18} color="#ef4444" /> : <Info size={18} color="#10b981" />}
                                            </div>
                                            <div style={{ flex: 1 }}>
                                                <div style={{ fontSize: '0.85rem', fontWeight: '900', color: '#0F172A' }}>{n.title}</div>
                                                <div style={{ fontSize: '0.75rem', color: '#64748b', marginTop: '2px', lineHeight: 1.4 }}>{n.message}</div>
                                                <div style={{ fontSize: '0.65rem', color: '#94a3b8', marginTop: '6px', fontWeight: '700' }}>
                                                    {new Date(n.created_at).toLocaleTimeString()} • {n.event_type}
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                ))
                            )}
                        </div>

                        <div
                            style={{ padding: '15px', textAlign: 'center', background: '#f8fafc', fontSize: '0.75rem', cursor: 'pointer', color: '#0F172A', fontWeight: '800' }}
                            onClick={goToNotificationsPage}
                        >
                            ACCESS FULL LOGS
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default NotificationCenter;
