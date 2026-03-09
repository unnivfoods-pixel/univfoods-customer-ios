import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { HelpCircle, Plus, Search, Trash2, Edit2, Check, X, Tag, Info, AlertTriangle, ShieldCheck, Clock } from 'lucide-react';
import { supabase } from '../supabase';
import { toast } from 'react-hot-toast';
import './Faqs.css';

const Faqs = () => {
    const [faqs, setFaqs] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [editingId, setEditingId] = useState(null);
    const [editForm, setEditForm] = useState({ question: '', answer: '', category: 'General' });
    const [showNewFaq, setShowNewFaq] = useState(false);

    const categories = ['Orders', 'Payments', 'Refunds', 'Delivery', 'Account', 'Safety', 'General'];

    useEffect(() => {
        fetchFaqs();
        const sub = supabase.channel('faqs-live')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'faqs' }, fetchFaqs)
            .subscribe();
        return () => sub.unsubscribe();
    }, []);

    const fetchFaqs = async () => {
        try {
            const { data, error } = await supabase.from('faqs').select('*').order('created_at', { ascending: false });
            if (error) throw error;
            setFaqs(data || []);
        } catch (err) {
            console.error("Fetch Error:", err);
            // toast.error("Tactical connection to FAQ database failed.");
        } finally {
            setLoading(false);
        }
    };

    const handleSaveNew = async () => {
        if (!editForm.question || !editForm.answer) {
            toast.error("Intel incomplete. Question and Answer required.");
            return;
        }

        try {
            const { error } = await supabase.from('faqs').insert([{
                ...editForm,
                active_status: true
            }]);
            if (error) throw error;
            toast.success("New FAQ deployed to Neural Network.");
            setShowNewFaq(false);
            setEditForm({ question: '', answer: '', category: 'General' });
            fetchFaqs();
        } catch (err) {
            toast.error(err.message);
        }
    };

    const handleUpdate = async (id) => {
        try {
            const { error } = await supabase.from('faqs').update(editForm).eq('id', id);
            if (error) throw error;
            toast.success("FAQ parameters recalibrated.");
            setEditingId(null);
            fetchFaqs();
        } catch (err) {
            toast.error(err.message);
        }
    };

    const handleDelete = async (id) => {
        if (!confirm("Permanently delete this FAQ? This action is irreversible.")) return;
        try {
            const { error } = await supabase.from('faqs').delete().eq('id', id);
            if (error) throw error;
            toast.success("Intel purged from database.");
            fetchFaqs();
        } catch (err) {
            toast.error(err.message);
        }
    };

    const filteredFaqs = faqs.filter(f =>
        f.question?.toLowerCase().includes(search.toLowerCase()) ||
        f.category?.toLowerCase().includes(search.toLowerCase())
    );

    return (
        <div className="faqs-container">
            <header className="page-header">
                <div>
                    <h1 className="page-title">FAQ Control Center</h1>
                    <p className="page-subtitle">Manage tactical intelligence for customer self-service.</p>
                </div>
                <button className="btn-add-faq" onClick={() => setShowNewFaq(true)}>
                    <Plus size={20} />
                    NEW FAQ
                </button>
            </header>

            <div className="faq-toolbar">
                <div className="search-box">
                    <Search size={18} className="search-icon" />
                    <input
                        type="text"
                        placeholder="Search intel by keywords..."
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                    />
                </div>
                <div className="stats-badge">
                    <ShieldCheck size={14} />
                    {faqs.length} KNOWLEDGE NODES ACTIVE
                </div>
            </div>

            <div className="faq-grid">
                <AnimatePresence>
                    {showNewFaq && (
                        <motion.div
                            initial={{ opacity: 0, y: -20 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: -20 }}
                            className="faq-card new-faq-card"
                        >
                            <div className="card-header">
                                <span className="category-tag new">NEW NODE</span>
                                <div className="card-actions">
                                    <button onClick={handleSaveNew} className="action-btn save"><Check size={16} /></button>
                                    <button onClick={() => setShowNewFaq(false)} className="action-btn cancel"><X size={16} /></button>
                                </div>
                            </div>
                            <select
                                value={editForm.category}
                                onChange={e => setEditForm({ ...editForm, category: e.target.value })}
                                className="faq-select"
                            >
                                {categories.map(c => <option key={c} value={c}>{c}</option>)}
                            </select>
                            <input
                                className="faq-input question"
                                placeholder="Tactical Question?"
                                value={editForm.question}
                                onChange={e => setEditForm({ ...editForm, question: e.target.value })}
                            />
                            <textarea
                                className="faq-textarea"
                                placeholder="Mission Solution Address..."
                                value={editForm.answer}
                                onChange={e => setEditForm({ ...editForm, answer: e.target.value })}
                            />
                        </motion.div>
                    )}

                    {filteredFaqs.map(faq => (
                        <motion.div
                            key={faq.id}
                            layout
                            className={`faq-card ${editingId === faq.id ? 'editing' : ''}`}
                        >
                            <div className="card-header">
                                <span className="category-tag">{faq.category}</span>
                                <div className="card-actions">
                                    {editingId === faq.id ? (
                                        <>
                                            <button onClick={() => handleUpdate(faq.id)} className="action-btn save"><Check size={16} /></button>
                                            <button onClick={() => setEditingId(null)} className="action-btn cancel"><X size={16} /></button>
                                        </>
                                    ) : (
                                        <>
                                            <button onClick={() => {
                                                setEditingId(faq.id);
                                                setEditForm({ question: faq.question, answer: faq.answer, category: faq.category });
                                            }} className="action-btn edit"><Edit2 size={16} /></button>
                                            <button onClick={() => handleDelete(faq.id)} className="action-btn delete"><Trash2 size={16} /></button>
                                        </>
                                    )}
                                </div>
                            </div>

                            {editingId === faq.id ? (
                                <>
                                    <select
                                        value={editForm.category}
                                        onChange={e => setEditForm({ ...editForm, category: e.target.value })}
                                        className="faq-select"
                                    >
                                        {categories.map(c => <option key={c} value={c}>{c}</option>)}
                                    </select>
                                    <input
                                        className="faq-input question"
                                        value={editForm.question}
                                        onChange={e => setEditForm({ ...editForm, question: e.target.value })}
                                    />
                                    <textarea
                                        className="faq-textarea"
                                        value={editForm.answer}
                                        onChange={e => setEditForm({ ...editForm, answer: e.target.value })}
                                    />
                                </>
                            ) : (
                                <>
                                    <h3 className="faq-question">{faq.question}</h3>
                                    <p className="faq-answer">{faq.answer}</p>
                                    <div className="faq-footer">
                                        <Clock size={12} />
                                        <span>LAST SYNC: {new Date(faq.updated_at || faq.created_at).toLocaleString()}</span>
                                    </div>
                                </>
                            )}
                        </motion.div>
                    ))}
                </AnimatePresence>
            </div>

            {!loading && filteredFaqs.length === 0 && (
                <div className="empty-state">
                    <Info size={48} />
                    <h3>No intelligence nodes matches the query.</h3>
                    <p>Broaden your search or deploy a new FAQ node.</p>
                </div>
            )}
        </div>
    );
};

export default Faqs;
