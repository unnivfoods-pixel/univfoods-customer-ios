import React, { useState, useEffect } from 'react';
import { Megaphone, Plus, Trash2, Calendar, RefreshCw } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { supabase } from '../supabase';

const Promotions = () => {
    const [promos, setPromos] = useState([]);
    const [loading, setLoading] = useState(true);
    const [showModal, setShowModal] = useState(false);

    useEffect(() => {
        fetchPromos();
        const sub = supabase.channel('promos-live-v2')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'promotions' }, fetchPromos)
            .subscribe();
        return () => sub.unsubscribe();
    }, []);

    const fetchPromos = async () => {
        try {
            const { data } = await supabase.from('promotions').select('*').order('created_at', { ascending: false });
            if (data) setPromos(data);
        } catch (e) {
            console.error(e);
        }
        setLoading(false);
    };

    return (
        <div className="page-container">
            <header className="page-header" style={{ marginBottom: '60px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
                <div>
                    <h1 style={{ fontSize: '2.5rem', fontWeight: '900', color: '#0F172A', letterSpacing: '-0.06em', lineHeight: 1.1 }}>Campaigns & Banners</h1>
                    <p style={{ color: '#64748B', fontSize: '1rem', fontWeight: '600', marginTop: '5px' }}>Manage high-conversion coupons and terminal display assets.</p>
                </div>
                <button
                    className="btn btn-primary"
                    onClick={() => setShowModal(true)}
                    style={{ background: '#FFD600', color: '#0F172A', fontWeight: '900', borderRadius: '16px', padding: '16px 32px', boxShadow: '0 10px 20px rgba(255,214,0,0.2)', border: 'none', display: 'flex', alignItems: 'center', gap: '8px' }}
                >
                    <Plus size={22} /> New Campaign
                </button>
            </header>

            <div className="glass-panel" style={{ padding: '0', overflow: 'hidden', borderRadius: '30px' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                    <thead>
                        <tr style={{ background: '#F8FAFC', borderBottom: '1px solid #F1F5F9' }}>
                            <th style={{ textAlign: 'left', padding: '24px', color: '#64748B', fontWeight: '800', fontSize: '0.85rem', textTransform: 'uppercase' }}>Campaign identity</th>
                            <th style={{ textAlign: 'left', padding: '24px', color: '#64748B', fontWeight: '800', fontSize: '0.85rem', textTransform: 'uppercase' }}>Terminal Code</th>
                            <th style={{ textAlign: 'left', padding: '24px', color: '#64748B', fontWeight: '800', fontSize: '0.85rem', textTransform: 'uppercase' }}>Transmission Value</th>
                            <th style={{ textAlign: 'left', padding: '24px', color: '#64748B', fontWeight: '800', fontSize: '0.85rem', textTransform: 'uppercase' }}>Status</th>
                            <th style={{ textAlign: 'left', padding: '24px', color: '#64748B', fontWeight: '800', fontSize: '0.85rem', textTransform: 'uppercase' }}>End Cycle</th>
                            <th style={{ textAlign: 'center', padding: '24px', color: '#64748B', fontWeight: '800', fontSize: '0.85rem', textTransform: 'uppercase' }}>Protocol</th>
                        </tr>
                    </thead>
                    <tbody>
                        {promos.length === 0 ? (
                            <tr>
                                <td colSpan="6" style={{ textAlign: 'center', padding: '100px', color: '#94A3B8', fontWeight: '600' }}>
                                    {loading ? <RefreshCw className="animate-spin" size={32} /> : "No active campaigns found in the grid."}
                                </td>
                            </tr>
                        ) : (
                            promos.map(p => (
                                <tr key={p.id} style={{ borderBottom: '1px solid #F1F5F9' }}>
                                    <td style={{ padding: '24px' }}>
                                        <div style={{ fontWeight: '900', color: '#0F172A' }}>{p.title}</div>
                                    </td>
                                    <td style={{ padding: '24px' }}>
                                        <span style={{ background: '#F4F7FE', padding: '8px 16px', borderRadius: '10px', fontWeight: '800', color: '#1E293B', fontFamily: 'monospace', fontSize: '1rem' }}>{p.code}</span>
                                    </td>
                                    <td style={{ padding: '24px' }}>
                                        <div style={{ color: '#166534', fontWeight: '900', fontSize: '1.1rem' }}>{p.discount}</div>
                                    </td>
                                    <td style={{ padding: '24px' }}>
                                        <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', padding: '6px 14px', borderRadius: '10px', background: p.active ? '#DCFCE7' : '#FEE2E2', color: p.active ? '#166534' : '#991B1B', fontWeight: '900', fontSize: '0.75rem' }}>
                                            {p.active ? 'ACTIVE' : 'EXPIRED'}
                                        </div>
                                    </td>
                                    <td style={{ padding: '24px', color: '#64748B', fontWeight: '700' }}>{p.expires}</td>
                                    <td style={{ padding: '24px', textAlign: 'center' }}>
                                        <button style={{ background: '#FEE2E2', color: '#991B1B', border: 'none', padding: '10px', borderRadius: '12px', cursor: 'pointer' }}>
                                            <Trash2 size={18} />
                                        </button>
                                    </td>
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>

            <AnimatePresence>
                {showModal && (
                    <div style={{ position: 'fixed', inset: 0, zIndex: 9999, display: 'grid', placeItems: 'center', padding: '20px' }}>
                        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setShowModal(false)} style={{ position: 'absolute', inset: 0, background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(10px)' }} />
                        <motion.div initial={{ opacity: 0, y: 30, scale: 0.95 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 30, scale: 0.95 }} style={{ position: 'relative', background: 'white', width: '100%', maxWidth: '500px', borderRadius: '40px', padding: '50px', boxShadow: '0 50px 100px -20px rgba(15,23,42,0.25)' }}>
                            <h3 style={{ fontSize: '1.6rem', fontWeight: '900', color: '#0F172A', marginBottom: '15px' }}>Deploy New Coupon</h3>
                            <p style={{ color: '#64748B', fontWeight: '600', marginBottom: '30px' }}>Strategic campaign protocol is coming to the next terminal cycle.</p>
                            <button className="btn btn-primary" onClick={() => setShowModal(false)} style={{ width: '100%', padding: '20px', borderRadius: '20px', background: '#FFD600', color: '#0F172A', fontWeight: '900', border: 'none', boxShadow: '0 10px 20px rgba(255,214,0,0.2)' }}>Close Transmission</button>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default Promotions;
