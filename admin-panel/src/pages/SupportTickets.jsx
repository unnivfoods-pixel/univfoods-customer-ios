import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';
import { motion, AnimatePresence } from 'framer-motion';
import {
    Search, MessageSquare, CheckCircle, Send,
    ShieldAlert, Ticket, Filter, User, Truck,
    Store, X, DollarSign, Brain, BarChart3,
    Plus, Trash2, Clock, Check, AlertCircle,
    ChevronRight, ArrowLeft
} from 'lucide-react';
import { toast } from 'react-hot-toast';
import './SupportTickets.css';

const SupportCenter = () => {
    // 🚦 STATE COMMAND
    const [activeTab, setActiveTab] = useState('OPERATIONAL'); // OPERATIONAL, CHATS, TICKETS, REFUNDS, FAQS, ANALYTICS
    const [loading, setLoading] = useState(true);
    const [searchQuery, setSearchQuery] = useState('');

    // Live Data Storage
    const [chats, setChats] = useState([]);
    const [opChats, setOpChats] = useState([]); // Order Specific Chats
    const [tickets, setTickets] = useState([]);
    const [refunds, setRefunds] = useState([]);
    const [faqs, setFaqs] = useState([]);
    const [notifications, setNotifications] = useState([]);
    const [showBroadcastModal, setShowBroadcastModal] = useState(false);
    const [broadcastData, setBroadcastData] = useState({
        title: '',
        message: '',
        role: 'customer',
        type: 'promotion',
        user_id: '',
        order_id: ''
    });

    // Selection Management
    const [selectedItem, setSelectedItem] = useState(null);
    const [messages, setMessages] = useState([]);
    const [newMessage, setNewMessage] = useState('');
    const [sending, setSending] = useState(false);
    const [filterType, setFilterType] = useState('ALL'); // ALL, CUSTOMER, VENDOR, RIDER

    // 📡 NEURAL LINK (Mount)
    useEffect(() => {
        const initializeSystem = async () => {
            setLoading(true);
            await Promise.all([
                fetchChats(),
                fetchOpChats(),
                fetchTickets(),
                fetchRefunds(),
                fetchFaqs(),
                fetchNotifications()
            ]);
            setLoading(false);
        };

        initializeSystem();

        // Establish Real-time Handshakes
        const channel = supabase.channel('support-neural-pulse-v16')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'support_chats' }, fetchChats)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'chat_messages' }, fetchOpChats)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'support_tickets' }, fetchTickets)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'refund_requests' }, fetchRefunds)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'faqs' }, fetchFaqs)
            .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications' }, (payload) => {
                fetchNotifications();
                toast.success(`NEW SYSTEM ALERT: ${payload.new.title}`, { icon: '🔔' });
            })
            .subscribe();

        return () => supabase.removeChannel(channel);
    }, []);

    // 📩 MESSAGE RELAY
    useEffect(() => {
        if (!selectedItem || (activeTab !== 'CHATS' && activeTab !== 'TICKETS' && activeTab !== 'OPERATIONAL')) return;

        let table, foreignKey;
        if (activeTab === 'CHATS') {
            table = 'support_messages';
            foreignKey = 'chat_id';
        } else if (activeTab === 'TICKETS') {
            table = 'ticket_messages';
            foreignKey = 'ticket_id';
        } else {
            table = 'chat_messages';
            foreignKey = 'order_id';
        }

        fetchMessages(selectedItem.id, table, foreignKey);

        const sub = supabase.channel(`relay-${selectedItem.id}`)
            .on('postgres_changes', {
                event: 'INSERT',
                schema: 'public',
                table: table,
            }, (payload) => {
                // 🛡️ REPAIR: Robust ID comparison (handles case/type mismatches)
                const payloadId = payload.new[foreignKey]?.toString().toLowerCase();
                const currentId = selectedItem.id.toString().toLowerCase();

                if (payloadId === currentId) {
                    setMessages(prev => [...prev, payload.new]);
                }
            })
            .subscribe((status) => {
                if (status === 'SUBSCRIBED') {
                    console.log(`📡 NEURAL LINK ACTIVE: Subscribed to ${table} for ${selectedItem.id}`);
                }
            });

        return () => supabase.removeChannel(sub);
    }, [selectedItem, activeTab]);

    // 🛰️ DATA ACQUISITION
    const fetchChats = async () => {
        const { data: rawChats } = await supabase.from('support_chats')
            .select('*')
            .order('updated_at', { ascending: false });

        if (rawChats) {
            const userIds = [...new Set(rawChats.map(c => c.user_id?.toString()).filter(Boolean))];
            const { data: pData } = await supabase.from('customer_profiles').select('id, full_name, phone').in('id', userIds);
            const pMap = Object.fromEntries((pData || []).map(p => [p.id?.toString(), p]));

            const mapped = rawChats.map(c => ({
                ...c,
                display_name: pMap[c.user_id?.toString()]?.full_name || 'Guest User',
                display_phone: pMap[c.user_id?.toString()]?.phone || 'No Phone'
            }));
            setChats(mapped);
        }
    };

    const fetchOpChats = async () => {
        // 🚦 REPAIR: Manual mapping to avoid join failures
        const { data: rawMsgs, error: msgErr } = await supabase.from('chat_messages')
            .select('order_id')
            .order('created_at', { ascending: false });

        if (rawMsgs) {
            const orderIds = [...new Set(rawMsgs.map(m => m.order_id?.toString()).filter(Boolean))];

            const [{ data: oData }, { data: vData }] = await Promise.all([
                supabase.from('orders').select('id, status, vendor_id').in('id', orderIds),
                supabase.from('vendors').select('id, name')
            ]);

            const oMap = Object.fromEntries((oData || []).map(o => [o.id?.toString(), o]));
            const vMap = Object.fromEntries((vData || []).map(v => [v.id?.toString(), v.name]));

            const unique = orderIds.map(oid => {
                const order = oMap[oid];
                return {
                    id: oid,
                    subject: `ORDER: ${vMap[order?.vendor_id?.toString()] || 'Local Store'}`,
                    role: 'OPERATIONAL',
                    status: order?.status || 'active'
                };
            });
            setOpChats(unique);
        }
    };

    const fetchTickets = async () => {
        // 🚦 REPAIR: Manual mapping for Support Tickets
        const { data: rawTickets, error: tErr } = await supabase.from('support_tickets')
            .select('*')
            .order('created_at', { ascending: false });

        if (rawTickets) {
            const userIds = [...new Set(rawTickets.map(t => t.user_id?.toString()).filter(Boolean))];
            const { data: pData } = await supabase.from('customer_profiles').select('id, full_name, phone').in('id', userIds);
            const pMap = Object.fromEntries((pData || []).map(p => [p.id?.toString(), p]));

            const mapped = rawTickets.map(t => ({
                ...t,
                display_name: pMap[t.user_id?.toString()]?.full_name || 'Guest User',
                display_phone: pMap[t.user_id?.toString()]?.phone || 'No Phone',
                customer_profiles: {
                    full_name: pMap[t.user_id?.toString()]?.full_name || 'Guest User',
                    phone: pMap[t.user_id?.toString()]?.phone || 'No Phone'
                }
            }));
            setTickets(mapped);
        }
    };

    const fetchRefunds = async () => {
        const { data: rawRefunds } = await supabase.from('refund_requests')
            .select('*')
            .order('created_at', { ascending: false });

        if (rawRefunds) {
            const userIds = [...new Set(rawRefunds.map(r => r.user_id?.toString()).filter(Boolean))];
            const { data: pData } = await supabase.from('customer_profiles').select('id, full_name, phone').in('id', userIds);
            const pMap = Object.fromEntries((pData || []).map(p => [p.id?.toString(), p]));

            const mapped = rawRefunds.map(r => ({
                ...r,
                display_name: pMap[r.user_id?.toString()]?.full_name || 'Guest User',
                display_phone: pMap[r.user_id?.toString()]?.phone || 'No Phone'
            }));
            setRefunds(mapped);
        }
    };

    const fetchFaqs = async () => {
        const { data } = await supabase.from('faqs')
            .select('*')
            .order('usage_count', { ascending: false });
        if (data) setFaqs(data);
    };

    const fetchNotifications = async () => {
        const { data } = await supabase.from('notifications')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(50);
        if (data) setNotifications(data);
    };

    const sendBroadcast = async (e) => {
        e.preventDefault();
        setSending(true);
        try {
            const { title, message, role, type, user_id, order_id } = broadcastData;

            // Logic for targeted vs broadcast
            // If user_id is empty, we handle it as a broadcast (requires backend processing for multi-insert)
            // For now, we follow the user rule: backend insertion triggered by admin

            const payload = {
                title,
                message,
                user_role: role,
                type: type.toUpperCase(),
                user_id: user_id || 'BROADCAST',
                order_id: order_id || null,
                is_read: false
            };

            const { error } = await supabase.from('notifications').insert(payload);

            if (error) throw error;

            toast.success("NOTIFICATION DISPATCHED");
            setShowBroadcastModal(false);
            setBroadcastData({ title: '', message: '', role: 'customer', type: 'promotion', user_id: '', order_id: '' });
        } catch (err) {
            toast.error("Dispatch Failed: " + err.message);
        } finally {
            setSending(false);
        }
    };

    const fetchMessages = async (id, table, fk) => {
        const { data } = await supabase.from(table)
            .select('*')
            .eq(fk, id)
            .order('created_at', { ascending: true });
        if (data) setMessages(data);
    };

    // 🏗️ ACTIONS
    const transmitMessage = async (e) => {
        e.preventDefault();
        const msgToSend = newMessage.trim();
        if (!msgToSend || !selectedItem || sending) return;

        // 🚀 OPTIMISTIC CLEAR: Clear immediately for premium feel
        setNewMessage('');
        setSending(true);

        const isOp = activeTab === 'OPERATIONAL';
        const isChat = activeTab === 'CHATS';
        const isTicket = activeTab === 'TICKETS';

        let table, fk;
        if (isChat) { table = 'support_messages'; fk = 'chat_id'; }
        else if (isOp) { table = 'chat_messages'; fk = 'order_id'; }
        else { table = 'ticket_messages'; fk = 'ticket_id'; }

        try {
            const { data: { session } } = await supabase.auth.getSession();
            const senderId = session?.user?.id || 'demo-admin-id';

            // 🎯 SCHEMA-SPECIFIC PAYLOADS: Only send columns that exist in each table
            let payload = {
                [fk]: selectedItem.id,
                sender_id: senderId.toString(),
                message: msgToSend
            };

            if (isChat) {
                payload.sender_type = 'AGENT'; // support_messages uses sender_type
            } else if (isOp) {
                payload.sender_role = 'ADMIN'; // chat_messages uses sender_role
            } else if (isTicket) {
                payload.is_admin = true;      // ticket_messages uses is_admin
            }

            const { error } = await supabase.from(table).insert(payload);

            if (error) {
                console.error(`Transmitter Fault [${table}]:`, error);
                toast.error(`Neural Pulse Interrupted: ${error.message}`);
                setNewMessage(msgToSend); // Restore on failure
            }
        } catch (err) {
            console.error("System Crash:", err);
            toast.error("Critical System Conflict");
            setNewMessage(msgToSend);
        } finally {
            setSending(false);
        }
    };

    const updateStatus = async (table, id, status) => {
        // 🚦 TACTICAL ROUTING: Orders might use 'status' or 'order_status'
        const updatePayload = { status };
        if (table === 'orders') {
            updatePayload.order_status = status;
        }

        const { error } = await supabase.from(table).update(updatePayload).eq('id', id);
        if (error) {
            // Fallback for older order schema if needed
            if (table === 'orders') {
                await supabase.from(table).update({ order_status: status }).eq('id', id);
            }
            toast.error(error.message);
        }
        else toast.success(`Status updated to ${status}`);
    };

    // Filtered Content Logic
    const filteredChats = chats.filter(c => {
        const query = searchQuery.toLowerCase();
        const matchesSearch = c.id.toLowerCase().includes(query) ||
            (c.subject || '').toLowerCase().includes(query) ||
            (c.display_name || '').toLowerCase().includes(query) ||
            (c.display_phone || '').toLowerCase().includes(query);
        const matchesType = filterType === 'ALL' || c.user_type === filterType;
        return matchesSearch && matchesType;
    });

    // 🎨 UI RENDERING COMPONENTS

    const renderChatTheatre = () => (
        <div className="transmission-core">
            <header className="transmission-header">
                <div>
                    <h3 style={{ margin: 0 }}>{selectedItem.display_name || selectedItem.subject || 'LIVE SESSION'}</h3>
                    <p style={{ margin: 0, fontSize: '0.75rem', color: '#64748b' }}>
                        ID: {selectedItem.id.slice(0, 8)} • PHONE: {selectedItem.display_phone || 'N/A'} • TYPE: {selectedItem.user_type || selectedItem.role}
                    </p>
                </div>
                <div style={{ display: 'flex', gap: '10px' }}>
                    <button
                        onClick={() => updateStatus(
                            activeTab === 'CHATS' ? 'support_chats' :
                                activeTab === 'OPERATIONAL' ? 'orders' : 'support_tickets',
                            selectedItem.id,
                            activeTab === 'OPERATIONAL' ? 'delivered' : 'RESOLVED'
                        )}
                        className="action-btn-resolved"
                    >
                        <Check size={16} /> {activeTab === 'OPERATIONAL' ? 'Force Delivered' : 'Mark Resolved'}
                    </button>
                    {(activeTab === 'CHATS' || activeTab === 'TICKETS' || activeTab === 'OPERATIONAL') && (
                        <button
                            onClick={() => updateStatus(
                                activeTab === 'CHATS' ? 'support_chats' :
                                    activeTab === 'OPERATIONAL' ? 'orders' : 'support_tickets',
                                selectedItem.id,
                                'HUMAN'
                            )}
                            className="action-btn-intervene"
                        >
                            <User size={16} /> Intervene
                        </button>
                    )}
                </div>
            </header>

            <div className="theatre-scroll">
                {messages.map((m, i) => {
                    const isSent = m.sender_role === 'ADMIN' ||
                        m.sender_type === 'AGENT' ||
                        m.is_admin === true ||
                        m.sender_id === 'demo-admin-id';

                    return (
                        <div key={i} className={`bubble-wrap ${isSent ? 'sent' : 'received'}`}>
                            <div className="bubble">
                                {m.message}
                            </div>
                            <div className="bubble-meta">
                                {m.sender_role || m.sender_type || (m.is_admin ? 'ADMIN' : 'USER')} • {new Date(m.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                            </div>
                        </div>
                    );
                })}
            </div>

            <form onSubmit={transmitMessage} className="control-hub">
                <div className="input-neural">
                    <input
                        placeholder="Enter command or response..."
                        value={newMessage}
                        onChange={e => setNewMessage(e.target.value)}
                    />
                </div>
                <button type="submit" className="btn-transmit" disabled={sending} style={{ opacity: sending ? 0.5 : 1 }}>
                    <Send size={20} className={sending ? 'pulse' : ''} />
                </button>
            </form>
        </div>
    );

    const renderFaqIntel = () => (
        <div className="faq-intel-unit">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
                <h2 style={{ fontWeight: 900 }}>NEURAL FAQ DATA</h2>
                <button className="tab-pill active"><Plus size={16} /> ADD INTEL</button>
            </div>
            {faqs.map(faq => (
                <div key={faq.id} className="faq-card">
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <h4 style={{ margin: '0 0 10px 0', color: '#0f172a' }}>{faq.question}</h4>
                        <span className="count-badge">{faq.usage_count} Hits</span>
                    </div>
                    <p style={{ color: '#64748b', fontSize: '0.9rem' }}>{faq.answer}</p>
                    <div style={{ display: 'flex', gap: '8px', marginTop: '12px' }}>
                        {faq.keywords?.map((k, i) => (
                            <span key={i} style={{ background: '#f1f5f9', padding: '4px 8px', borderRadius: '6px', fontSize: '0.7rem', fontWeight: 700 }}>{k}</span>
                        ))}
                    </div>
                </div>
            ))}
        </div>
    );

    const renderRefundControl = () => (
        <div className="refund-grid">
            {refunds.map(ref => (
                <div key={ref.id} className="refund-card">
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                        <span style={{ fontWeight: 900, color: '#94a3b8', fontSize: '0.7rem' }}>#{ref.id.slice(0, 8)}</span>
                        <span className={`count-badge`} style={{ background: ref.status === 'PENDING' ? '#fef3c7' : '#ecfdf5', color: ref.status === 'PENDING' ? '#b45309' : '#10b981' }}>
                            {ref.status}
                        </span>
                    </div>
                    <div style={{ marginBottom: '12px' }}>
                        <h4 style={{ margin: 0, fontSize: '0.9rem' }}>{ref.display_name}</h4>
                        <p style={{ margin: 0, fontSize: '0.75rem', color: '#64748b', fontWeight: 700 }}>{ref.display_phone}</p>
                    </div>
                    <h3 style={{ margin: '0 0 8px 0' }}>₹{ref.amount}</h3>
                    <p style={{ margin: '0 0 16px 0', fontSize: '0.8rem', color: '#64748b' }}>{ref.reason}</p>
                    {ref.status === 'PENDING' && (
                        <div style={{ display: 'flex', gap: '10px' }}>
                            <button onClick={() => updateStatus('refund_requests', ref.id, 'APPROVED')} className="tab-pill" style={{ background: '#10b981', color: 'white', border: 'none', flex: 1 }}>APPROVE</button>
                            <button onClick={() => updateStatus('refund_requests', ref.id, 'REJECTED')} className="tab-pill" style={{ borderColor: '#ef4444', color: '#ef4444', flex: 1 }}>REJECT</button>
                        </div>
                    )}
                </div>
            ))}
        </div>
    );

    const renderNotificationFeed = () => (
        <div className="notification-intel-grid">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                <h2 style={{ fontWeight: 900 }}>SYSTEM ALERTS & LOGS</h2>
                <div style={{ display: 'flex', gap: '10px' }}>
                    <button onClick={() => setShowBroadcastModal(true)} className="tab-pill" style={{ background: '#3b82f6', color: 'white', border: 'none' }}>
                        <Plus size={16} /> DISPATCH ALERT
                    </button>
                    <button onClick={() => supabase.from('notifications').update({ is_read: true }).eq('user_role', 'admin')} className="tab-pill">MARK ALL READ</button>
                </div>
            </div>

            {showBroadcastModal && (
                <div className="modal-overlay">
                    <motion.div initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} className="broadcast-modal">
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '20px' }}>
                            <h3 style={{ fontWeight: 900 }}>DISPATCH MISSION CONTROL</h3>
                            <button onClick={() => setShowBroadcastModal(false)} className="btn-close"><X size={20} /></button>
                        </div>
                        <form onSubmit={sendBroadcast} style={{ display: 'flex', flex_direction: 'column', gap: '16px' }}>
                            <div className="input-field">
                                <label>TITLE</label>
                                <input required placeholder="Flashy title..." value={broadcastData.title} onChange={e => setBroadcastData({ ...broadcastData, title: e.target.value })} />
                            </div>
                            <div className="input-field">
                                <label>MESSAGE</label>
                                <textarea required rows="3" placeholder="Mission details..." value={broadcastData.message} onChange={e => setBroadcastData({ ...broadcastData, message: e.target.value })}></textarea>
                            </div>
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                                <div className="input-field">
                                    <label>TARGET AUDIENCE</label>
                                    <select value={broadcastData.role} onChange={e => setBroadcastData({ ...broadcastData, role: e.target.value })}>
                                        <option value="customer">CUSTOMERS</option>
                                        <option value="vendor">VENDORS</option>
                                        <option value="delivery">DELIVERY</option>
                                        <option value="admin">ADMINS</option>
                                    </select>
                                </div>
                                <div className="input-field">
                                    <label>ALERT TYPE</label>
                                    <select value={broadcastData.type} onChange={e => setBroadcastData({ ...broadcastData, type: e.target.value })}>
                                        <option value="promotion">PROMOTION</option>
                                        <option value="system">SYSTEM ALERT</option>
                                        <option value="order_update">ORDER UPDATE</option>
                                        <option value="payment">PAYMENT</option>
                                    </select>
                                </div>
                            </div>
                            <div className="input-field">
                                <label>USER ID (OPTIONAL - EMPTY FOR ALL)</label>
                                <input placeholder="Specific target ID..." value={broadcastData.user_id} onChange={e => setBroadcastData({ ...broadcastData, user_id: e.target.value })} />
                            </div>
                            <button type="submit" disabled={sending} className="btn-transmit" style={{ width: '100%', marginTop: '10px' }}>
                                {sending ? 'TRANSMITTING...' : 'DISPATCH NOW'}
                            </button>
                        </form>
                    </motion.div>
                </div>
            )}
            {notifications.length === 0 ? (
                <div style={{ padding: '60px', textAlign: 'center', opacity: 0.3 }}>
                    <ShieldAlert size={48} style={{ marginBottom: '16px' }} />
                    <p>SYSTEM QUIET. NO RECENT ALERTS.</p>
                </div>
            ) : (
                <div className="notif-scroll">
                    {notifications.map(notif => (
                        <div key={notif.id} className={`notification-pulse-card ${notif.is_read ? 'read' : 'unread'}`}>
                            <div className="pulse-icon">
                                {notif.type === 'ORDER_STATUS' ? <Truck size={18} /> :
                                    notif.type === 'CHAT_MESSAGE' ? <MessageSquare size={18} /> : <AlertCircle size={18} />}
                            </div>
                            <div className="pulse-content">
                                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                    <h4 style={{ margin: 0 }}>{notif.title}</h4>
                                    <span style={{ fontSize: '0.65rem', fontWeight: 700, color: '#94a3b8' }}>{new Date(notif.created_at).toLocaleString()}</span>
                                </div>
                                <p style={{ margin: '4px 0', fontSize: '0.85rem', color: '#475569' }}>{notif.message}</p>
                                {notif.order_id && (
                                    <button
                                        className="btn-link"
                                        onClick={() => {
                                            setActiveTab('OPERATIONAL');
                                            setSelectedItem({ id: notif.order_id });
                                        }}
                                    >
                                        VIEW ORDER #{notif.order_id.slice(0, 8)}
                                    </button>
                                )}
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );

    const renderAnalytics = () => (
        <div>
            <div className="metrics-row">
                <div className="metric-card">
                    <h5>Avg Response Time</h5>
                    <div className="metric-value">4.2m</div>
                </div>
                <div className="metric-card">
                    <h5>Bot Resolution</h5>
                    <div className="metric-value">68%</div>
                </div>
                <div className="metric-card">
                    <h5>Active Chats</h5>
                    <div className="metric-value">{chats.filter(c => c.status !== 'RESOLVED').length}</div>
                </div>
                <div className="metric-card">
                    <h5>Refund Rate</h5>
                    <div className="metric-value">1.2%</div>
                </div>
            </div>
        </div>
    );

    return (
        <div className="support-command-center">
            {/* 🏎️ COMMAND TABS */}
            <div className="command-tabs">
                {[
                    { id: 'OPERATIONAL', label: 'Order Chat Ops', icon: <Truck size={16} />, count: opChats.length },
                    { id: 'CHATS', label: 'Support Terminal', icon: <MessageSquare size={16} />, count: chats.filter(c => c.status !== 'RESOLVED').length },
                    { id: 'TICKETS', label: 'Legacy Tickets', icon: <Ticket size={16} />, count: tickets.filter(t => t.status !== 'RESOLVED').length },
                    { id: 'REFUNDS', label: 'Refund Hub', icon: <DollarSign size={16} />, count: refunds.filter(r => r.status === 'PENDING').length },
                    { id: 'FAQS', label: 'Bot Intelligence', icon: <Brain size={16} />, count: faqs.length },
                    { id: 'NOTIFICATIONS', label: 'Pulse Hub', icon: <ShieldAlert size={16} />, count: notifications.filter(n => !n.is_read).length },
                    { id: 'ANALYTICS', label: 'Performance', icon: <BarChart3 size={16} /> }
                ].map(tab => (
                    <button
                        key={tab.id}
                        className={`tab-pill ${activeTab === tab.id ? 'active' : ''}`}
                        onClick={() => { setActiveTab(tab.id); setSelectedItem(null); }}
                    >
                        {tab.icon} {tab.label}
                        {tab.count > 0 && <span className="count-badge">{tab.count}</span>}
                    </button>
                ))}
            </div>

            <div className="workspace-layer">
                {/* 📁 ASIDE LIST */}
                {(activeTab === 'CHATS' || activeTab === 'TICKETS' || activeTab === 'OPERATIONAL') && (
                    <div className="support-aside">
                        <div className="support-aside-header">
                            {activeTab !== 'OPERATIONAL' && <div style={{ display: 'flex', gap: '8px', marginBottom: '16px', overflowX: 'auto', paddingBottom: '4px' }}>
                                {['ALL', 'CUSTOMER', 'VENDOR', 'RIDER'].map(type => (
                                    <button
                                        key={type}
                                        onClick={() => setFilterType(type)}
                                        className={`tab-pill ${filterType === type ? 'active' : ''}`}
                                        style={{ fontSize: '0.65rem', padding: '6px 12px' }}
                                    >
                                        {type}
                                    </button>
                                ))}
                            </div>}
                            <div className="search-neural">
                                <Search size={18} color="#94a3b8" />
                                <input placeholder="Filter active relays..." value={searchQuery} onChange={e => setSearchQuery(e.target.value)} />
                            </div>
                        </div>
                        <div className="aside-scroll">
                            {(activeTab === 'OPERATIONAL' ? opChats : (activeTab === 'CHATS' ? filteredChats : tickets)).length === 0 ? (
                                <div style={{ padding: '40px 20px', textAlign: 'center', opacity: 0.5 }}>
                                    <p style={{ fontSize: '0.7rem', fontWeight: 900, letterSpacing: '1px' }}>ZERO ACTIVE RELAYS</p>
                                </div>
                            ) : (
                                (activeTab === 'OPERATIONAL' ? opChats : (activeTab === 'CHATS' ? filteredChats : tickets)).map(item => (
                                    <div
                                        key={item.id}
                                        className={`entity-node ${selectedItem?.id === item.id ? 'active' : ''}`}
                                        onClick={() => setSelectedItem(item)}
                                    >
                                        <div className="node-top">
                                            <span>#{item.id.slice(0, 8)}</span>
                                            <div className={`node-status-dot ${item.status?.toLowerCase()}`}></div>
                                        </div>
                                        <h4>{item.display_name || item.subject || 'Mission Relay'}</h4>
                                        <p style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                                            {(item.user_type || item.role) === 'VENDOR' ? <Store size={12} /> : (item.user_type || item.role) === 'RIDER' ? <Truck size={12} /> : <User size={12} />}
                                            <span className="phone-tag">{item.display_phone || 'No Phone'}</span>
                                        </p>
                                    </div>
                                ))
                            )}
                        </div>
                    </div>
                )}

                {/* 🎭 MAIN DASHBOARD AREA */}
                <div className="main-theatre">
                    {selectedItem ? (
                        activeTab === 'CHATS' || activeTab === 'TICKETS' || activeTab === 'OPERATIONAL' ? renderChatTheatre() : null
                    ) : (
                        activeTab === 'CHATS' || activeTab === 'TICKETS' || activeTab === 'OPERATIONAL' ? (
                            <div className="theatre-welcome">
                                <div className="icon-shield"><ShieldAlert size={40} /></div>
                                <h2>Terminal Ready</h2>
                                <p>Establish a secure communication link by selecting an active tactical relay from the sidebar.</p>
                            </div>
                        ) : activeTab === 'FAQS' ? renderFaqIntel() :
                            activeTab === 'REFUNDS' ? renderRefundControl() :
                                activeTab === 'NOTIFICATIONS' ? renderNotificationFeed() :
                                    activeTab === 'ANALYTICS' ? renderAnalytics() : null
                    )}
                </div>
            </div>
        </div>
    );
};

export default SupportCenter;
