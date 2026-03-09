import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Save, RefreshCw, Globe, Shield, Bell, Zap, Activity, Navigation, CreditCard, AlertTriangle } from 'lucide-react';
import { supabase } from '../supabase';
import { toast } from 'react-hot-toast';
import './SystemSettings.css';

const SystemSettings = () => {
    const [settings, setSettings] = useState({
        platformName: 'UNIV Foods',
        supportEmail: 'support@univfoods.in',
        currency: 'INR (₹)',
        maintenanceMode: false,
        taxRate: 5,
        minOrderValue: 150,
        deliveryRadius: 15,
        codEnabled: true,
        maxCodValue: 2000,
        autoAssignRiders: true,
        supportPhone: '+919940407600',
        emergencyPhone: '100'
    });
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        fetchSettings();
    }, []);

    const fetchSettings = async () => {
        try {
            const { data } = await supabase.from('app_settings').select('*').eq('key', 'system_config').single();
            if (data?.value) setSettings({ ...settings, ...data.value });
        } catch (e) { console.error(e); }
        setLoading(false);
    };

    const handleSave = async (e) => {
        if (e) e.preventDefault();
        setSaving(true);
        try {
            const { error } = await supabase.from('app_settings').upsert({
                key: 'system_config',
                value: settings,
                updated_at: new Date().toISOString()
            });
            if (error) throw error;
            toast.success("System configurations deployed live.");
        } catch (error) {
            toast.error(error.message);
        }
        setSaving(false);
    };

    return (
        <div className="settings-page">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Command Center</h1>
                    <p className="page-subtitle">Real-time platform logic and operational constraints.</p>
                </div>
                <div className="page-actions">
                    <button
                        onClick={handleSave}
                        disabled={saving}
                        className="btn-deploy"
                    >
                        {saving ? <RefreshCw size={20} className="animate-spin" /> : <Zap size={20} />}
                        {saving ? 'SYNCING...' : 'DEPLOY LIVE'}
                    </button>
                </div>
            </header>

            <div className="settings-grid">
                {/* General Config */}
                <div className="glass-panel settings-card">
                    <div className="settings-card-header">
                        <Globe size={24} color="#FFD600" />
                        <h3 className="section-title">Core Identity</h3>
                    </div>
                    <div className="settings-input-group">
                        <div>
                            <label className="settings-label">Platform Title</label>
                            <input value={settings.platformName} onChange={e => setSettings({ ...settings, platformName: e.target.value })} className="settings-input" />
                        </div>
                        <div>
                            <label className="settings-label">Global Support Registry</label>
                            <input value={settings.supportEmail} onChange={e => setSettings({ ...settings, supportEmail: e.target.value })} className="settings-input" />
                        </div>
                        <div>
                            <label className="settings-label">Support Phone</label>
                            <input value={settings.supportPhone} onChange={e => setSettings({ ...settings, supportPhone: e.target.value })} className="settings-input" />
                        </div>
                        <div>
                            <label className="settings-label">Emergency Hotline</label>
                            <input value={settings.emergencyPhone} onChange={e => setSettings({ ...settings, emergencyPhone: e.target.value })} className="settings-input" />
                        </div>
                    </div>
                </div>

                {/* Logistics Control */}
                <div className="glass-panel settings-card">
                    <div className="settings-card-header">
                        <Navigation size={24} color="#FFD600" />
                        <h3 className="section-title">Logistics Radius</h3>
                    </div>
                    <div className="settings-input-group">
                        <div>
                            <label className="settings-label">Operational Radius (KM)</label>
                            <input type="number" value={settings.deliveryRadius} onChange={e => setSettings({ ...settings, deliveryRadius: e.target.value })} className="settings-input" />
                            <p style={{ fontSize: '0.7rem', color: '#64748b', marginTop: '8px', fontWeight: '600' }}>Changes reflect instantly during checkout validation.</p>
                        </div>
                        <div className="settings-toggle-row">
                            <span style={{ fontWeight: '800', color: '#475569', fontSize: '0.9rem' }}>Auto-Assign Riders</span>
                            <input type="checkbox" checked={settings.autoAssignRiders} onChange={e => setSettings({ ...settings, autoAssignRiders: e.target.checked })} className="settings-toggle" />
                        </div>
                    </div>
                </div>

                {/* Financial Safety */}
                <div className="glass-panel settings-card">
                    <div className="settings-card-header">
                        <CreditCard size={24} color="#FFD600" />
                        <h3 className="section-title">Financial Constraints</h3>
                    </div>
                    <div className="settings-input-group">
                        <div className="settings-toggle-row">
                            <span style={{ fontWeight: '800', color: '#475569', fontSize: '0.9rem' }}>Enable COD Globally</span>
                            <input type="checkbox" checked={settings.codEnabled} onChange={e => setSettings({ ...settings, codEnabled: e.target.checked })} className="settings-toggle" />
                        </div>
                        <div>
                            <label className="settings-label">Max COD Threshold (₹)</label>
                            <input type="number" value={settings.maxCodValue} onChange={e => setSettings({ ...settings, maxCodValue: e.target.value })} className="settings-input" />
                        </div>
                    </div>
                </div>

                {/* Emergency Measures */}
                <div className={`glass-panel settings-card ${settings.maintenanceMode ? 'maintenance-active' : ''}`}>
                    <div className="settings-card-header">
                        <AlertTriangle size={24} color="#ef4444" />
                        <h3 className="section-title">Danger Zone</h3>
                    </div>
                    <div className="settings-input-group">
                        <div className="settings-toggle-row" style={{ background: 'rgba(255,255,255,0.5)' }}>
                            <div>
                                <span style={{ fontWeight: '800', color: '#475569', fontSize: '0.9rem' }}>Maintenance Mode</span>
                                <p style={{ fontSize: '0.65rem', color: '#ef4444', fontWeight: '700', margin: '2px 0 0' }}>HALTS ALL TRANSACTIONS</p>
                            </div>
                            <input type="checkbox" checked={settings.maintenanceMode} onChange={e => setSettings({ ...settings, maintenanceMode: e.target.checked })} className="settings-toggle" />
                        </div>
                    </div>
                </div>
            </div>

        </div>
    );
};

const inputStyle = {
    width: '100%',
    padding: '16px 20px',
    borderRadius: '14px',
    border: '2px solid #f1f5f9',
    outline: 'none',
    fontSize: '1rem',
    fontWeight: '700',
    color: '#0f172a',
    background: 'white',
    transition: 'border-color 0.2s'
};

const toggleStyle = {
    width: '44px',
    height: '24px',
    cursor: 'pointer'
};

export default SystemSettings;
