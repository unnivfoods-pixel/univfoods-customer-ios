import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
    IndianRupee, Clock, ArrowUpRight, CheckCircle,
    ArrowDownLeft, Filter, Search, Store, Bike,
    ShieldCheck, AlertTriangle, FileText, LayoutDashboard, History
} from 'lucide-react';
import { supabase } from '../supabase';
import { toast } from 'react-hot-toast';
import './Settlements.css';

const SettlementsHub = () => {
    const [wallets, setWallets] = useState([]);
    const [ledger, setLedger] = useState([]);
    const [activeTab, setActiveTab] = useState('wallets'); // 'wallets' | 'ledger' | 'cod'
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');

    useEffect(() => {
        fetchData();
        const sub = supabase.channel('financial-master')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'financial_ledger' }, fetchData)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'wallets' }, fetchData)
            .subscribe();
        return () => sub.unsubscribe();
    }, []);

    const fetchData = async () => {
        setLoading(true);
        // 1. Wallets with User metadata
        const { data: wData } = await supabase.from('wallets')
            .select('*, customer_profiles(full_name, avatar_url, phone), vendors(name)');

        // 2. Recent Ledger
        const { data: lData } = await supabase.from('financial_ledger')
            .select('*, orders(total, customer_id)')
            .order('created_at', { ascending: false })
            .limit(50);

        if (wData) setWallets(wData);
        if (lData) setLedger(lData);
        setLoading(false);
    };

    const clearCodDebt = async (userId, amount) => {
        const confirm = window.confirm(`Clear ₹${amount} COD debt for this rider? Ensure you have received the cash.`);
        if (!confirm) return;

        const { error } = await supabase.from('wallets').update({ cod_debt: 0 }).eq('user_id', userId);
        if (error) toast.error("Debt clearance failed");
        else {
            await supabase.from('financial_ledger').insert({
                entry_type: 'COD_SETTLEMENT',
                user_id: userId,
                amount: amount,
                flow_type: 'OUT',
                notes: 'Admin cleared COD debt manually'
            });
            toast.success("Debt cleared successfully");
        }
    };

    const stats = {
        platformRevenue: ledger.filter(l => l.flow_type === 'IN').reduce((acc, l) => acc + l.amount, 0),
        pendingPayouts: wallets.reduce((acc, w) => acc + (w.balance || 0), 0),
        totalDebt: wallets.reduce((acc, w) => acc + (w.cod_debt || 0), 0)
    };

    const filteredWallets = wallets.filter(w =>
        (w.vendors?.name?.toLowerCase().includes(search.toLowerCase())) ||
        (w.customer_profiles?.full_name?.toLowerCase().includes(search.toLowerCase()))
    );

    return (
        <div className="settlements-container">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Financial Command Center</h1>
                    <p className="page-subtitle">Master ledger oversight, settlement splits, and rider debt management.</p>
                </div>
                <div className="page-actions">
                    <button className="btn-secondary" onClick={fetchData}><History size={18} /> Refresh</button>
                    <button className="btn-primary" style={{ background: '#FFD600', color: '#0F172A' }}><FileText size={18} /> Commission Rules</button>
                </div>
            </header>

            <div className="financial-stats-grid">
                <div className="stat-card-premium gold">
                    <div className="stat-icon"><IndianRupee size={24} /></div>
                    <div className="stat-info">
                        <label>Gross Revenue</label>
                        <h3>₹{stats.platformRevenue.toLocaleString('en-IN')}</h3>
                    </div>
                </div>
                <div className="stat-card-premium dark">
                    <div className="stat-icon"><LayoutDashboard size={24} /></div>
                    <div className="stat-info">
                        <label>Withdrawable Balance</label>
                        <h3>₹{stats.pendingPayouts.toLocaleString('en-IN')}</h3>
                    </div>
                </div>
                <div className="stat-card-premium red">
                    <div className="stat-icon"><AlertTriangle size={24} /></div>
                    <div className="stat-info">
                        <label>Rider COD Debt</label>
                        <h3>₹{stats.totalDebt.toLocaleString('en-IN')}</h3>
                    </div>
                </div>
            </div>

            <div className="hub-tabs">
                <button className={activeTab === 'wallets' ? 'active' : ''} onClick={() => setActiveTab('wallets')}>Partner Wallets</button>
                <button className={activeTab === 'ledger' ? 'active' : ''} onClick={() => setActiveTab('ledger')}>Master Ledger</button>
                <button className={activeTab === 'cod' ? 'active' : ''} onClick={() => setActiveTab('cod')}>COD Reconciliation</button>
            </div>

            <div className="glass-panel main-hub-content">
                <div className="hub-header">
                    <div className="search-box">
                        <Search size={20} />
                        <input placeholder="Search entities..." value={search} onChange={e => setSearch(e.target.value)} />
                    </div>
                    <div className="hub-filters">
                        <Filter size={18} /> Filter
                    </div>
                </div>

                {activeTab === 'wallets' && (
                    <div className="table-wrapper">
                        <table className="hub-table">
                            <thead>
                                <tr>
                                    <th>Entity</th>
                                    <th>Role</th>
                                    <th>Withdrawable</th>
                                    <th>Lifetime</th>
                                    <th>Status</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {filteredWallets.map(w => (
                                    <tr key={w.id}>
                                        <td>
                                            <div className="entity-cell">
                                                <div className="avatar">{(w.vendors?.name || w.customer_profiles?.full_name || '?')[0]}</div>
                                                <div>
                                                    <div className="name">{w.vendors?.name || w.customer_profiles?.full_name || 'Unknown'}</div>
                                                    <div className="sub">#{w.user_id.slice(0, 8)}</div>
                                                </div>
                                            </div>
                                        </td>
                                        <td>{w.vendors ? <span className="pill vendor">VENDOR</span> : <span className="pill rider">RIDER</span>}</td>
                                        <td className="amount bold">₹{w.balance.toLocaleString()}</td>
                                        <td className="amount">₹{w.lifetime_earnings.toLocaleString()}</td>
                                        <td><span className="status active">ACTIVE</span></td>
                                        <td><button className="btn-small">Details</button></td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}

                {activeTab === 'ledger' && (
                    <div className="table-wrapper">
                        <table className="hub-table">
                            <thead>
                                <tr>
                                    <th>Entry ID</th>
                                    <th>Event</th>
                                    <th>Amount</th>
                                    <th>Dir</th>
                                    <th>Time</th>
                                    <th>Notes</th>
                                </tr>
                            </thead>
                            <tbody>
                                {ledger.map(l => (
                                    <tr key={l.id}>
                                        <td className="id-cell">#{l.id.slice(0, 8)}</td>
                                        <td><span className={`event-tag ${l.entry_type}`}>{l.entry_type}</span></td>
                                        <td className="amount bold">₹{l.amount.toLocaleString()}</td>
                                        <td>
                                            <div className={`flow-icon ${l.flow_type}`}>
                                                {l.flow_type === 'IN' ? <ArrowDownLeft size={16} /> : <ArrowUpRight size={16} />}
                                                {l.flow_type}
                                            </div>
                                        </td>
                                        <td className="time-cell">{new Date(l.created_at).toLocaleString()}</td>
                                        <td className="notes-cell">{l.notes}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}

                {activeTab === 'cod' && (
                    <div className="table-wrapper">
                        <table className="hub-table">
                            <thead>
                                <tr>
                                    <th>Rider</th>
                                    <th>Debt Collected</th>
                                    <th>Threshold</th>
                                    <th>Status</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {wallets.filter(w => !w.vendors && w.cod_debt > 0).map(w => (
                                    <tr key={w.id}>
                                        <td>{w.customer_profiles?.full_name}</td>
                                        <td className="amount bold red">₹{w.cod_debt.toLocaleString()}</td>
                                        <td>₹5,000</td>
                                        <td>{w.cod_debt > 2000 ? <span className="pill risk">HIGH DEBT</span> : <span className="pill safe">NORMAL</span>}</td>
                                        <td>
                                            <button
                                                className="btn-clear"
                                                onClick={() => clearCodDebt(w.user_id, w.cod_debt)}
                                            >
                                                <ShieldCheck size={16} /> CLEAR & SYNC
                                            </button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>
        </div>
    );
};

export default SettlementsHub;
