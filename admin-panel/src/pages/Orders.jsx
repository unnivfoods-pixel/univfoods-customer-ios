import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ShoppingBag, Clock, MapPin, CheckCircle, XCircle, Truck, Phone, Search, Filter, ArrowRight, User, Hash, Star, UserPlus, RefreshCw, AlertCircle, CreditCard } from 'lucide-react';
import { supabase } from '../supabase';
import { COLLECTIONS } from '../constants';
import { toast } from 'react-hot-toast';
import MissionMap from '../components/MissionMap';
import './Orders.css';

const Orders = () => {
    const [orders, setOrders] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [activeTab, setActiveTab] = useState('ALL');
    const [riders, setRiders] = useState([]);
    const [showRiderModal, setShowRiderModal] = useState(null);
    const [showMap, setShowMap] = useState(false);

    useEffect(() => {
        fetchOrders();
        fetchRiders();
        const sub = supabase.channel('logistics-live-extreme')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, fetchOrders)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'order_live_tracking' }, fetchOrders)
            .subscribe();
        return () => sub.unsubscribe();
    }, []);

    const fetchOrders = async () => {
        try {
            // 🛑 REPAIR: Using separate calls + client-side mapping to avoid PGRST200 Join failures
            const { data: rawOrders, error: orderErr } = await supabase
                .from('orders')
                .select('*')
                .order('created_at', { ascending: false })
                .limit(100);

            if (orderErr) throw orderErr;

            // 🎯 REPAIR: Targeted Profile Recovery (only for IDs in current batch)
            let profileMap = {};
            if (rawOrders?.length > 0) {
                try {
                    const uniqueIds = [...new Set(rawOrders.map(o => o.customer_id || o.user_id).filter(Boolean))];
                    if (uniqueIds.length > 0) {
                        const { data: pData } = await supabase
                            .from('customer_profiles')
                            .select('id, full_name, phone')
                            .in('id', uniqueIds);

                        (pData || []).forEach(p => {
                            if (p.id) profileMap[p.id.toString()] = p;
                        });
                    }
                } catch (pErr) {
                    console.warn("Logistics identity enrichment partially offline (Customer Profiles restricted)");
                }
            }

            const [{ data: vData }, { data: rData }] = await Promise.all([
                supabase.from('vendors').select('id, name'),
                supabase.from('delivery_riders').select('id, name, phone')
            ]);

            const vendorMap = Object.fromEntries((vData || []).map(v => [v.id?.toString(), v.name]));
            const riderMap = Object.fromEntries((rData || []).map(r => [r.id?.toString(), r]));

            if (rawOrders) {
                const synchronized = rawOrders.map(o => {
                    const profId = (o.customer_id || o.user_id || '').toString();

                    // 🔑 Extract phone from sms_auth_ IDs (handles sms_auth_8897868951 AND sms_auth_918897868951)
                    let smsAuthPhone = '';
                    if (profId.startsWith('sms_auth_')) {
                        const digits = profId.replace('sms_auth_', '').replace(/^91/, ''); // strip 91 prefix
                        if (/^\d{10}$/.test(digits)) smsAuthPhone = digits;
                    }

                    const prof = profileMap[profId] ||
                        profileMap[smsAuthPhone] ||          // Look up by extracted phone
                        profileMap[o.delivery_phone] ||
                        profileMap[o.customer_phone];
                    const rider = riderMap[o.rider_id?.toString()];

                    // Master Identity Sanitization
                    const isSafe = (str) => {
                        if (!str || typeof str !== 'string' || !str.trim()) return false;
                        const s = str.trim();
                        if (s.length < 3) return false;
                        if (s.length > 20 && /[a-zA-Z]/.test(s) && /\d/.test(s)) return false;
                        return true;
                    };

                    const safePhone = (str) => {
                        const clean = (str || '').toString().trim();
                        return /^\+?[\d\s-]{10,}$/.test(clean) && !/[a-zA-Z]/.test(clean) ? clean : '';
                    };

                    // Aggregate sources for Phone — smsAuthPhone as extra fallback
                    const rawPhone = safePhone(o.delivery_phone) ||
                        safePhone(o.customer_phone) ||
                        safePhone(o.customer_phone_snapshot) ||
                        safePhone(prof?.phone) ||
                        smsAuthPhone ||                      // ← phone from sms_auth_ ID
                        (safePhone(profId) ? profId : '');

                    // Aggregate sources for Name
                    const rawName = (isSafe(prof?.full_name) ? prof.full_name : null) ||
                        (isSafe(o.customer_name) ? o.customer_name : null) ||
                        (isSafe(o.customer_name_snapshot) ? o.customer_name_snapshot : null) || null;

                    const finalName = (isSafe(rawName) ? rawName : null) || (rawPhone ? `📞 ${rawPhone}` : 'Unknown Customer');

                    let pinFallback = o.delivery_pincode;
                    if (!pinFallback && o.address) {
                        const pinMatch = o.address.match(/\b\d{6}\b/);
                        if (pinMatch) pinFallback = pinMatch[0];
                    }
                    const finalPhone = rawPhone || safePhone(o.delivery_phone) || o.delivery_phone || '';


                    // Normalize price: DB uses total_amount, legacy uses total
                    const resolvedTotal = o.total_amount || o.total || 0;

                    return {
                        ...o,
                        order_id: o.id,
                        total: resolvedTotal,
                        total_amount: resolvedTotal,
                        vendor_name: vendorMap[o.vendor_id?.toString()] || o.vendor_name || 'UNIV Station',
                        rider_name: rider?.name || o.rider_name || null,
                        rider_phone: rider?.phone || o.rider_phone || '',
                        customer_name: finalName,
                        customer_phone: finalPhone,
                        display_pin: pinFallback,
                        raw_id: profId
                    };
                });
                setOrders(synchronized);
            }
        } catch (err) {
            console.error('Logistics Heartbeat Failure:', err);
            toast.error("Logistics Grid Sync Failed: Check Supabase RLS");
        } finally {
            setLoading(false);
        }
    };

    const fetchRiders = async () => {
        const { data } = await supabase.from('delivery_riders').select('*').eq('status', 'Online');
        if (data) setRiders(data);
    };

    const updateStatus = async (id, status, extra = {}) => {
        const upperStatus = status.toUpperCase();
        try {
            // 1. RPC call (updates status + order_status via fixed function)
            const { error } = await supabase.rpc('update_order_status_v3', {
                p_order_id: id,
                p_new_status: upperStatus
            });

            if (error) {
                // Fallback: Direct update if RPC fails
                console.warn('RPC failed, using direct update:', error.message);
                const { error: directErr } = await supabase.from('orders')
                    .update({ status: upperStatus, order_status: upperStatus, updated_at: new Date().toISOString() })
                    .eq('id', id);
                if (directErr) throw directErr;
            }

            if (Object.keys(extra).length > 0) {
                await supabase.from('orders').update(extra).eq('id', id);
            }

            toast.success(`✅ Status → ${upperStatus}`);
            fetchOrders();
        } catch (error) {
            console.error('Update Failed:', error);
            toast.error(`❌ Failed: ${error.message}`);
        }
    };

    const assignRider = async (orderId, riderId) => {
        try {
            // 1. Link Rider to Order
            const { error: ordErr } = await supabase.from('orders').update({
                rider_id: riderId,
                status: 'rider_assigned',
                assigned_at: new Date().toISOString()
            }).eq('id', orderId);

            if (ordErr) throw ordErr;

            // 2. Lock Rider to Order
            const { error: ridErr } = await supabase.from('delivery_riders').update({
                status: 'Busy'
            }).eq('id', riderId);

            if (ridErr) throw ridErr;

            toast.success("Logistics Link Established: Rider Assigned.");
            setShowRiderModal(null);
            fetchOrders();
        } catch (error) {
            toast.error(`Assignment Fault: ${error.message}`);
        }
    };

    const summonSimulationRider = async () => {
        const riderId = 'SIM-RIDER-' + Math.floor(Math.random() * 1000);
        const { error } = await supabase.from('delivery_riders').upsert([{
            id: riderId,
            name: "Simulation Rider " + Math.floor(Math.random() * 100),
            phone: "+91 90000 00000",
            status: 'Online',
            is_online: true,
            current_lat: 9.5120,
            current_lng: 77.6320
        }]);
        if (error) toast.error("Summoning Failed: " + error.message);
        else {
            toast.success("Simulation Unit Summoned to Grid.");
            fetchRiders();
        }
    };

    const initiateRefund = async (order) => {
        const { error } = await supabase.from('refunds').insert({
            order_id: order.id,
            amount: parseFloat(order.total) || 0,
            status: 'PENDING',
            reason: 'Admin Initiated Force Refund'
        });
        if (error) toast.error("Refund Engine Fault: " + error.message);
        else toast.success("Capital Flow Reversed. Refund Signal Sent.");
    };

    const simulateOrder = async () => {
        const loadingToast = toast.loading("Provisioning Logistics Chain...");
        try {
            // 1. Get/Create a vendor
            let { data: vendors } = await supabase.from('vendors').select('id, name').limit(1);
            let vendor = vendors?.[0];

            if (!vendor) {
                const { data: newVendor, error: vErr } = await supabase.from('vendors').insert({
                    name: "Genesis Kitchen (Auto-Provisioned)",
                    address: "Srivilliputhur Digital Node",
                    status: 'ONLINE',
                    cuisine_type: 'North Indian',
                    rating: 5.0
                }).select().single();
                if (vErr) throw new Error("Vendor Provisioning Failed: " + vErr.message);
                vendor = newVendor;
            }

            const testOrder = {
                id: 'ORD-' + Math.random().toString(36).substr(2, 9).toUpperCase(),
                total: Math.floor(Math.random() * 500) + 150,
                status: 'pending',
                payment_method: 'UPI',
                payment_status: 'SUCCESS',
                vendor_id: vendor?.id || null,
                customer_id: null,
                customer_name: "Simulation Guest",
                customer_phone: "+91 88888 77777",
                delivery_address: "123 Beta Sector, Logistics Node Alpha",
                delivery_pincode: "600001",
                delivery_house_number: "Suite 505",
                delivery_phone: "+91 88888 77777",
                vendor_lat: 9.5120,
                vendor_lng: 77.6320,
                delivery_lat: 9.5150,
                delivery_lng: 77.6350,
                created_at: new Date().toISOString()
            };

            const { error } = await supabase.from('orders').insert(testOrder);
            if (error) throw error;

            toast.success(`Grid Online! Linked to ${vendor?.name}`, { id: loadingToast });
            fetchOrders();
        } catch (err) {
            toast.error(err.message, { id: loadingToast });
        }
    };

    const statusColors = {
        'PLACED': { bg: '#fff7ed', text: '#9a3412', dot: '#f97316', label: 'IN QUEUE' },
        'PENDING': { bg: '#fff7ed', text: '#9a3412', dot: '#f97316', label: 'IN QUEUE' },
        'ACCEPTED': { bg: '#e0f2fe', text: '#0369a1', dot: '#0ea5e9', label: 'ACCEPTED' },
        'RIDER_ASSIGNED': { bg: '#e0f2fe', text: '#0369a1', dot: '#0ea5e9', label: 'DISPATCHED' },
        'PREPARING': { bg: '#fef9c3', text: '#854d0e', dot: '#eab308', label: 'KITCHEN' },
        'READY': { bg: '#f0fdf4', text: '#166534', dot: '#22c55e', label: 'READY' },
        'PICKED_UP': { bg: '#f5f3ff', text: '#5b21b6', dot: '#8b5cf6', label: 'PICKED UP' },
        'ON_THE_WAY': { bg: '#ebf5ff', text: '#1e40af', dot: '#3b82f6', label: 'ON THE WAY' },
        'OUT_FOR_DELIVERY': { bg: '#f5f3ff', text: '#5b21b6', dot: '#8b5cf6', label: 'IN TRANSIT' },
        'DELIVERED': { bg: '#dcfce7', text: '#14532d', dot: '#10b981', label: 'COMPLETED' },
        'CANCELLED': { bg: '#fef2f2', text: '#991b1b', dot: '#ef4444', label: 'REJECTED' },
        'CONFIRMED': { bg: '#e0f2fe', text: '#0369a1', dot: '#0ea5e9', label: 'CONFIRMED' }
    };

    const getStatusStyle = (status) => {
        const s = (status || 'PLACED').toString().toUpperCase();
        return statusColors[s] || statusColors.PLACED;
    };

    const filtered = orders.filter(o => {
        const orderId = (o.order_id || o.id || '').toLowerCase();
        const vendorName = (o.vendor_name || o.vendor_id || '').toLowerCase();
        const customerName = (o.customer_name || o.customer_id || '').toLowerCase();

        const matchesSearch = orderId.includes(search.toLowerCase()) ||
            vendorName.includes(search.toLowerCase()) ||
            customerName.includes(search.toLowerCase()) ||
            (o.customer_phone || '').includes(search) ||
            (o.delivery_pincode || '').includes(search) ||
            (o.delivery_address || '').toLowerCase().includes(search.toLowerCase());

        const matchesTab = activeTab === 'ALL' ||
            (activeTab === 'TRANSIT' && ['OUT_FOR_DELIVERY', 'ON_THE_WAY', 'PICKED_UP', 'RIDER_ASSIGNED', 'ACCEPTED'].includes(o.status?.toUpperCase())) ||
            (o.status || '').toUpperCase() === activeTab;

        return matchesSearch && matchesTab;
    });

    return (
        <div className="orders-container">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Live Logistics Control</h1>
                    <p className="page-subtitle">Real-time order flow and emergency operational overrides.</p>
                </div>
                <div className="page-actions">
                    <button
                        onClick={() => setShowMap(!showMap)}
                        className="btn-primary"
                        style={{ background: showMap ? '#FFD600' : '#0F172A', color: showMap ? '#0F172A' : 'white' }}>
                        <MapPin size={18} />
                        {showMap ? 'HIDE LOGISTICS MAP' : 'SHOW LOGISTICS MAP'}
                    </button>
                    <div className="glass-panel grid-status-badge">
                        <div className="pulse-green"></div>
                        <span>GRID ACTIVE</span>
                    </div>
                </div>
            </header>

            {showMap && (
                <motion.div
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: 'auto', opacity: 1 }}
                    style={{ marginBottom: '32px' }}
                >
                    <MissionMap />
                </motion.div>
            )}

            <div className="orders-controls">
                <div className="glass-panel search-field">
                    <Search size={20} color="#64748b" />
                    <input
                        placeholder="Search ID, Vendor, or Customer..."
                        value={search} onChange={e => setSearch(e.target.value)}
                    />
                </div>
                <div className="glass-panel filter-pills">
                    {['ALL', 'PENDING', 'ACCEPTED', 'PREPARING', 'READY', 'TRANSIT', 'DELIVERED'].map(tab => (
                        <button
                            key={tab}
                            onClick={() => setActiveTab(tab)}
                            className="filter-pill"
                            style={{
                                background: activeTab === tab ? '#FFD600' : 'transparent',
                                color: activeTab === tab ? '#0F172A' : '#64748B',
                            }}
                        >
                            {tab}
                        </button>
                    ))}
                </div>
            </div>

            {loading ? (
                <div style={{ textAlign: 'center', padding: '100px 0' }}>
                    <div className="pulse-green" style={{ width: '40px', height: '40px', background: '#FFD600', borderRadius: '50%', margin: '0 auto 20px' }}></div>
                    <div style={{ fontSize: '1.2rem', fontWeight: '800', color: '#64748b' }}>Syncing with global logistics grid...</div>
                </div>
            ) : filtered.length === 0 ? (
                <div className="glass-panel" style={{ padding: '80px', textAlign: 'center' }}>
                    <ShoppingBag size={48} color="#e2e8f0" style={{ marginBottom: '20px' }} />
                    <h3 style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0f172a', marginBottom: '8px' }}>No orders in the pulse</h3>
                    <p style={{ color: '#64748b', fontWeight: '600', marginBottom: '32px' }}>The logistics grid is currently quiet. New orders will appear here in real-time.</p>
                    <button
                        onClick={simulateOrder}
                        style={{ padding: '14px 28px', borderRadius: '16px', background: '#FFD600', color: '#0F172A', fontWeight: '900', border: 'none', cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: '10px', boxShadow: '0 8px 16px rgba(255, 214, 0, 0.3)' }}>
                        <RefreshCw size={20} /> INITIALIZE LIVE FEED
                    </button>
                </div>
            ) : (
                <div className="orders-list-grid">
                    {filtered.map(order => {
                        const style = getStatusStyle(order.status);
                        const oId = order.order_id || order.id || '';
                        return (
                            <div
                                key={oId}
                                className="glass-panel order-card-new"
                                style={{ borderLeft: `6px solid ${style.dot}` }}
                            >
                                <div>
                                    <div style={{ color: '#94a3b8', fontSize: '0.65rem', fontWeight: '900', marginBottom: '2px' }}>ORDER ID</div>
                                    <div style={{ color: '#0F172A', fontSize: '0.85rem', fontWeight: '900', marginBottom: '6px', letterSpacing: '0.5px' }}>{oId.toUpperCase()}</div>
                                    <h3 style={{ fontSize: '1.4rem', fontWeight: '900', color: '#0f172a', margin: 0 }}>₹{(order.total_amount || order.total || 0).toFixed(2)}</h3>
                                    <div style={{ fontSize: '0.75rem', fontWeight: '700', color: '#64748b', marginTop: '4px' }}>{order.payment_method || 'COD'} • {order.payment_status || 'PENDING'}</div>
                                </div>

                                <div style={{ minWidth: '240px' }}>
                                    <p style={{ fontSize: '0.65rem', fontWeight: '900', color: '#94a3b8', textTransform: 'uppercase', marginBottom: '8px' }}>Partners & Delivery</p>
                                    <div style={{ fontWeight: '800', color: '#0f172a', fontSize: '0.85rem' }}>STATION: {order.vendor_name}</div>
                                    <div style={{ fontWeight: '800', color: '#1e293b', fontSize: '0.85rem', marginTop: '4px' }}>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                                            <div style={{ padding: '2px 6px', background: '#334155', color: 'white', borderRadius: '4px', fontSize: '0.6rem' }}>USER</div>
                                            <span>{order.customer_name}</span>
                                            {order.customer_phone && <span style={{ color: '#2563eb', marginLeft: '6px', fontSize: '0.7rem' }}>• 📞 {order.customer_phone}</span>}
                                        </div>
                                        {order.raw_id && order.raw_id.includes('-') && (
                                            <div style={{ fontSize: '0.6rem', color: '#94a3b8', marginTop: '2px', marginLeft: '32px', fontWeight: '500' }}>
                                                ID: {order.raw_id.substring(0, 8)}...
                                            </div>
                                        )}
                                    </div>
                                    <div style={{ marginTop: '10px', padding: '12px 16px', borderRadius: '12px', background: '#f8fafc', border: '1px solid #e2e8f0' }}>
                                        <div style={{ display: 'flex', gap: '8px' }}>
                                            <MapPin size={14} style={{ color: '#ef4444', marginTop: '2px' }} />
                                            <div>
                                                <div style={{ fontSize: '0.75rem', fontWeight: '800', color: '#1e293b', marginBottom: '4px' }}>Delivery Destination:</div>
                                                <div style={{ fontSize: '0.8rem', color: '#1e293b', fontWeight: '800', lineHeight: '1.6' }}>
                                                    {order.delivery_house_number && !(order.address || '').startsWith(order.delivery_house_number) ? <b>{order.delivery_house_number}, </b> : ''}
                                                    {order.address || order.delivery_address || 'Address Captured Locally'}
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <div>
                                    <p style={{ fontSize: '0.65rem', fontWeight: '900', color: '#94a3b8', textTransform: 'uppercase', marginBottom: '8px' }}>Logistics</p>
                                    {order.rider_id ? (
                                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                            <div style={{ background: '#f1f5f9', padding: '6px 12px', borderRadius: '8px', fontSize: '0.8rem', fontWeight: '800' }}>
                                                <Truck size={14} style={{ marginRight: '6px', verticalAlign: 'middle' }} />
                                                {order.rider_name || 'Rider Assigned'}
                                            </div>
                                            <button onClick={() => setShowRiderModal({ id: oId })} style={{ background: 'none', border: 'none', color: '#3b82f6', fontSize: '0.7rem', fontWeight: '800', cursor: 'pointer' }}>REASSIGN</button>
                                        </div>
                                    ) : (
                                        <button onClick={() => setShowRiderModal({ id: oId })} style={{ background: '#FFD600', border: 'none', padding: '6px 12px', borderRadius: '8px', fontSize: '0.75rem', fontWeight: '800', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '6px' }}>
                                            <UserPlus size={14} /> ASSIGN RIDER
                                        </button>
                                    )}
                                </div>

                                <div>
                                    <div style={{
                                        display: 'inline-flex', alignItems: 'center', gap: '6px',
                                        padding: '6px 12px', borderRadius: '20px', background: style.bg, color: style.text,
                                        fontWeight: '800', fontSize: '0.7rem'
                                    }}>
                                        <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: style.dot }} className="pulse-green" />
                                        {style.label}
                                    </div>
                                    <div style={{ fontSize: '0.7rem', color: '#94a3b8', marginTop: '6px', fontWeight: '700', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                            <span>ETA: {order.estimated_arrival_time || 'CALC...'}</span>
                                            <span>{order.rider_lat ? '📡 LIVE' : '--'}</span>
                                        </div>
                                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.65rem', color: '#64748b' }}>
                                            <span>SPEED: {order.speed ? `${(order.speed * 3.6).toFixed(0)}km/h` : '0'}</span>
                                            <span>HEARTBEAT: {order.rider_last_seen ? new Date(order.rider_last_seen).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'WAITING'}</span>
                                        </div>
                                    </div>

                                    {(new Date() - new Date(order.rider_last_seen || 0) > 60000) && ['out_for_delivery', 'on_the_way', 'picked_up'].includes(order.status) && (
                                        <div style={{ fontSize: '0.65rem', color: '#ef4444', fontWeight: '900', marginTop: '8px', display: 'flex', alignItems: 'center', gap: '4px', background: '#fef2f2', padding: '4px 8px', borderRadius: '6px' }}>
                                            <AlertCircle size={10} /> 🔴 GPS INACTIVE (60s+)
                                        </div>
                                    )}
                                </div>

                                <div className="order-actions" style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', alignItems: 'center', flexWrap: 'wrap' }}>
                                    <select
                                        value={order.status?.toUpperCase()}
                                        onChange={(e) => updateStatus(oId, e.target.value)}
                                        style={{ background: '#f8fafc', border: '1px solid #e2e8f0', padding: '8px', borderRadius: '10px', fontSize: '0.75rem', fontWeight: '700', outline: 'none', minWidth: '120px' }}
                                    >
                                        <option value="PLACED">Placed</option>
                                        <option value="ACCEPTED">Accepted</option>
                                        <option value="PREPARING">Preparing</option>
                                        <option value="READY">Ready</option>
                                        <option value="PICKED_UP">Picked Up</option>
                                        <option value="ON_THE_WAY">On The Way</option>
                                        <option value="DELIVERED">Delivered</option>
                                        <option value="CANCELLED">Cancelled</option>
                                    </select>

                                    <div style={{ display: 'flex', gap: '8px' }}>
                                        <button onClick={() => initiateRefund(order)} title="Trigger Refund" style={{ width: '36px', height: '36px', borderRadius: '10px', background: '#f0fdf4', color: '#10b981', border: 'none', cursor: 'pointer', display: 'grid', placeItems: 'center', transition: 'all 0.2s' }}>
                                            <CreditCard size={18} />
                                        </button>
                                        <button onClick={() => updateStatus(oId, 'cancelled', { is_force_cancelled: true })} title="Admin Kill Switch" style={{ width: '36px', height: '36px', borderRadius: '10px', background: '#fff1f2', color: '#ef4444', border: 'none', cursor: 'pointer', display: 'grid', placeItems: 'center', transition: 'all 0.2s' }}>
                                            <XCircle size={18} />
                                        </button>
                                    </div>

                                    {['out_for_delivery', 'on_the_way', 'picked_up', 'rider_assigned', 'accepted'].includes(order.status) && (
                                        <button
                                            onClick={() => toast.success(`Pinging GPS Beacon for unit: ${order.rider_name || 'Assigned Rider'}`)}
                                            style={{ background: '#FFD600', color: '#0F172A', padding: '10px 20px', borderRadius: '12px', fontWeight: '800', fontSize: '0.75rem', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px', boxShadow: '0 4px 12px rgba(255, 214, 0, 0.3)' }}>
                                            <MapPin size={16} /> TRACK
                                        </button>
                                    )}
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}

            {/* Rider Assignment Modal */}
            <AnimatePresence>
                {showRiderModal && (
                    <motion.div
                        initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                        style={{ position: 'fixed', inset: 0, background: 'rgba(15, 23, 42, 0.8)', backdropFilter: 'blur(8px)', zIndex: 100, display: 'grid', placeItems: 'center', padding: '20px' }}
                    >
                        <motion.div
                            initial={{ scale: 0.9, y: 20 }} animate={{ scale: 1, y: 0 }} exit={{ scale: 0.9, y: 20 }}
                            className="glass-panel"
                            style={{ background: 'white', width: '100%', maxWidth: '400px', padding: '32px', position: 'relative' }}
                        >
                            <h2 style={{ fontSize: '1.25rem', fontWeight: '900', color: '#0f172a', marginBottom: '20px' }}>Dispatch Logistics</h2>
                            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                                {riders.length === 0 ? (
                                    <div style={{ textAlign: 'center', padding: '20px' }}>
                                        <p style={{ color: '#64748b', fontSize: '0.9rem', marginBottom: '16px' }}>No active units in range.</p>
                                        <button
                                            onClick={summonSimulationRider}
                                            style={{ padding: '10px 20px', borderRadius: '10px', background: '#0F172A', color: 'white', border: 'none', fontWeight: '800', cursor: 'pointer' }}
                                        >
                                            SUMMON SIMULATION RIDER
                                        </button>
                                    </div>
                                ) : riders.map(rider => (
                                    <button
                                        key={rider.id}
                                        onClick={() => assignRider(showRiderModal.id, rider.id)}
                                        style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px', borderRadius: '12px', border: '1px solid #f1f5f9', background: 'none', cursor: 'pointer', width: '100%', textAlign: 'left' }}
                                    >
                                        <div>
                                            <div style={{ fontWeight: '800', fontSize: '0.9rem' }}>{rider.name}</div>
                                            <div style={{ fontSize: '0.7rem', color: '#64748b' }}>{rider.phone}</div>
                                        </div>
                                        <ArrowRight size={18} color="#FFD600" />
                                    </button>
                                ))}
                            </div>
                            <button onClick={() => setShowRiderModal(null)} style={{ marginTop: '20px', width: '100%', padding: '12px', borderRadius: '12px', border: 'none', background: '#f1f5f9', fontWeight: '800', cursor: 'pointer' }}>CANCEL</button>
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>

            <style>{`
                .glass-panel {
                    background: rgba(255, 255, 255, 0.8);
                    backdrop-filter: blur(12px);
                    border: 1px solid rgba(255, 255, 255, 0.3);
                    border-radius: 20px;
                    box-shadow: 0 10px 30px rgba(0,0,0,0.02);
                }
                @keyframes pulse {
                    0% { transform: scale(1); opacity: 1; }
                    50% { transform: scale(1.5); opacity: 0.4; }
                    100% { transform: scale(1); opacity: 1; }
                }
                .pulse-green {
                    animation: pulse 2s infinite;
                }
            `}</style>
        </div>
    );
};

export default Orders;
