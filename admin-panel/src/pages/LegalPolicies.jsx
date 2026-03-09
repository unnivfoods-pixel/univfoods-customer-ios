import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Plus, Shield, Clock, ChevronRight, Info, FileText, CheckCircle, Save, X } from 'lucide-react';
import { supabase } from '../supabase';
import { COLLECTIONS } from '../constants';
import { toast } from 'react-hot-toast';
import './LegalPolicies.css';

const LegalPolicies = () => {
    const [docs, setDocs] = useState([]);
    const [auditLogs, setAuditLogs] = useState([]);
    const [loading, setLoading] = useState(true);
    const [isEditing, setIsEditing] = useState(false);
    const [formData, setFormData] = useState({
        type: 'PRIVACY_POLICY',
        role: 'ALL',
        title: '',
        content: '',
        version: '1.0',
        requires_acceptance: true
    });

    useEffect(() => {
        fetchDocs();
        fetchAudit();
    }, []);

    const fetchDocs = async () => {
        const { data } = await supabase.from(COLLECTIONS.LEGAL_DOCS)
            .select('*')
            .eq('is_active', true)
            .order('type', { ascending: true });
        if (data) setDocs(data);
        setLoading(false);
    };

    const fetchAudit = async () => {
        const { data } = await supabase.from(COLLECTIONS.LEGAL_LOGS)
            .select('*')
            .order('accepted_at', { ascending: false })
            .limit(20);
        if (data) setAuditLogs(data);
    };

    const handlePublish = async (e) => {
        e.preventDefault();
        const toastId = toast.loading("Publishing document...");
        try {
            // Deactivate old
            await supabase.from(COLLECTIONS.LEGAL_DOCS)
                .update({ is_active: false })
                .match({ type: formData.type, role: formData.role, is_active: true });

            // Insert new
            const { error } = await supabase.from(COLLECTIONS.LEGAL_DOCS).insert([{
                ...formData,
                is_active: true,
                published_at: new Date()
            }]);

            if (error) throw error;
            toast.success("Document published live!", { id: toastId });
            setIsEditing(false);
            fetchDocs();
        } catch (err) {
            toast.error(err.message, { id: toastId });
        }
    };

    return (
        <div className="legal-container">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Legal & Policies</h1>
                    <p className="page-subtitle">Administrative oversight of user agreements and regulatory protocols.</p>
                </div>
                <div className="page-actions">
                    <button
                        onClick={() => setIsEditing(true)}
                        className="btn-primary"
                    >
                        <Plus size={20} /> Deploy Policy
                    </button>
                </div>
            </header>

            <div className="legal-grid">
                <div className="policy-list">
                    {docs.map(doc => (
                        <motion.div
                            key={doc.id}
                            initial={{ opacity: 0, x: -20 }}
                            animate={{ opacity: 1, x: 0 }}
                            className="glass-panel policy-card"
                            whileHover={{ scale: 1.01 }}
                        >
                            <div className="policy-icon">
                                <Shield size={28} />
                            </div>
                            <div className="policy-info">
                                <h3>{doc.title.toUpperCase()}</h3>
                                <div className="policy-badges">
                                    <span className="badge-type">{doc.role}</span>
                                    <span className="badge-version">V{doc.version}</span>
                                </div>
                                <div className="policy-date">
                                    <Clock size={14} /> Published {new Date(doc.published_at).toLocaleDateString()}
                                </div>
                            </div>
                            <ChevronRight size={24} className="policy-arrow" />
                        </motion.div>
                    ))}
                </div>

                <div className="glass-panel" style={{ padding: '40px', background: 'white', borderRadius: '40px', border: '1px solid rgba(0,0,0,0.03)' }}>
                    <h3 style={{ fontSize: '1.25rem', fontWeight: '800', color: '#0f172a', marginBottom: '30px', display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <Clock size={20} /> Acceptance Logs
                    </h3>
                    {auditLogs.length === 0 ? (
                        <div style={{ textAlign: 'center', padding: '40px 0' }}>
                            <Info size={40} color="#cbd5e1" style={{ margin: '0 auto 15px' }} />
                            <p style={{ color: '#94a3b8', fontWeight: '600' }}>No records found yet.</p>
                        </div>
                    ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                            {auditLogs.map(log => (
                                <div key={log.id} style={{ display: 'flex', gap: '15px' }}>
                                    <CheckCircle size={18} color="#22c55e" style={{ flexShrink: 0, marginTop: '2px' }} />
                                    <div>
                                        <p style={{ margin: 0, fontWeight: '800', fontSize: '0.9rem', color: '#0f172a' }}>{log.user_id ? `User ${log.user_id.slice(0, 8)}` : 'Anonymous'}</p>
                                        <p style={{ margin: 0, fontSize: '0.8rem', color: '#64748b' }}>Accepted version {log.accepted_version}</p>
                                        <p style={{ margin: '2px 0 0', fontSize: '0.7rem', color: '#94a3b8' }}>{new Date(log.accepted_at).toLocaleString()}</p>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>

            <AnimatePresence>
                {isEditing && (
                    <div style={{ position: 'fixed', inset: 0, zIndex: 9999, display: 'grid', placeItems: 'center', padding: '20px' }}>
                        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setIsEditing(false)} style={{ position: 'absolute', inset: 0, background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(10px)' }} />
                        <motion.div initial={{ opacity: 0, y: 30, scale: 0.95 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 30, scale: 0.95 }} style={{ position: 'relative', background: 'white', width: '100%', maxWidth: '700px', borderRadius: '40px', padding: '50px', boxShadow: '0 50px 100px -20px rgba(15,23,42,0.25)' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
                                <h2 style={{ fontSize: '1.6rem', fontWeight: '900', color: '#0F172A' }}>New Policy Document</h2>
                                <button onClick={() => setIsEditing(false)} style={{ background: '#f1f5f9', border: 'none', padding: '10px', borderRadius: '14px', cursor: 'pointer' }}><X size={20} /></button>
                            </div>
                            <form onSubmit={handlePublish} style={{ display: 'grid', gap: '20px' }}>
                                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
                                    <div>
                                        <label style={{ fontSize: '0.85rem', fontWeight: '800', color: '#64748b', marginBottom: '8px', display: 'block' }}>Document Title</label>
                                        <input required value={formData.title} onChange={e => setFormData({ ...formData, title: e.target.value })} style={{ width: '100%', padding: '15px', borderRadius: '12px', border: '2px solid #f1f5f9', fontWeight: '700' }} />
                                    </div>
                                    <div>
                                        <label style={{ fontSize: '0.85rem', fontWeight: '800', color: '#64748b', marginBottom: '8px', display: 'block' }}>Version</label>
                                        <input required value={formData.version} onChange={e => setFormData({ ...formData, version: e.target.value })} style={{ width: '100%', padding: '15px', borderRadius: '12px', border: '2px solid #f1f5f9', fontWeight: '700' }} />
                                    </div>
                                </div>
                                <div>
                                    <label style={{ fontSize: '0.85rem', fontWeight: '800', color: '#64748b', marginBottom: '8px', display: 'block' }}>Content</label>
                                    <textarea required rows={8} value={formData.content} onChange={e => setFormData({ ...formData, content: e.target.value })} style={{ width: '100%', padding: '15px', borderRadius: '12px', border: '2px solid #f1f5f9', fontWeight: '500', resize: 'vertical' }} />
                                </div>
                                <div style={{ display: 'flex', gap: '15px' }}>
                                    <button type="button" onClick={() => setIsEditing(false)} style={{ flex: 1, padding: '18px', borderRadius: '16px', border: 'none', background: '#f1f5f9', color: '#475569', fontWeight: '800' }}>Cancel</button>
                                    <button type="submit" style={{ flex: 1, padding: '18px', borderRadius: '16px', border: 'none', background: '#FFD600', color: '#0F172A', fontWeight: '900', boxShadow: '0 10px 20px rgba(255, 214, 0, 0.2)' }}>Publish Document</button>
                                </div>
                            </form>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default LegalPolicies;
