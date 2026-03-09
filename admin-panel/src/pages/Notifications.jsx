import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Megaphone, Send, Bell, BellOff, X, Filter, Trash2, CheckCircle, AlertCircle, Clock, Smartphone, Mail, Globe, User } from 'lucide-react';
import { supabase } from '../supabase';
import { toast } from 'react-hot-toast';
import './Notifications.css';

const Notifications = () => {
    const [notifications, setNotifications] = useState([]);
    const [loading, setLoading] = useState(true);
    const [isCampaignModalOpen, setIsCampaignModalOpen] = useState(false);
    const [campaign, setCampaign] = useState({
        title: '', message: '', type: 'all', target: 'all',
        category: 'ALERT', user_id: ''
    });

    useEffect(() => {
        fetchNotifications();
        const sub = supabase.channel('notifs-live-extreme')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'notifications' }, fetchNotifications)
            .subscribe();
        return () => sub.unsubscribe();
    }, []);

    const fetchNotifications = async () => {
        const { data } = await supabase.from('notifications').select('*').order('created_at', { ascending: false });
        if (data) setNotifications(data);
        setLoading(false);
    };

    const handleSendCampaign = async (e) => {
        e.preventDefault();
        try {
            const payload = {
                title: campaign.title,
                body: campaign.message, // Renaming message to body for schema
                category: campaign.category,
                status: 'unread',
                created_at: new Date().toISOString()
            };

            if (campaign.target === 'specific') {
                payload.user_id = campaign.user_id;
            } else {
                payload.target_type = campaign.target; // all, vendors, riders
            }

            const { error } = await supabase.from('notifications').insert([payload]);
            if (error) throw error;
            setIsCampaignModalOpen(false);
            setCampaign({ title: '', message: '', type: 'all', target: 'all', category: 'ALERT', user_id: '' });
            toast.success("Broadcast Signal Dispatched!");
        } catch (error) {
            toast.error(error.message);
        }
    };

    return (
        <div className="notifications-page">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Broadcast Center</h1>
                    <p className="page-subtitle">Targeted push signals and global announcements.</p>
                </div>
                <div className="page-actions">
                    <button
                        className="btn-primary"
                        onClick={() => setIsCampaignModalOpen(true)}
                        style={{ background: '#FFD600', color: '#0F172A' }}
                    >
                        <Megaphone size={24} /> NEW CAMPAIGN
                    </button>
                </div>
            </header>

            <div className="notifications-grid">
                <div className="glass-panel history-panel">
                    <h3 className="panel-title">Live Signal History</h3>

                    {loading ? (
                        <div className="loading-signals">Syncing broadcast logs...</div>
                    ) : (
                        <div className="signals-list">
                            {notifications.length === 0 ? (
                                <div className="empty-signals">No signals sent yet.</div>
                            ) : notifications.map((notif, idx) => (
                                <motion.div key={notif.id} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: idx * 0.05 }}
                                    className="signal-card">
                                    <div className={`signal-icon ${notif.category === 'ALERT' ? 'alert' : 'info'}`}>
                                        {notif.category === 'ALERT' ? <AlertCircle size={24} /> : <Bell size={24} />}
                                    </div>
                                    <div className="signal-content">
                                        <div className="signal-header">
                                            <h4>{notif.title}</h4>
                                            <span className="signal-time">{new Date(notif.created_at).toLocaleTimeString()}</span>
                                        </div>
                                        <p className="signal-body">{notif.body || notif.message}</p>
                                        <div className="signal-meta">
                                            <span className="target-badge">TARGET: {notif.target_type || 'SPECIFIC USER'}</span>
                                        </div>
                                    </div>
                                </motion.div>
                            ))}
                        </div>
                    )}
                </div>

                <div className="health-sidebar">
                    <div className="glass-panel health-panel">
                        <h4 className="health-title">Network Health</h4>
                        <div className="health-stats">
                            <div className="health-item">
                                <div className="health-info">
                                    <span className="label">Push Reach</span>
                                    <span className="value">99.2%</span>
                                </div>
                                <div className="progress-bar">
                                    <div className="progress-fill" style={{ width: '99.2%' }} />
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <AnimatePresence>
                {isCampaignModalOpen && (
                    <div className="modal-overlay" onClick={() => setIsCampaignModalOpen(false)}>
                        <motion.div
                            initial={{ opacity: 0, y: 30, scale: 0.95 }}
                            animate={{ opacity: 1, y: 0, scale: 1 }}
                            exit={{ opacity: 0, y: 30, scale: 0.95 }}
                            className="glass-panel campaign-modal"
                            onClick={e => e.stopPropagation()}
                        >
                            <div className="modal-header">
                                <h2>Command Signal</h2>
                                <button className="close-btn" onClick={() => setIsCampaignModalOpen(false)}><X size={24} /></button>
                            </div>

                            <form onSubmit={handleSendCampaign} className="campaign-form">
                                <div className="form-group">
                                    <label>SIGNAL LEAD</label>
                                    <input required value={campaign.title} onChange={e => setCampaign({ ...campaign, title: e.target.value })} placeholder="Campaign Heading" className="signal-input" />
                                </div>
                                <div className="form-group">
                                    <label>PAYLOAD MESSAGE</label>
                                    <textarea required value={campaign.message} onChange={e => setCampaign({ ...campaign, message: e.target.value })} placeholder="Signal content..." className="signal-textarea" />
                                </div>
                                <div className="form-row">
                                    <div className="form-group">
                                        <label>SIGNAL TYPE</label>
                                        <select value={campaign.category} onChange={e => setCampaign({ ...campaign, category: e.target.value })} className="signal-select">
                                            <option value="INFO">INFO</option>
                                            <option value="ALERT">ALERT</option>
                                            <option value="PROMO">PROMO</option>
                                        </select>
                                    </div>
                                    <div className="form-group">
                                        <label>TARGET GRID</label>
                                        <select value={campaign.target} onChange={e => setCampaign({ ...campaign, target: e.target.value })} className="signal-select">
                                            <option value="all">GLOBAL (ALL)</option>
                                            <option value="vendors">VENDORS</option>
                                            <option value="riders">RIDERS</option>
                                            <option value="specific">SPECIFIC USER ID</option>
                                        </select>
                                    </div>
                                </div>
                                {campaign.target === 'specific' && (
                                    <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: 'auto' }} className="form-group">
                                        <label>TARGET USER ID</label>
                                        <input required value={campaign.user_id} onChange={e => setCampaign({ ...campaign, user_id: e.target.value })} placeholder="Paste User UUID" className="signal-input" />
                                    </motion.div>
                                )}
                                <div className="modal-footer">
                                    <button type="button" onClick={() => setIsCampaignModalOpen(false)} className="cancel-btn">CANCEL</button>
                                    <button type="submit" className="dispatch-btn">DISPATCH SIGNAL <Send size={20} /></button>
                                </div>
                            </form>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>

        </div>
    );
};

const inputStyle = {
    width: '100%',
    padding: '16px 20px',
    borderRadius: '16px',
    border: '2px solid #f1f5f9',
    outline: 'none',
    fontSize: '1rem',
    fontWeight: '800',
    color: '#0f172a',
    background: '#f8fafc'
};

export default Notifications;
