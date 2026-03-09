import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { NavLink } from 'react-router-dom';
import { TrendingUp, Users, ShoppingBag, CreditCard, Store, Calendar, Bell, Clock, Bike, AlertTriangle } from 'lucide-react';
import { supabase } from '../supabase';
import { COLLECTIONS } from '../constants';
import { toast } from 'react-hot-toast';
import DashboardHeader from '../components/Layout/DashboardHeader';
import './Dashboard.css';

const StatCard = ({ title, value, change, icon: Icon, color = 'var(--primary)' }) => (
    <div className="glass-panel stat-card-new">
        <div className="stat-icon-new" style={{ background: color }}>
            <Icon size={24} />
        </div>
        <div className="stat-info-new">
            <p className="stat-label-new">{title}</p>
            <h3 className="stat-value-new">{value}</h3>
            <div className="stat-change-new">
                <TrendingUp size={12} /> {change}
            </div>
        </div>
    </div>
);

const Dashboard = () => {
    const [orders, setOrders] = useState([]);
    const [delayedOrders, setDelayedOrders] = useState([]);
    const [chartData, setChartData] = useState([]);
    const [showAnnounce, setShowAnnounce] = useState(false);
    const [dbStatus, setDbStatus] = useState('connecting');

    useEffect(() => {
        const checkPulse = async () => {
            try {
                const { error } = await supabase.from('vendors').select('id').limit(1);
                setDbStatus(error ? 'offline' : 'online');
            } catch {
                setDbStatus('offline');
            }
        };
        checkPulse();
    }, []);

    const [stats, setStats] = useState({
        todayOrders: 0,
        preparing: 0,
        outForDelivery: 0,
        delivered: 0,
        cancelled: 0,
        revenue: 0,
        activePartners: 0
    });

    useEffect(() => {
        const fetchData = async () => {
            try {
                const startOfToday = new Date();
                startOfToday.setHours(0, 0, 0, 0);
                const todayIso = startOfToday.toISOString();

                // 1. Total Orders (Today)
                const { count: todayCount, error: err1 } = await supabase.from(COLLECTIONS.ORDERS)
                    .select('*', { count: 'exact', head: true })
                    .gte('created_at', todayIso);
                if (err1) console.error('Grid Pulse Fault (Today Orders):', err1);

                // 2. Status Specific Counts (Today only for accuracy)
                const { data: statusCounts, error: err2 } = await supabase.from(COLLECTIONS.ORDERS)
                    .select('status')
                    .gte('created_at', todayIso);
                if (err2) console.error('Grid Pulse Fault (Status Counts):', err2);

                const getCount = (stat) => {
                    if (!statusCounts) return 0;
                    return statusCounts.filter(o =>
                        (o.status || '').toString().toUpperCase() === stat.toUpperCase()
                    ).length;
                };

                const counts = {
                    preparing: getCount('PREPARING'),
                    outForDelivery: getCount('OUT_FOR_DELIVERY') + getCount('ON_THE_WAY'),
                    delivered: getCount('DELIVERED') + getCount('COMPLETED'),
                    cancelled: getCount('CANCELLED') + getCount('REJECTED')
                };

                // 3. Active Delivery Partners (Online)
                const { count: partnerCount, error: err3 } = await supabase.from('delivery_riders')
                    .select('*', { count: 'exact', head: true })
                    .eq('status', 'Online');
                if (err3) console.error('Grid Pulse Fault (Partners):', err3);

                // 4. Total Revenue (Delivered - Case Insensitive Search)
                const { data: revData, error: err4 } = await supabase.from(COLLECTIONS.ORDERS)
                    .select('total, total_amount')
                    .or('status.eq.delivered,status.eq.DELIVERED,status.eq.COMPLETED,status.eq.completed');
                if (err4) console.error('Grid Pulse Fault (Revenue):', err4);

                const totalRevenue = revData ? revData.reduce((acc, curr) =>
                    acc + (parseFloat(curr.total || curr.total_amount) || 0), 0) : 0;

                setStats({
                    todayOrders: todayCount || 0,
                    preparing: counts.preparing,
                    outForDelivery: counts.outForDelivery,
                    delivered: counts.delivered,
                    cancelled: counts.cancelled,
                    revenue: totalRevenue,
                    activePartners: partnerCount || 0
                });

                // 5. Delayed Orders Alarm (e.g. Preparing for > 20 mins)
                const twentyMinsAgo = new Date(Date.now() - 20 * 60000).toISOString();

                // Fetch Orders for mapping (Delayed + Recent)
                const { data: allRawOrders, error: rawErr } = await supabase.from(COLLECTIONS.ORDERS)
                    .select('*')
                    .order('created_at', { ascending: false });

                const { data: vNames } = await supabase.from('vendors').select('id, name');
                const vMap = Object.fromEntries((vNames || []).map(v => [v.id?.toString(), v.name]));

                if (allRawOrders) {
                    const mapped = allRawOrders.map(o => ({
                        ...o,
                        vendors: { name: vMap[o.vendor_id?.toString()] || o.vendor_name || 'UNIV Station' }
                    }));

                    setDelayedOrders(mapped.filter(o => {
                        const s = (o.status || '').toString().toUpperCase();
                        return ['PREPARING', 'READY', 'ACCEPTED'].includes(s) &&
                            (o.updated_at || o.created_at) < twentyMinsAgo;
                    }));

                    setOrders(mapped.slice(0, 5));
                }

                // Chart Logic
                const last7Days = Array.from({ length: 7 }, (_, i) => {
                    const d = new Date();
                    d.setDate(d.getDate() - (6 - i));
                    return d.toISOString().split('T')[0];
                });

                const { data: chartResults, error: err6 } = await supabase.from(COLLECTIONS.ORDERS)
                    .select('total, created_at')
                    .gte('created_at', last7Days[0])
                    .eq('status', 'delivered');
                if (err6) console.error('Grid Pulse Fault (Chart):', err6);

                const formattedChart = last7Days.map(date => {
                    const dayTotal = chartResults?.filter(o => o.created_at.startsWith(date))
                        .reduce((acc, curr) => acc + (parseFloat(curr.total || curr.total_amount) || 0), 0) || 0;
                    return {
                        day: new Date(date).toLocaleDateString('en-US', { weekday: 'short' }),
                        val: dayTotal
                    };
                });
                setChartData(formattedChart);
                console.log("📈 Dashboard Master Pulse: Success (Client-Side Mapping Active).");
            } catch (err) {
                console.error('Critical Dashboard Pulse Failure:', err);
            }
        };

        fetchData();

        const channel = supabase.channel('dashboard-master-pulse')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, fetchData)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'delivery_riders' }, fetchData)
            .subscribe();

        return () => supabase.removeChannel(channel);
    }, []);


    return (
        <div className="dashboard-container">
            <DashboardHeader title="UNIV Foods" />

            <header className="page-header">
                <div>
                    <h1 className="page-title">Mission Command</h1>
                    <p className="page-subtitle">Real-time platform synchronization and logistics oversight.</p>
                </div>
                <div className="page-actions">
                    <button
                        onClick={() => setShowAnnounce(true)}
                        className="btn-broadcast">
                        <Bell size={18} color="#FFD600" />
                        BROADCAST
                    </button>
                </div>
            </header>

            <div className="stats-grid-responsive">
                <StatCard title="Today's Orders" value={stats.todayOrders} change="Live Traffic" icon={ShoppingBag} color="#FFD600" />
                <StatCard title="Total Revenue" value={`₹${stats.revenue.toLocaleString('en-IN')}`} change="Net Earnings" icon={CreditCard} color="#FFD600" />
                <StatCard title="Active Partners" value={stats.activePartners} change="Online Now" icon={Bike} color="#FFD600" />
                <StatCard title="Platform Load" value={`${stats.preparing + stats.outForDelivery} Active`} change="Current Log" icon={Clock} color="#FFD600" />
            </div>

            {/* Live Status Sub-Grid */}
            <div className="secondary-stats-grid">
                <div className="glass-panel" style={{ padding: '20px', textAlign: 'center', borderBottom: '4px solid #F97316' }}>
                    <div style={{ fontSize: '0.7rem', fontWeight: '900', color: '#94A3B8', textTransform: 'uppercase' }}>Preparing</div>
                    <div style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0F172A' }}>{stats.preparing}</div>
                </div>
                <div className="glass-panel" style={{ padding: '20px', textAlign: 'center', borderBottom: '4px solid #8B5CF6' }}>
                    <div style={{ fontSize: '0.7rem', fontWeight: '900', color: '#94A3B8', textTransform: 'uppercase' }}>In Transit</div>
                    <div style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0F172A' }}>{stats.outForDelivery}</div>
                </div>
                <div className="glass-panel" style={{ padding: '20px', textAlign: 'center', borderBottom: '4px solid #10B981' }}>
                    <div style={{ fontSize: '0.7rem', fontWeight: '900', color: '#94A3B8', textTransform: 'uppercase' }}>Delivered</div>
                    <div style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0F172A' }}>{stats.delivered}</div>
                </div>
                <div className="glass-panel" style={{ padding: '20px', textAlign: 'center', borderBottom: '4px solid #EF4444' }}>
                    <div style={{ fontSize: '0.7rem', fontWeight: '900', color: '#94A3B8', textTransform: 'uppercase' }}>Cancelled</div>
                    <div style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0F172A' }}>{stats.cancelled}</div>
                </div>
            </div>


            <div className="dashboard-main-grid">
                <div className="glass-panel" style={{ padding: '32px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                            <h2 style={{ fontSize: '1.125rem', fontWeight: '700', color: '#0f172a' }}>Risk Mitigation</h2>
                            {delayedOrders.length > 0 && <div className="pulse-red" style={{ background: '#EF4444', color: 'white', fontSize: '0.65rem', padding: '2px 8px', borderRadius: '20px', fontWeight: '900' }}>{delayedOrders.length} DELAYS</div>}
                        </div>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                        {delayedOrders.length === 0 ? (
                            <div style={{ textAlign: 'center', padding: '20px', opacity: 0.5 }}>
                                <p style={{ fontSize: '0.875rem' }}>No operational risks detected.</p>
                            </div>
                        ) : delayedOrders.map(o => (
                            <div key={o.id} style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '12px', borderRadius: '12px', background: '#FEF2F2', border: '1px solid #FEE2E2' }}>
                                <AlertTriangle size={18} color="#EF4444" />
                                <div style={{ flex: 1 }}>
                                    <h4 style={{ fontSize: '0.85rem', fontWeight: '800', color: '#991B1B', margin: 0 }}>{o.vendors?.name}</h4>
                                    <p style={{ fontSize: '0.7rem', color: '#B91C1C', fontWeight: '600' }}>#{o.id ? o.id.toString().slice(0, 8) : 'ORD'} • Stuck in {(o.status || 'N/A').toUpperCase()}</p>
                                </div>
                                <NavLink to="/orders" style={{ fontSize: '0.7rem', fontWeight: '900', color: '#EF4444' }}>RESOLVE</NavLink>
                            </div>
                        ))}
                    </div>

                    <div style={{ marginTop: '32px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
                        <h2 style={{ fontSize: '1.125rem', fontWeight: '700', color: '#0f172a' }}>Live Revenue Stream</h2>
                        <span style={{ fontSize: '0.875rem', fontWeight: '600', color: '#10b981' }}>SYSTEM ONLINE</span>
                    </div>
                    <div className="chart-container-new">
                        {chartData.map((d, i) => (
                            <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px' }}>
                                <div
                                    style={{ width: '100%', borderRadius: '6px', background: '#FFD600', height: `${Math.min((d.val / (Math.max(...chartData.map(cd => cd.val)) || 1000)) * 100, 100)}%`, transition: 'height 0.4s' }}
                                />
                                <span style={{ fontSize: '0.75rem', fontWeight: '600', color: '#64748B' }}>{d.day}</span>
                            </div>
                        ))}
                    </div>
                </div>

                <div className="glass-panel" style={{ padding: '32px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                            <h2 style={{ fontSize: '1.125rem', fontWeight: '700', color: '#0f172a' }}>Recent Activity</h2>
                            <div className="pulse-green" style={{ width: '8px', height: '8px', background: '#10b981', borderRadius: '50%' }}></div>
                        </div>
                        <NavLink to="/orders" style={{ fontSize: '0.875rem', fontWeight: '800', color: '#0F172A', background: '#FFD600', padding: '6px 14px', borderRadius: '8px', boxShadow: '0 4px 10px rgba(255, 214, 0, 0.2)' }}>View All</NavLink>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                        {orders.length === 0 ? (
                            <div style={{ textAlign: 'center', padding: '40px 0', opacity: 0.5 }}>
                                <p style={{ fontSize: '0.875rem' }}>No recent activity detected.</p>
                            </div>
                        ) : orders.map(o => (
                            <div key={o.id} style={{ display: 'flex', alignItems: 'center', gap: '16px', padding: '12px', borderRadius: '12px', border: '1px solid #f1f5f9' }}>
                                <div style={{ width: '40px', height: '40px', borderRadius: '8px', background: '#f8fafc', display: 'grid', placeItems: 'center', color: '#64748b' }}>
                                    <ShoppingBag size={18} />
                                </div>
                                <div style={{ flex: 1 }}>
                                    <h4 style={{ fontSize: '0.875rem', fontWeight: '800', color: '#0F172A', margin: 0 }}>{o.vendors?.name || 'Platform Update'}</h4>
                                    <p style={{ fontSize: '0.75rem', color: '#64748B', fontWeight: '600', margin: '2px 0 0' }}>₹{o.total || o.total_amount || 0} • <span style={{ color: '#FFD600' }}>{(o.status || 'N/A').toUpperCase()}</span></p>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Dashboard;
