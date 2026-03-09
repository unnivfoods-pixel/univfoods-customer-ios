import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { AlertTriangle, Shield, RefreshCw, Eye, Trash2 } from 'lucide-react';
import { supabase } from '../supabase';
import { toast } from 'react-hot-toast';
import './FraudMonitor.css';

const FraudMonitor = () => {
    const [logs, setLogs] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchLogs();
        const sub = supabase.channel('fraud-updates')
            .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'fraud_logs' }, fetchLogs)
            .subscribe();
        return () => supabase.removeChannel(sub);
    }, []);

    const fetchLogs = async () => {
        const { data } = await supabase.from('fraud_logs')
            .select('*, orders(total), delivery_riders(name)')
            .order('created_at', { ascending: false });
        if (data) setLogs(data);
        setLoading(false);
    };

    const resolveLog = async (id) => {
        const { error } = await supabase.from('fraud_logs').delete().eq('id', id);
        if (!error) {
            toast.success("Flag dismissed.");
            fetchLogs();
        }
    };

    return (
        <div className="fraud-page">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Inertia Fraud Shield</h1>
                    <p className="page-subtitle">Real-time integrity monitor for all platform transactions.</p>
                </div>
                <div className="page-actions">
                    <div className="fraud-status-badge">
                        <Shield size={18} />
                        {logs.filter(l => l.severity === 'HIGH').length} CRITICAL FLAGS
                    </div>
                </div>
            </header>

            <div className="glass-panel" style={{ background: 'white', padding: 0, borderRadius: '30px', overflow: 'hidden' }}>
                <table className="responsive-table">
                    <thead>
                        <tr>
                            <th>Signal Timestamp</th>
                            <th>Target Entity</th>
                            <th>Anomaly Logic</th>
                            <th>Threat Level</th>
                            <th style={{ textAlign: 'right' }}>Neutralization</th>
                        </tr>
                    </thead>
                    <tbody>
                        {loading ? (
                            <tr>
                                <td colSpan="5" style={{ textAlign: 'center', padding: '100px 0', color: '#94a3b8', fontWeight: '800' }}>
                                    Scanning platform integrity...
                                </td>
                            </tr>
                        ) : logs.length === 0 ? (
                            <tr>
                                <td colSpan="5" style={{ textAlign: 'center', padding: '100px 0', color: '#94a3b8', fontWeight: '800' }}>
                                    No anomalies detected in current cycle.
                                </td>
                            </tr>
                        ) : (
                            logs.map(log => (
                                <tr key={log.id}>
                                    <td data-label="Timestamp">
                                        <div className="event-time">{new Date(log.created_at).toLocaleString()}</div>
                                    </td>
                                    <td data-label="Entity">
                                        <div className="event-entity">
                                            <div className="entity-main">{log.delivery_riders?.name || 'Customer Node'}</div>
                                            <div className="entity-sub">TRANS_ID: #{log.order_id?.substring(0, 8)}</div>
                                        </div>
                                    </td>
                                    <td data-label="Reason">
                                        <div className="fraud-reason">{log.reason}</div>
                                    </td>
                                    <td data-label="Severity">
                                        <span className={`severity-pill ${log.severity === 'HIGH' ? 'high' : 'low'}`}>
                                            {log.severity}
                                        </span>
                                    </td>
                                    <td data-label="Actions" style={{ textAlign: 'right' }}>
                                        <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                                            <button onClick={() => resolveLog(log.id)} className="btn-resolve" title="Dismiss High-Priority Flag">
                                                <Trash2 size={18} />
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
};


export default FraudMonitor;
