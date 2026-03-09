import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { UserPlus, CheckCircle, XCircle, MapPin, Phone, Mail, Clock, Shield, Search, FileText, ExternalLink, ArrowRight, Trash2 } from 'lucide-react';
import { supabase } from '../supabase';
import { toast } from 'react-hot-toast';
import { useNavigate } from 'react-router-dom';
import './RegistrationRequests.css';

const RegistrationRequests = () => {
    const navigate = useNavigate();
    const [requests, setRequests] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [filterType, setFilterType] = useState('all'); // 'all', 'vendor', 'delivery'

    useEffect(() => {
        console.log("🛰️ REGISTRATION_REQUESTS_LOADED_V2.1");
        fetchRequests();
        const sub = supabase.channel('requests-live').on('postgres_changes', { event: '*', schema: 'public', table: 'registration_requests' }, fetchRequests).subscribe();
        return () => sub.unsubscribe();
    }, []);

    const fetchRequests = async () => {
        try {
            // Attempt to fetch from primary table
            const { data: primaryData, error: primaryError } = await supabase.from('registration_requests').select('*').order('created_at', { ascending: false });

            // Attempt to fetch from legacy/alternative table
            const { data: secondaryData } = await supabase.from('registrations').select('*').order('created_at', { ascending: false });

            let combined = [];
            if (primaryData) combined = [...primaryData];
            if (secondaryData) {
                // Merge and avoid duplicates by email
                const existingEmails = new Set(combined.map(r => r.email?.toLowerCase()));
                const extra = secondaryData.filter(r => !existingEmails.has(r.email?.toLowerCase()));
                combined = [...combined, ...extra];
            }

            setRequests(combined);
        } catch (err) {
            console.error("Fetch failed:", err);
        } finally {
            setLoading(false);
        }
    };

    const handleApprove = async (req) => {
        try {
            const { error } = await supabase.rpc('approve_partner_v7', { request_id: req.id });
            if (error) throw error;

            toast.success(`${req.type === 'rider' || req.type === 'delivery' ? 'Rider' : 'Vendor'} Activated Real-time!`);
            fetchRequests();
        } catch (err) {
            console.error("Approval failed:", err);
            // Fallback to manual navigation if RPC fails
            if (req.type === 'delivery' || req.type === 'rider') {
                navigate('/delivery', { state: { registrationData: req } });
            } else {
                navigate('/vendors', { state: { registrationData: req } });
            }
            toast.error("Switching to Manual Deployment...");
        }
    };

    const handleDelete = async (id) => {
        if (!confirm("Permanently destroy this record?")) return;
        const { error } = await supabase.from('registration_requests').delete().eq('id', id);
        // Also try legacy table
        await supabase.from('registrations').delete().eq('id', id);

        if (error) toast.error(error.message);
        else toast.success("Node terminated.");
        fetchRequests();
    };

    const filtered = requests.filter(r => {
        const matchesSearch = r.name?.toLowerCase().includes(search.toLowerCase()) ||
            r.email?.toLowerCase().includes(search.toLowerCase());

        const isDelivery = r.type === 'delivery' || r.type === 'rider';
        const isVendor = r.type === 'vendor' || !r.type; // Default to vendor if no type

        if (filterType === 'delivery') return matchesSearch && isDelivery;
        if (filterType === 'vendor') return matchesSearch && isVendor;
        return matchesSearch;
    });

    return (
        <div className="registration-requests-container">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Partner Registrations</h1>
                    <p className="page-subtitle">
                        Reviewing {requests.filter(r => r.status === 'pending').length} pending applications.
                    </p>
                </div>
                <div className="page-actions">
                    <div className="glass-panel search-field">
                        <Search size={18} color="#64748b" />
                        <input
                            placeholder="Search applications..."
                            value={search} onChange={e => setSearch(e.target.value)}
                        />
                    </div>
                </div>
            </header>

            <div className="registration-filters">
                <button
                    onClick={() => setFilterType('all')}
                    className={filterType === 'all' ? 'filter-btn active' : 'filter-btn'}
                >
                    All Requests
                </button>
                <button
                    onClick={() => setFilterType('vendor')}
                    className={filterType === 'vendor' ? 'filter-btn active' : 'filter-btn'}
                >
                    Vendors
                </button>
                <button
                    onClick={() => setFilterType('delivery')}
                    className={filterType === 'delivery' ? 'filter-btn active' : 'filter-btn'}
                >
                    Fleet
                </button>
            </div>

            {loading ? (
                <div style={{ textAlign: 'center', padding: '100px 0', fontSize: '1.2rem', fontWeight: '800', color: '#64748b' }}>Establishing secure connection to records...</div>
            ) : (
                <div className="registration-grid">
                    {filtered.map((req, idx) => (
                        <div
                            key={req.id}
                            className="glass-panel"
                            style={{ padding: '24px', position: 'relative' }}
                        >
                            {/* Status Indicator */}
                            <div style={{ position: 'absolute', top: '20px', right: '20px', display: 'flex', gap: '8px' }}>
                                <div style={{ padding: '4px 8px', borderRadius: '4px', background: (req.type === 'vendor' || !req.type) ? '#ecfdf5' : '#eef2ff', color: (req.type === 'vendor' || !req.type) ? '#065f46' : '#3730a3', fontSize: '0.65rem', fontWeight: '800', textTransform: 'uppercase' }}>
                                    {(req.type === 'delivery' || req.type === 'rider') ? 'DELIVERY' : 'VENDOR'}
                                </div>
                                <div style={{ padding: '4px 8px', borderRadius: '4px', background: req.status === 'pending' ? '#fff7ed' : '#f1f5f9', color: req.status === 'pending' ? '#c2410c' : '#64748b', fontSize: '0.65rem', fontWeight: '700', textTransform: 'uppercase' }}>
                                    {req.status}
                                </div>
                            </div>

                            <div style={{ display: 'flex', gap: '16px', marginBottom: '24px' }}>
                                <div style={{ width: '48px', height: '48px', borderRadius: '12px', background: '#FFD600', display: 'grid', placeItems: 'center', color: '#0F172A', fontSize: '1.25rem', fontWeight: '900', boxShadow: '0 4px 12px rgba(255, 214, 0, 0.3)' }}>
                                    {req.name?.[0] || 'V'}
                                </div>
                                <div>
                                    <h3 style={{ fontSize: '1.2rem', fontWeight: '800', color: '#0f172a', margin: 0 }}>{req.name}</h3>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#dc2626', fontSize: '0.9rem', fontWeight: '700', marginTop: '4px' }}>
                                        <Mail size={14} /> {req.email || 'NO_EMAIL_DETECTED'}
                                    </div>
                                </div>
                            </div>

                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '24px' }}>
                                <div style={{ background: '#f8fafc', padding: '12px', borderRadius: '8px' }}>
                                    <p style={{ fontSize: '0.65rem', fontWeight: '600', color: '#94a3b8', textTransform: 'uppercase', marginBottom: '4px' }}>Phone</p>
                                    <div style={{ fontWeight: '600', color: '#1e293b', fontSize: '0.875rem' }}>{req.phone}</div>
                                </div>
                                <div style={{ background: '#fef2f2', padding: '12px', borderRadius: '8px', border: '1px solid #fee2e2' }}>
                                    <p style={{ fontSize: '0.65rem', fontWeight: '800', color: '#ef4444', textTransform: 'uppercase', marginBottom: '4px' }}>Login Password</p>
                                    <div style={{ fontWeight: '800', color: '#b91c1c', fontSize: '0.875rem', fontFamily: 'monospace' }}>
                                        {req.password || '••••••••'}
                                        <button
                                            onClick={() => {
                                                navigator.clipboard.writeText(req.password);
                                                toast.success("Password copied!");
                                            }}
                                            style={{ marginLeft: '8px', background: 'transparent', border: 'none', cursor: 'pointer', verticalAlign: 'middle', opacity: 0.5 }}
                                        >
                                            <FileText size={14} />
                                        </button>
                                    </div>
                                </div>
                            </div>

                            <div style={{ marginBottom: '24px' }}>
                                <p style={{ fontSize: '0.875rem', color: '#475569', lineHeight: 1.5 }}>{req.message || "Establishing new node for platform expansion."}</p>
                            </div>

                            <div style={{ display: 'flex', gap: '12px' }}>
                                <button
                                    onClick={() => handleApprove(req)}
                                    style={{ flex: 1, padding: '12px', borderRadius: '12px', background: '#FFD600', color: '#0F172A', border: 'none', fontWeight: '800', fontSize: '0.875rem', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', boxShadow: '0 4px 12px rgba(255, 214, 0, 0.2)' }}
                                >
                                    Review Application <ArrowRight size={16} />
                                </button>
                                <button
                                    onClick={() => handleDelete(req.id)}
                                    style={{ width: '40px', height: '40px', borderRadius: '8px', background: '#fff1f2', color: '#ef4444', border: 'none', cursor: 'pointer', display: 'grid', placeItems: 'center' }}
                                >
                                    <Trash2 size={20} />
                                </button>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
};

export default RegistrationRequests;
