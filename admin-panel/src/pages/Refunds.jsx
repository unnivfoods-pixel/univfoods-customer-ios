import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';
import {
    Search, RefreshCw, Clock, CheckCircle, AlertCircle,
    Trash2, ShieldAlert, BadgeInfo, Scale, DollarSign,
    ExternalLink, Check, X, FileMinus
} from 'lucide-react';
import { toast } from 'react-hot-toast';
import './Refunds.css';

const RefundsAndDisputes = () => {
    const [disputes, setDisputes] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');

    useEffect(() => {
        fetchDisputes();
        const sub = supabase.channel('disputes-live')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'disputes' }, fetchDisputes)
            .subscribe();
        return () => sub.unsubscribe();
    }, []);

    const fetchDisputes = async () => {
        setLoading(true);
        try {
            const { data: rawDisputes, error: disErr } = await supabase.from('disputes')
                .select('*')
                .order('created_at', { ascending: false });

            if (disErr) throw disErr;

            if (rawDisputes && rawDisputes.length > 0) {
                // Fetch context for mapping
                const orderIds = rawDisputes.map(d => d.order_id?.toString()).filter(Boolean);
                const customerIds = rawDisputes.map(d => d.customer_id?.toString()).filter(Boolean);

                const [{ data: oData }, { data: pData }, { data: vData }] = await Promise.all([
                    supabase.from('orders').select('*').in('id', orderIds),
                    supabase.from('customer_profiles').select('id, full_name, phone').in('id', customerIds),
                    supabase.from('vendors').select('id, name')
                ]);

                const oMap = Object.fromEntries((oData || []).map(o => [o.id?.toString(), o]));
                const pMap = Object.fromEntries((pData || []).map(p => [p.id?.toString(), p]));
                const vMap = Object.fromEntries((vData || []).map(v => [v.id?.toString(), v.name]));

                const mapped = rawDisputes.map(d => {
                    const order = oMap[d.order_id?.toString()];
                    const profile = pMap[d.customer_id?.toString()];
                    return {
                        ...d,
                        orders: order ? { ...order, vendors: { name: vMap[order.vendor_id?.toString()] || 'UNIV Station' } } : null,
                        customer_profiles: profile
                    };
                });
                setDisputes(mapped);
            } else {
                setDisputes([]);
            }
        } catch (err) {
            console.error('Justice Grid Sync Failed:', err);
            toast.error("Refund Pulse Fault: Data Not Harmonized");
        } finally {
            setLoading(false);
        }
    };

    const handleResolution = async (id, type, amount = 0) => {
        const msg = type === 'FULL_REFUND' ? `Issue full refund of ₹${amount}?` : `Reject dispute?`;
        if (!window.confirm(msg)) return;

        const { error } = await supabase.from('disputes').update({
            status: 'RESOLVED',
            resolution_type: type,
            refund_amount: amount,
            resolved_at: new Date().toISOString()
        }).eq('id', id);

        if (error) {
            toast.error(error.message);
        } else {
            // If refund approved, we should also track it in the ledger via RPC or manual insert
            if (type.includes('REFUND')) {
                await supabase.from('financial_ledger').insert({
                    entry_type: 'ORDER_REFUND',
                    order_id: (disputes.find(d => d.id === id))?.order_id,
                    amount: amount,
                    flow_type: 'OUT',
                    notes: `Refund approved by Admin: ${type}`
                });
            }
            toast.success("Dispute resolved successfully");
        }
    };

    return (
        <div className="refunds-page">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Refunds & Disputes Hub</h1>
                    <p className="page-subtitle">Mediate between customers and partners. Resolve issues with financial integrity.</p>
                </div>
                <div className="page-actions">
                    <button className="btn-secondary" onClick={fetchDisputes}><RefreshCw size={18} /> Sync</button>
                </div>
            </header>

            <div className="dispute-filters-row">
                <div className="glass-panel search-field">
                    <Search size={20} color="#64748b" />
                    <input
                        placeholder="Search by Order ID or Customer..."
                        value={search} onChange={e => setSearch(e.target.value)}
                    />
                </div>
            </div>

            <div className="dispute-grid">
                {loading ? (
                    <div className="loading-state">Syncing with justice system...</div>
                ) : disputes.length === 0 ? (
                    <div className="empty-state">
                        <Scale size={48} />
                        <p>No active disputes or refund requests.</p>
                    </div>
                ) : disputes.map(dispute => (
                    <div key={dispute.id} className={`dispute-card ${dispute.status.toLowerCase()}`}>
                        <div className="card-header">
                            <div>
                                <span className={`status-tag ${dispute.status.toLowerCase()}`}>{dispute.status}</span>
                                <span className="time-ago">{new Date(dispute.created_at).toLocaleDateString()}</span>
                            </div>
                            <div className="order-id">#{dispute.order_id.slice(0, 8)}</div>
                        </div>

                        <div className="card-body">
                            <div className="customer-info">
                                <h4 className="name">{dispute.customer_profiles?.full_name}</h4>
                                <p className="phone">{dispute.customer_profiles?.phone}</p>
                            </div>

                            <div className="reason-box">
                                <label><BadgeInfo size={14} /> Reason</label>
                                <p className="reason-text">{dispute.reason.replace('_', ' ')}</p>
                                <p className="detail-msg">{dispute.detail_msg || 'No additional details provided.'}</p>
                            </div>

                            <div className="order-summary">
                                <div className="summary-item">
                                    <label>Restaurant</label>
                                    <span>{dispute.orders?.vendors?.name}</span>
                                </div>
                                <div className="summary-item">
                                    <label>Order Amount</label>
                                    <span style={{ fontWeight: 800 }}>₹{dispute.orders?.total}</span>
                                </div>
                                <div className="summary-item">
                                    <label>Payment</label>
                                    <span>{dispute.orders?.payment_method}</span>
                                </div>
                            </div>
                        </div>

                        {dispute.status === 'PENDING' && (
                            <div className="card-footer">
                                <button
                                    className="btn-resolve approve"
                                    onClick={() => handleResolution(dispute.id, 'FULL_REFUND', dispute.orders?.total)}
                                >
                                    <Check size={16} /> FULL REFUND
                                </button>
                                <button
                                    className="btn-resolve partial"
                                    onClick={() => handleResolution(dispute.id, 'PARTIAL_REFUND', dispute.orders?.total / 2)}
                                >
                                    <DollarSign size={16} /> PARTIAL (50%)
                                </button>
                                <button
                                    className="btn-resolve reject"
                                    onClick={() => handleResolution(dispute.id, 'REJECTED')}
                                >
                                    <X size={16} /> REJECT
                                </button>
                            </div>
                        )}

                        {dispute.status === 'RESOLVED' && (
                            <div className="resolution-info">
                                <ShieldCheck size={16} />
                                <span>Resolved as: <strong>{dispute.resolution_type}</strong> (₹{dispute.refund_amount})</span>
                            </div>
                        )}
                    </div>
                ))}
            </div>
        </div>
    );
};

// Simple Icon component used in the JSX above
const ShieldCheck = ({ size }) => <CheckCircle size={size} color="#10b981" />;

export default RefundsAndDisputes;
