import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';
import { Search, Lock, UserX, AlertTriangle, Eye, Shield, CreditCard, ShoppingBag, XCircle, Ban, DollarSign, Activity, RefreshCw } from 'lucide-react';
import { toast } from 'react-hot-toast';
import { motion, AnimatePresence } from 'framer-motion';
import './Customers.css';

const Customers = () => {
    const [customers, setCustomers] = useState([]);
    const [search, setSearch] = useState('');
    const [loading, setLoading] = useState(true);
    const [selectedCustomer, setSelectedCustomer] = useState(null);

    useEffect(() => {
        fetchCustomers();
        const sub = supabase.channel('customers-live-extreme')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'customer_profiles' }, fetchCustomers)
            .subscribe();
        return () => sub.unsubscribe();
    }, []);

    const fetchCustomers = async () => {
        try {
            const { data, error } = await supabase.from('customer_profiles')
                .select('*')
                .order('created_at', { ascending: false });
            if (data) setCustomers(data);
            if (error) console.error(error);
        } catch (e) {
            console.error(e);
        } finally {
            setLoading(false);
        }
    };

    const handleUpdate = async (id, updates) => {
        const { error } = await supabase.from('customer_profiles').update(updates).eq('id', id);
        if (error) toast.error(error.message);
        else {
            toast.success("Account updated instantly.");
            if (selectedCustomer && selectedCustomer.id === id) {
                setSelectedCustomer({ ...selectedCustomer, ...updates });
            }
        }
    };

    const simulateCustomer = async () => {
        const testUser = {
            id: crypto.randomUUID(),
            full_name: "Simulated User " + Math.floor(Math.random() * 1000),
            phone: "+91 8877" + Math.floor(Math.random() * 100000),
            email: `user${Math.floor(Math.random() * 1000)}@sim.com`,
            wallet_balance: Math.floor(Math.random() * 1000),
            total_orders: Math.floor(Math.random() * 20),
            total_spent: Math.floor(Math.random() * 5000),
            is_blocked: false,
            created_at: new Date().toISOString()
        };
        const { error } = await supabase.from('customer_profiles').insert([testUser]);
        if (error) toast.error("Simulation Failed: " + error.message);
        else toast.success(`Simulated ${testUser.full_name} established on the grid!`);
    };

    const filtered = customers.filter(c =>
        (c.full_name && c.full_name.toLowerCase().includes(search.toLowerCase())) ||
        (c.phone && c.phone.includes(search)) ||
        (c.email && c.email.toLowerCase().includes(search.toLowerCase()))
    );

    return (
        <div className="customers-container">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Customer Control Center</h1>
                    <p className="page-subtitle">Real-time monitoring and advanced account restrictions.</p>
                </div>
                <div className="page-actions">
                    <button onClick={simulateCustomer} className="btn-primary" style={{ background: '#0F172A', color: 'white' }}>
                        <RefreshCw size={18} color="#FFD600" style={{ marginRight: '8px' }} /> SIMULATE CUSTOMER
                    </button>
                    <div className="glass-panel connection-status">
                        <div className="pulse-green"></div>
                        <span>{customers.length} CONNECTED</span>
                    </div>
                </div>
            </header>

            <div className="glass-panel search-field customers-search">
                <Search size={20} color="#64748b" />
                <input
                    placeholder="Search by name, phone, or email..."
                    value={search} onChange={e => setSearch(e.target.value)}
                />
            </div>

            <div className="glass-panel" style={{ background: 'white', padding: '0', borderRadius: '30px', overflow: 'hidden' }}>
                <div style={{ overflowX: 'auto' }}>
                    <table className="responsive-table">
                        <thead>
                            <tr>
                                <th>Customer Entity</th>
                                <th>Stats Array</th>
                                <th>Finance / Total</th>
                                <th>Link Status</th>
                                <th style={{ textAlign: 'right' }}>Direct Control</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                <tr>
                                    <td colSpan="5">
                                        <div className="loader-container">
                                            <div className="establishing-connection">
                                                <div className="spinner-premium"></div>
                                                Establishing secure connection...
                                            </div>
                                        </div>
                                    </td>
                                </tr>
                            ) : filtered.length === 0 ? (
                                <tr>
                                    <td colSpan="5" style={{ textAlign: 'center', padding: '100px 0', fontSize: '1.1rem', fontWeight: '800', color: '#94a3b8' }}>
                                        Zero nodes detected in current cluster.
                                    </td>
                                </tr>
                            ) : (
                                filtered.map(customer => (
                                    <tr key={customer.id} className={customer.is_blocked ? 'row-blocked' : ''}>
                                        <td data-label="Entity">
                                            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                                                <div className={`entity-avatar ${customer.is_blocked ? 'blocked' : ''}`}>
                                                    {customer.full_name?.[0] || 'U'}
                                                </div>
                                                <div>
                                                    <div className="entity-name">{customer.full_name || 'Guest User'}</div>
                                                    <div className="entity-phone">{customer.phone || 'NO_PHONE_LINK'}</div>
                                                </div>
                                            </div>
                                        </td>
                                        <td data-label="Stats">
                                            <div className="customer-stats-container">
                                                <div className="stat-box" title="Total Orders">
                                                    <div className="stat-value">{customer.total_orders || 0}</div>
                                                    <div className="stat-label">ORDERS</div>
                                                </div>
                                                <div className="stat-box" title="Cancellations">
                                                    <div className={`stat-value ${customer.cancel_count > 2 ? 'text-danger' : ''}`}>{customer.cancel_count || 0}</div>
                                                    <div className="stat-label">CANCELS</div>
                                                </div>
                                            </div>
                                        </td>
                                        <td data-label="Finance">
                                            <div className="finance-cell">
                                                <div className="wallet-value">₹{customer.wallet_balance || 0}</div>
                                                <div className="spent-label">Aggregated: ₹{customer.total_spent || 0}</div>
                                            </div>
                                        </td>
                                        <td data-label="Status">
                                            <div className="status-container">
                                                <span className={`status-pill ${customer.is_blocked ? 'blocked' : 'active'}`}>
                                                    {customer.is_blocked ? 'DECOMMISSIONED' : 'OPERATIONAL'}
                                                </span>
                                                {customer.cod_disabled && (
                                                    <span className="status-pill warning">COD LOCK ACTIVE</span>
                                                )}
                                            </div>
                                        </td>
                                        <td data-label="Actions" style={{ textAlign: 'right' }}>
                                            <div className="action-group">
                                                <button
                                                    onClick={() => setSelectedCustomer(customer)}
                                                    className="action-btn btn-view"
                                                    title="Interrogate Profile"
                                                >
                                                    <Eye size={18} />
                                                </button>
                                                <button
                                                    onClick={() => handleUpdate(customer.id, { is_blocked: !customer.is_blocked })}
                                                    className={`action-btn ${customer.is_blocked ? 'btn-unblock-toggle' : 'btn-block-toggle'}`}
                                                    title={customer.is_blocked ? 'Reactivate Node' : 'Terminate Link'}
                                                >
                                                    {customer.is_blocked ? <Shield size={18} /> : <Ban size={18} />}
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

            {/* Profile Detail Modal */}
            <AnimatePresence>
                {selectedCustomer && (
                    <div className="modal-overlay" onClick={() => setSelectedCustomer(null)}>
                        <motion.div
                            initial={{ scale: 0.9, y: 30, opacity: 0 }}
                            animate={{ scale: 1, y: 0, opacity: 1 }}
                            exit={{ scale: 0.9, y: 30, opacity: 0 }}
                            className="glass-panel customer-modal-card"
                            onClick={e => e.stopPropagation()}
                        >
                            <div className="modal-header-banner">
                                <button className="close-btn-modal" onClick={() => setSelectedCustomer(null)}><XCircle size={24} /></button>
                                <div className="modal-profile-header">
                                    <div className="modal-avatar">
                                        {selectedCustomer.full_name?.[0] || 'U'}
                                    </div>
                                    <div className="modal-title-info">
                                        <h2>{selectedCustomer.full_name || 'Anonymous Node'}</h2>
                                        <p>{selectedCustomer.phone} • {selectedCustomer.email || 'NO_EMAIL_DETECTED'}</p>
                                        <div className="id-badge">IDENT: {selectedCustomer.id}</div>
                                    </div>
                                </div>
                            </div>

                            <div className="modal-body-content">
                                <div className="modal-stats-grid">
                                    <div className="modal-stat-card finance">
                                        <p className="card-label">Transactional Volume</p>
                                        <h3 className="card-value">₹{selectedCustomer.wallet_balance || 0}</h3>
                                        <p className="card-subtext">Total Spent: ₹{selectedCustomer.total_spent || 0}</p>
                                    </div>
                                    <div className="modal-stat-card reliability">
                                        <p className="card-label">Network Reliability</p>
                                        <h3 className="card-value">{selectedCustomer.total_orders || 0} <span>Missions</span></h3>
                                        <p className={`card-subtext ${selectedCustomer.cancel_count > 2 ? 'text-danger' : 'text-success'}`}>{selectedCustomer.cancel_count || 0} Signal Drops</p>
                                    </div>
                                </div>

                                <div className="controls-section">
                                    <h4>Command Protocols</h4>

                                    <div className="control-row">
                                        <div className="control-info">
                                            <Ban size={20} color="#ef4444" />
                                            <div>
                                                <div className="control-name">Decommission Account</div>
                                                <p className="control-desc">Terminate all platform link access</p>
                                            </div>
                                        </div>
                                        <button
                                            onClick={() => handleUpdate(selectedCustomer.id, { is_blocked: !selectedCustomer.is_blocked })}
                                            className={`control-btn ${selectedCustomer.is_blocked ? 'active-block' : ''}`}
                                        >
                                            {selectedCustomer.is_blocked ? 'OPERATIONALIZE' : 'TERMINATE LINK'}
                                        </button>
                                    </div>

                                    <div className="control-row">
                                        <div className="control-info">
                                            <DollarSign size={20} color="#f59e0b" />
                                            <div>
                                                <div className="control-name">Restrict Signal (COD)</div>
                                                <p className="control-desc">Mandate digital-only settlement</p>
                                            </div>
                                        </div>
                                        <button
                                            onClick={() => handleUpdate(selectedCustomer.id, { cod_disabled: !selectedCustomer.cod_disabled })}
                                            className={`control-btn warning ${selectedCustomer.cod_disabled ? 'active-warning' : ''}`}
                                        >
                                            {selectedCustomer.cod_disabled ? 'RESTORE COD' : 'RESTRICT NOW'}
                                        </button>
                                    </div>

                                    <div className="control-row">
                                        <div className="control-info">
                                            <Activity size={20} color="#06b6d4" />
                                            <div>
                                                <div className="control-name">Transmission Threshold</div>
                                                <p className="control-desc">Cap: ₹{selectedCustomer.max_order_limit || 5000}</p>
                                            </div>
                                        </div>
                                        <div className="limit-input-container">
                                            <span>₹</span>
                                            <input
                                                type="number"
                                                placeholder="Limit"
                                                onBlur={(e) => handleUpdate(selectedCustomer.id, { max_order_limit: parseFloat(e.target.value) })}
                                                className="limit-input"
                                            />
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>

        </div>
    );
};

export default Customers;
