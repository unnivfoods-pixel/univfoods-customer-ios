import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';
import { COLLECTIONS } from '../constants';
import { motion } from 'framer-motion';
import { CreditCard, RefreshCw, AlertCircle, DollarSign, Activity } from 'lucide-react';
import './Payments.css';

const Payments = () => {
    const [stats, setStats] = useState({
        total_volume: 0,
        success_count: 0,
        failed_count: 0,
        refunds_today: 0,
        cod_percent: 0
    });
    const [recentTxns, setRecentTxns] = useState([]);
    const [globalRules, setGlobalRules] = useState([]);

    useEffect(() => {
        fetchDashboardData();
        fetchRules();

        const paymentSub = supabase.channel('payments-dashboard')
            .on('postgres_changes', { event: '*', schema: 'public', table: COLLECTIONS.PAYMENTS }, () => {
                fetchDashboardData(); // Refresh stats on any payment change
            })
            .subscribe();

        return () => supabase.removeChannel(paymentSub);
    }, []);

    const fetchDashboardData = async () => {
        // In a real app, use optimized RPC or edge functions for agg
        // Fetching last 100 payments for client-side demo agg
        const { data } = await supabase.from(COLLECTIONS.PAYMENTS)
            .select('*')
            .order('created_at', { ascending: false })
            .limit(100);

        if (data && data.length > 0) {
            const success = data.filter(p => p.status === 'SUCCESS');
            const failed = data.filter(p => p.status === 'FAILED');
            const cod = data.filter(p => p.payment_method === 'COD');
            const refunds = data.filter(p => p.status === 'REFUNDED');

            const total = success.reduce((acc, curr) => acc + (Number(curr.amount) || 0), 0);

            setStats({
                total_volume: total,
                success_count: success.length,
                failed_count: failed.length,
                refunds_today: refunds.length,
                cod_percent: Math.round((cod.length / data.length) * 100) || 0
            });
            setRecentTxns(data.slice(0, 50)); // Show top 50
        }
    };

    const fetchRules = async () => {
        const { data } = await supabase.from(COLLECTIONS.PAYMENT_RULES)
            .select('*')
            .eq('scope', 'GLOBAL');
        if (data) setGlobalRules(data);
    };

    const toggleRule = async (ruleId, currentStatus) => {
        await supabase.from(COLLECTIONS.PAYMENT_RULES)
            .update({ enabled: !currentStatus })
            .eq('id', ruleId);
        fetchRules();
    };

    // Helper for status badge
    const getStatusBadge = (status) => {
        switch (status) {
            case 'SUCCESS': return <span className="badge badge-success">Success</span>;
            case 'FAILED': return <span className="badge badge-danger">Failed</span>;
            case 'REFUNDED': return <span className="badge badge-warning">Refunded</span>;
            default: return <span className="badge badge-secondary">{status}</span>;
        }
    };

    return (
        <div className="payments-page">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Financial Treasury</h1>
                    <p className="page-subtitle">Terminal health monitoring and live transaction auditing.</p>
                </div>
                <div className="page-actions">
                    <button className="btn-primary" style={{ background: '#FFD600', color: '#0F172A' }}>
                        <DollarSign size={18} /> Settlement Logs
                    </button>
                    <button className="btn-refresh" onClick={fetchDashboardData}>
                        <RefreshCw size={20} />
                    </button>
                </div>
            </header>

            {/* Quick Stats */}
            <div className="stats-grid">
                <div className="glass-panel stat-box volume">
                    <p className="stat-label">Volume (Live)</p>
                    <h2 className="stat-value">₹{stats.total_volume.toLocaleString()}</h2>
                    <Activity size={24} className="stat-icon-live" />
                </div>
                <div className="glass-panel stat-box">
                    <p className="stat-label">Success Rate</p>
                    <h2 className="stat-value">{stats.success_count}%</h2>
                    <p className="stat-sub">Based on last 100 txns</p>
                </div>
                <div className="glass-panel stat-box">
                    <p className="stat-label">Failed Payments</p>
                    <h2 className="stat-value text-danger">{stats.failed_count}</h2>
                    <AlertCircle size={24} className="stat-icon-alert" />
                </div>
                <div className="glass-panel stat-box">
                    <p className="stat-label">COD Share</p>
                    <h2 className="stat-value">{stats.cod_percent}%</h2>
                    <p className="stat-sub">vs Online Methods</p>
                </div>
            </div>

            <div className="payments-dashboard-grid">

                {/* Live Transactions */}
                <div className="glass-panel transaction-panel">
                    <h3>Live Transactions</h3>
                    <div className="table-wrapper">
                        <table className="responsive-table">
                            <thead>
                                <tr>
                                    <th>Method</th>
                                    <th>Amount</th>
                                    <th>Status</th>
                                    <th>Time</th>
                                </tr>
                            </thead>
                            <tbody>
                                {recentTxns.map(txn => (
                                    <tr key={txn.id}>
                                        <td data-label="Method">{txn.payment_method}</td>
                                        <td data-label="Amount">₹{txn.amount}</td>
                                        <td data-label="Status">{getStatusBadge(txn.status)}</td>
                                        <td data-label="Time">{new Date(txn.created_at).toLocaleTimeString()}</td>
                                    </tr>
                                ))}
                                {recentTxns.length === 0 && <tr><td colSpan="4" className="text-center">No transactions yet</td></tr>}
                            </tbody>
                        </table>
                    </div>
                </div>

                {/* Global Gateway Controls */}
                <div className="glass-panel controls-panel">
                    <h3>Global Controls</h3>
                    <p className="panel-hint">Toggle payment methods instantly across all apps.</p>

                    <div className="controls-list">
                        {globalRules.map(rule => (
                            <div key={rule.id} className="control-item-row">
                                <span className="control-name">{rule.payment_method}</span>
                                <label className="switch">
                                    <input type="checkbox" checked={rule.enabled} onChange={() => toggleRule(rule.id, rule.enabled)} />
                                    <span className="slider round"></span>
                                </label>
                            </div>
                        ))}
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Payments;
