import React, { useState, useEffect } from 'react';
import { Settings as SettingsIcon, Save } from 'lucide-react';
import { supabase } from '../supabase';

const Settings = () => {
    const [config, setConfig] = useState({
        name: 'UNIV Foods',
        currency: 'USD ($)',
        tax_rate: 5,
        delivery_fee: 10
    });
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        fetchSettings();
    }, []);

    const fetchSettings = async () => {
        try {
            const { data, error } = await supabase
                .from('app_settings')
                .select('value')
                .eq('key', 'platform_config')
                .single();

            if (data?.value) {
                setConfig(data.value);
            }
        } catch (err) {
            console.error('Error fetching settings:', err);
        } finally {
            setLoading(false);
        }
    };

    const handleSave = async () => {
        setSaving(true);
        try {
            const { error } = await supabase
                .from('app_settings')
                .upsert({
                    key: 'platform_config',
                    value: config,
                    updated_at: new Date().toISOString()
                });

            if (error) throw error;
            alert('Settings saved successfully!');
        } catch (err) {
            alert('Error saving settings: ' + err.message);
        } finally {
            setSaving(false);
        }
    };

    return (
        <div style={{ padding: '40px', background: 'transparent', minHeight: '100vh' }}>
            <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '60px', flexWrap: 'wrap', gap: '24px' }}>
                <div>
                    <h1 style={{ fontSize: '2.8rem', fontWeight: '900', color: '#1B5E20', letterSpacing: '-0.04em', lineHeight: 1.1 }}>Core <span style={{ color: '#FFD600' }}>Control</span></h1>
                    <p style={{ color: '#667C68', fontSize: '1.1rem', fontWeight: '600', marginTop: '8px' }}>Configure global platform parameters and network variables.</p>
                </div>
            </header>

            <div className="glass-panel" style={{ padding: '2rem', maxWidth: '800px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '2rem', paddingBottom: '1rem', borderBottom: '1px solid #eee' }}>
                    <SettingsIcon size={24} className="text-primary" />
                    <h3 style={{ margin: 0 }}>General Configuration</h3>
                </div>

                {loading ? (
                    <p>Loading configuration...</p>
                ) : (
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
                        <div className="form-group">
                            <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '500' }}>Platform Name</label>
                            <input
                                type="text"
                                value={config.name}
                                onChange={e => setConfig({ ...config, name: e.target.value })}
                                className="input-field"
                                style={{ width: '100%', padding: '0.8rem', borderRadius: '8px', border: '1px solid #ddd' }}
                            />
                        </div>

                        <div className="form-group">
                            <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '500' }}>Currency Symbol</label>
                            <select
                                value={config.currency}
                                onChange={e => setConfig({ ...config, currency: e.target.value })}
                                style={{ width: '100%', padding: '0.8rem', borderRadius: '8px', border: '1px solid #ddd' }}
                            >
                                <option>USD ($)</option>
                                <option>INR (₹)</option>
                                <option>GBP (£)</option>
                                <option>EUR (€)</option>
                            </select>
                        </div>

                        <div className="form-group">
                            <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '500' }}>Default Tax Rate (%)</label>
                            <input
                                type="number"
                                value={config.tax_rate}
                                onChange={e => setConfig({ ...config, tax_rate: parseFloat(e.target.value) })}
                                className="input-field"
                                style={{ width: '100%', padding: '0.8rem', borderRadius: '8px', border: '1px solid #ddd' }}
                            />
                        </div>

                        <div className="form-group">
                            <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: '500' }}>Base Delivery Fee</label>
                            <input
                                type="number"
                                value={config.delivery_fee}
                                onChange={e => setConfig({ ...config, delivery_fee: parseFloat(e.target.value) })}
                                className="input-field"
                                style={{ width: '100%', padding: '0.8rem', borderRadius: '8px', border: '1px solid #ddd' }}
                            />
                        </div>

                        <div style={{ gridColumn: '1 / -1', marginTop: '1rem' }}>
                            <button
                                onClick={handleSave}
                                disabled={saving}
                                className="btn btn-primary"
                                style={{
                                    width: '100%',
                                    padding: '1rem',
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    gap: '0.5rem',
                                    opacity: saving ? 0.7 : 1
                                }}
                            >
                                <Save size={20} />
                                {saving ? 'Saving...' : 'Save Configuration'}
                            </button>
                        </div>
                    </div>
                )}

                {/* PRO Features Tabs */}
                {!loading && (
                    <div style={{ marginTop: '60px' }}>
                        <div style={{ display: 'flex', gap: '32px', borderBottom: '2px solid #F4F7FE', marginBottom: '40px' }}>
                            {['Logistics Zones', 'Relay Versions', 'Network Flags', 'Visual Banners'].map((tab, i) => (
                                <button key={tab} style={{ padding: '16px 0', background: 'transparent', border: 'none', borderBottom: i === 0 ? '4px solid #1B5E20' : 'none', color: i === 0 ? '#1B5E20' : '#94A3B8', fontWeight: '900', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: '0.1em', cursor: 'pointer' }}>{tab}</button>
                            ))}
                        </div>

                        {/* Delivery Zone Section */}
                        <div style={{ background: '#F8FAFC', padding: '40px', borderRadius: '32px' }}>
                            <h4 style={{ fontSize: '1.2rem', fontWeight: '900', color: '#0F172A', marginBottom: '24px' }}>Service Radius & Spatial Zones</h4>
                            <div style={{ maxWidth: '400px' }}>
                                <label style={{ fontSize: '0.85rem', fontWeight: '900', color: '#667C68', marginBottom: '8px', display: 'block', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Operational Radius (km)</label>
                                <input
                                    type="number"
                                    value={config.service_radius || 10}
                                    onChange={e => setConfig({ ...config, service_radius: parseFloat(e.target.value) })}
                                    style={{ width: '100%', padding: '18px', borderRadius: '16px', border: '2px solid #FFF', outline: 'none', fontSize: '1.1rem', fontWeight: '800', color: '#0F172A', background: 'white' }}
                                />
                                <p style={{ color: '#667C68', fontSize: '0.85rem', fontWeight: '600', marginTop: '12px' }}>Maximum geospatial distance for partner deployments.</p>
                            </div>
                        </div>

                        <div style={{ marginTop: '40px', padding: '32px', background: 'linear-gradient(135deg, #1B5E20 0%, #0F172A 100%)', borderRadius: '32px', color: 'white', position: 'relative', overflow: 'hidden' }}>
                            <div style={{ position: 'relative', zIndex: 1 }}>
                                <h4 style={{ fontSize: '1.3rem', fontWeight: '900', color: '#FFD600', marginBottom: '12px' }}>🚀 Edge Integration Enabled</h4>
                                <p style={{ opacity: 0.9, lineHeight: 1.6, fontWeight: '600', margin: 0 }}>Terminal access to real-time relay cycles. Changes deployed here propagate instantly to all client nodes across the global logistics grid.</p>
                            </div>
                            <div style={{ position: 'absolute', right: '-20px', bottom: '-20px', fontSize: '120px', opacity: 0.05, fontWeight: '900' }}>PRO</div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
};

export default Settings;
