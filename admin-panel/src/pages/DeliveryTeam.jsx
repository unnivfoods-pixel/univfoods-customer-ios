import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';
import { useLocation } from 'react-router-dom';
import { MapPin, Phone, Circle, Plus, Trash2, Map as MapIcon, Power, AlertTriangle, RefreshCw, ExternalLink, Star } from 'lucide-react';

import { toast } from 'react-hot-toast';
import { motion, AnimatePresence } from 'framer-motion';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import './DeliveryTeam.css';

// Fix Leaflet Icons
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const riderIcon = new L.Icon({
    iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-gold.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41]
});

const vendorIcon = new L.Icon({
    iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-orange.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41]
});

const customerIcon = new L.Icon({
    iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-blue.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41]
});

const DeliveryTeam = () => {
    const location = useLocation();
    const [riders, setRiders] = useState([]);
    const [vendors, setVendors] = useState([]);
    const [activeOrders, setActiveOrders] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [showAddModal, setShowAddModal] = useState(false);
    const [viewMode, setViewMode] = useState('list'); // 'list' or 'map'
    const [newRider, setNewRider] = useState({ name: '', phone: '', status: 'Offline', vehicle_number: '' });

    useEffect(() => {
        if (location.state?.registrationData) {
            const reg = location.state.registrationData;
            setNewRider({
                id: reg.owner_id || reg.id,
                name: reg.name,
                phone: reg.phone,
                email: reg.email,
                status: 'Offline',
                vehicle_number: ''
            });
            setShowAddModal(true);
        }
    }, [location]);

    useEffect(() => {
        fetchRiders();
        fetchVendors();
        fetchActiveOrders();
        const channel = supabase.channel('logistics-grid-central-v16')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'delivery_riders' }, fetchRiders)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, fetchActiveOrders)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'delivery_live_location' }, (payload) => {
                setRiders(prev => prev.map(r => r.id === payload.new.delivery_id ? {
                    ...r,
                    current_lat: payload.new.latitude,
                    current_lng: payload.new.longitude,
                    last_location_update: payload.new.updated_at
                } : r));
            })
            .subscribe();
        return () => channel.unsubscribe();
    }, []);

    const fetchVendors = async () => {
        const { data } = await supabase.from('vendors').select('*');
        if (data) setVendors(data);
    };

    const fetchActiveOrders = async () => {
        const { data } = await supabase.from('orders')
            .select(`*, vendors(name, address), customer_profiles(full_name)`)
            .not('status', 'in', '("delivered","cancelled")');
        if (data) setActiveOrders(data);
    };

    const fetchRiders = async () => {
        const { data: riders } = await supabase.from('delivery_riders').select('*').order('name');
        const { data: liveData } = await supabase.from('delivery_live_location').select('*');

        if (riders) {
            const enriched = riders.map(r => {
                const live = liveData?.find(l => l.delivery_id === r.id);
                return {
                    ...r,
                    current_lat: live?.latitude || r.last_lat,
                    current_lng: live?.longitude || r.last_lng,
                    last_location_update: live?.updated_at || r.last_active_at
                };
            });
            setRiders(enriched);
        }
        setLoading(false);
    };

    const getGpsStatus = (lastUpdate) => {
        if (!lastUpdate) return { label: 'NO GPS', color: '#94a3b8' };
        const diff = (new Date() - new Date(lastUpdate)) / 1000;
        if (diff > 30) return { label: 'GPS LOST', color: '#ef4444', icon: true };
        return { label: 'LIVE', color: '#10b981' };
    };

    // Assuming searchTerm is defined elsewhere, e.g., via useState:
    // const [searchTerm, setSearchTerm] = useState('');
    const filteredRiders = riders.filter(r => r.name?.toLowerCase().includes(searchTerm.toLowerCase()));

    const handleAddRider = async (e) => {
        e.preventDefault();
        const { error } = await supabase.from('delivery_riders').insert([{
            ...newRider,
            kyc_status: 'ACTIVE',
            is_approved: true,
            is_online: false,
            status: 'Offline',
            current_lat: 17.3850,
            current_lng: 78.4867
        }]);
        if (error) alert('Error: ' + error.message);
        else {
            setShowAddModal(false);
            setNewRider({ name: '', phone: '', status: 'Offline', vehicle_number: '' });
            alert('Rider Registered! KYC Pending.');
            fetchRiders();
        }
    };

    const handleApproveKYC = async (id, status) => {
        const updateData = { kyc_status: status };
        if (status === 'ACTIVE') {
            updateData.is_approved = true;
            updateData.status = 'Offline';
        }
        await supabase.from('delivery_riders').update(updateData).eq('id', id);
        fetchRiders();
    };

    const toggleStatus = async (rider) => {
        const newOnline = !rider.is_online;
        await supabase.from('delivery_riders').update({
            is_online: newOnline,
            status: newOnline ? 'Online' : 'Offline'
        }).eq('id', rider.id);
        fetchRiders();
    };

    const simulateRider = async () => {
        const testRider = {
            name: "Flash Rider " + Math.floor(Math.random() * 100),
            phone: "+91 91234 56" + Math.floor(Math.random() * 9) + Math.floor(Math.random() * 9),
            status: 'Online',
            is_online: true,
            kyc_status: 'ACTIVE',
            is_approved: true,
            current_lat: 9.5100 + (Math.random() - 0.5) * 0.02,
            current_lng: 77.6300 + (Math.random() - 0.5) * 0.02,
            last_location_update: new Date().toISOString(),
            vehicle_number: 'TN-67-' + Math.floor(Math.random() * 9000 + 1000)
        };
        const { error } = await supabase.from('delivery_riders').insert([testRider]);
        if (error) toast.error("Deployment Failed: " + error.message);
        else toast.success(`Unit ${testRider.name} is now on the grid!`);
    };

    return (
        <div className="delivery-team-container">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Fleet Team</h1>
                    <p className="page-subtitle">Logistics unit management and live grid transmissions.</p>
                </div>
                <div className="page-actions">
                    <button onClick={simulateRider} className="btn-primary" style={{ background: '#0F172A', color: 'white' }}>
                        <RefreshCw size={18} color="#FFD600" style={{ marginRight: '8px' }} /> SIMULATE RIDER
                    </button>
                    <div className="glass-panel btn-view-mode-toggle" style={{ background: 'white', padding: '6px', borderRadius: '18px', display: 'flex', border: 'none' }}>
                        <button onClick={() => setViewMode('list')} style={{ padding: '10px 24px', borderRadius: '12px', background: viewMode === 'list' ? '#FFD600' : 'transparent', color: '#0F172A', fontWeight: '800', transition: 'all 0.3s', border: 'none' }}>Grid</button>
                        <button onClick={() => setViewMode('map')} style={{ padding: '10px 24px', borderRadius: '12px', background: viewMode === 'map' ? '#FFD600' : 'transparent', color: '#0F172A', fontWeight: '800', transition: 'all 0.3s', display: 'flex', alignItems: 'center', gap: '8px', border: 'none' }}>
                            <MapIcon size={18} /> Spatial
                        </button>
                    </div>
                    <button
                        className="btn-primary"
                        onClick={() => setShowAddModal(true)}
                        style={{ background: '#FFD600', color: '#0F172A' }}
                    >
                        <Plus size={22} /> Deploy Unit
                    </button>
                </div>
            </header>

            {/* MAP VIEW: ENHANCED LOGISTICS GRID */}
            {viewMode === 'map' && (
                <div className="glass-panel" style={{ height: 'calc(100vh - 250px)', width: '100%', padding: 0, overflow: 'hidden', borderRadius: '32px', border: 'none', boxShadow: '0 20px 40px rgba(0,0,0,0.1)' }}>
                    <MapContainer center={[9.5120, 77.6320]} zoom={14} style={{ height: '100%', width: '100%' }}>
                        <TileLayer url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png" />

                        {/* 1. RENDER RIDERS */}
                        {riders.map(rider => {
                            const gpsStatus = getGpsStatus(rider.last_location_update);
                            return (
                                <Marker
                                    key={`rider-${rider.id}`}
                                    position={[rider.current_lat || 9.512, rider.current_lng || 77.632]}
                                    icon={riderIcon}
                                >
                                    <Popup>
                                        <div style={{ padding: '4px' }}>
                                            <strong style={{ fontSize: '1.1rem' }}>RIDER: {rider.name}</strong><br />
                                            <span style={{ color: rider.is_online ? '#10b981' : '#64748b', fontWeight: 'bold' }}>
                                                {rider.is_online ? '● ONLINE' : '○ OFFLINE'}
                                            </span><br />
                                            {gpsStatus.label === 'GPS LOST' && <span style={{ color: '#ef4444', fontWeight: '900' }}>⚠️ GPS LOST ({Math.round((new Date() - new Date(rider.last_location_update)) / 1000)}s)</span>}
                                            <div style={{ marginTop: '8px' }}>
                                                Unit Status: {rider.status}<br />
                                                Contact: {rider.phone}
                                            </div>
                                        </div>
                                    </Popup>
                                </Marker>
                            );
                        })}

                        {/* 2. RENDER VENDORS */}
                        {vendors.map(vendor => (
                            <Marker
                                key={`vendor-${vendor.id}`}
                                position={[vendor.latitude || 9.512, vendor.longitude || 77.632]}
                                icon={vendorIcon}
                            >
                                <Popup>
                                    <strong>RESTAURANT: {vendor.name}</strong><br />
                                    {vendor.address}<br />
                                    Status: {vendor.status}
                                </Popup>
                            </Marker>
                        ))}

                        {/* 3. RENDER ACTIVE MISSIONS (CUSTOMERS) */}
                        {activeOrders.map(order => (
                            <Marker
                                key={`order-${order.id}`}
                                position={[order.delivery_lat || 9.515, order.delivery_long || 77.635]}
                                icon={customerIcon}
                            >
                                <Popup>
                                    <div style={{ minWidth: '150px' }}>
                                        <strong style={{ color: '#3b82f6' }}>MISSON: {order.status.toUpperCase()}</strong><br />
                                        <span>Customer: {order.customer_profiles?.full_name || 'Guest'}</span><br />
                                        <div style={{ marginTop: '5px', background: '#f1f5f9', padding: '8px', borderRadius: '8px' }}>
                                            <strong>Analytics:</strong><br />
                                            ETA: {order.eta_minutes || '?'} mins<br />
                                            Distance: {order.distance_remaining_km?.toFixed(2) || '0.00'} km
                                        </div>
                                    </div>
                                </Popup>
                            </Marker>
                        ))}
                    </MapContainer>
                </div>
            )}

            {/* LIST VIEW */}
            {viewMode === 'list' && (
                <div className="glass-panel" style={{ background: 'white', padding: '40px' }}>
                    <div style={{ overflowX: 'auto' }}>
                        <table className="responsive-table" style={{ width: '100%', borderCollapse: 'separate', borderSpacing: '0 20px' }}>
                            <thead>
                                <tr style={{ color: '#94A3B8', fontSize: '0.85rem', fontWeight: '900', textAlign: 'left', textTransform: 'uppercase', letterSpacing: '0.1em' }}>
                                    <th style={{ padding: '0 20px' }}>Unit Identity</th>
                                    <th style={{ padding: '0 20px' }}>Rating</th>
                                    <th style={{ padding: '0 20px' }}>Network Status</th>
                                    <th style={{ padding: '0 20px' }}>Spatial Data</th>
                                    <th style={{ padding: '0 20px' }}>Mission Control</th>

                                </tr>
                            </thead>
                            <tbody>
                                {riders.map(rider => (
                                    <tr key={rider.id} style={{ transition: 'all 0.3s cubic-bezier(0.19, 1, 0.22, 1)' }}>
                                        <td data-label="Identity" style={{ padding: '24px', borderRadius: '24px 0 0 24px' }}>
                                            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                                                <div style={{ width: '50px', height: '50px', borderRadius: '16px', background: '#FFD600', display: 'grid', placeItems: 'center', fontSize: '1.2rem', color: '#0F172A', boxShadow: '0 4px 10px rgba(255, 214, 0, 0.2)' }}>🤝</div>
                                                <div>
                                                    <div style={{ fontWeight: '900', color: '#0F172A', fontSize: '1.1rem' }}>{rider.name}</div>
                                                    <div style={{ fontSize: '0.85rem', color: '#64748B', fontWeight: '800', marginTop: '2px' }}><Phone size={12} style={{ verticalAlign: 'middle', marginRight: '6px' }} /> {rider.phone}</div>
                                                    <div style={{ fontSize: '0.7rem', color: '#94A3B8', fontWeight: '700' }}>KYC:
                                                        <span style={{ color: rider.kyc_status === 'ACTIVE' ? '#166534' : '#E11D48', marginLeft: '4px' }}>{rider.kyc_status}</span>
                                                    </div>
                                                </div>
                                            </div>
                                        </td>
                                        <td data-label="Rating" style={{ padding: '24px' }}>
                                            <div style={{ display: 'flex', alignItems: 'center', gap: '4px', color: '#B45309' }}>
                                                <Star size={16} fill="#FACC15" color="#FACC15" />
                                                <span style={{ fontWeight: '900', fontSize: '1rem' }}>{rider.rating?.toFixed(1) || '5.0'}</span>
                                            </div>
                                        </td>

                                        <td data-label="Status" style={{ padding: '24px' }}>
                                            <div style={{
                                                display: 'inline-flex', alignItems: 'center', gap: '8px',
                                                padding: '8px 16px', borderRadius: '12px',
                                                background: rider.is_online ? '#DCFCE7' : '#F1F5F9',
                                                color: rider.is_online ? '#166534' : '#64748B',
                                                fontWeight: '900', fontSize: '0.75rem', letterSpacing: '0.05em'
                                            }}>
                                                <div className={rider.is_online ? 'pulse-green' : ''} style={{ width: '6px', height: '6px', borderRadius: '50%', background: rider.is_online ? '#1B5E20' : '#64748B' }} />
                                                {rider.is_online ? 'ONLINE' : 'OFFLINE'}
                                            </div>
                                            {rider.active_order_id && (
                                                <div style={{ marginTop: '8px', fontSize: '0.75rem', color: '#FFD600', fontWeight: '900' }}>
                                                    ON MISSION
                                                </div>
                                            )}
                                        </td>
                                        <td data-label="Spatial" style={{ padding: '24px' }}>
                                            <div style={{ color: '#0F172A', fontWeight: '800', fontSize: '0.9rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                                                <MapPin size={16} color={getGpsStatus(rider.last_location_update).color} />
                                                {rider.current_lat ? `${rider.current_lat.toFixed(4)} N, ${rider.current_lng.toFixed(4)} E` : 'Link Pending'}
                                            </div>
                                            {rider.last_location_update && (
                                                <div style={{ fontSize: '0.7rem', color: getGpsStatus(rider.last_location_update).color, marginTop: '4px', fontWeight: 'bold' }}>
                                                    {getGpsStatus(rider.last_location_update).label}: {new Date(rider.last_location_update).toLocaleTimeString()}
                                                    {getGpsStatus(rider.last_location_update).icon && <AlertTriangle size={10} style={{ marginLeft: '4px' }} />}
                                                </div>
                                            )}
                                        </td>
                                        <td data-label="Mission" style={{ padding: '24px', borderRadius: '0 24px 24px 0' }}>
                                            <div style={{ display: 'flex', gap: '12px' }}>
                                                {rider.kyc_status !== 'ACTIVE' ? (
                                                    <button
                                                        onClick={() => handleApproveKYC(rider.id, 'ACTIVE')}
                                                        className="btn-primary"
                                                        style={{ padding: '8px 16px', borderRadius: '12px', background: '#FFD600', fontSize: '0.8rem', border: 'none', fontWeight: '900' }}
                                                    >
                                                        APPROVE KYC
                                                    </button>
                                                ) : (
                                                    <>
                                                        <button
                                                            onClick={() => toggleStatus(rider)}
                                                            style={{ width: '44px', height: '44px', borderRadius: '14px', background: rider.is_online ? '#166534' : '#F1F5F9', color: rider.is_online ? 'white' : '#64748B', border: 'none', cursor: 'pointer', display: 'grid', placeItems: 'center', transition: 'all 0.3s' }}
                                                            title={rider.is_online ? 'Force Offline' : 'Resume'}
                                                        >
                                                            <Power size={18} />
                                                        </button>
                                                        {rider.active_order_id && (
                                                            <button
                                                                onClick={async () => {
                                                                    if (confirm('REASSIGN MISSION? This will release the rider and find a replacement.')) {
                                                                        await supabase.rpc('admin_force_rider_action', { r_id: rider.id, action_type: 'REASSIGN_MISSION' });
                                                                        toast.success("Mission Reassigned");
                                                                    }
                                                                }}
                                                                style={{ width: '44px', height: '44px', borderRadius: '14px', background: '#FFF7ED', color: '#EA580C', border: 'none', cursor: 'pointer', display: 'grid', placeItems: 'center' }}
                                                                title="Reassign Mission"
                                                            >
                                                                <ExternalLink size={18} />
                                                            </button>
                                                        )}
                                                    </>
                                                )}
                                                <button
                                                    onClick={async () => {
                                                        if (confirm('Suspend rider?')) {
                                                            await handleApproveKYC(rider.id, 'SUSPENDED');
                                                        }
                                                    }}
                                                    style={{ width: '44px', height: '44px', borderRadius: '14px', background: '#FFEBEB', color: '#E11D48', border: 'none', cursor: 'pointer', display: 'grid', placeItems: 'center', transition: 'all 0.3s' }}
                                                    title="Suspend Account"
                                                >
                                                    <AlertTriangle size={18} />
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            )}

            {/* ADD MODAL */}
            <AnimatePresence>
                {showAddModal && (
                    <div style={{ position: 'fixed', inset: 0, zIndex: 9999, display: 'grid', placeItems: 'center', padding: '20px' }}>
                        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setShowAddModal(false)} style={{ position: 'absolute', inset: 0, background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(10px)' }} />
                        <motion.div initial={{ opacity: 0, y: 30, scale: 0.95 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 30, scale: 0.95 }} className="rider-modal-card" style={{ position: 'relative', background: 'white', width: '100%', maxWidth: '500px', borderRadius: '40px', padding: '50px', boxShadow: '0 50px 100px -20px rgba(15,23,42,0.25)' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
                                <h2 style={{ fontSize: '1.6rem', fontWeight: '900', color: '#0F172A', letterSpacing: '-0.03em' }}>Register Unit</h2>
                                <button onClick={() => setShowAddModal(false)} style={{ background: '#F4F7FE', border: 'none', padding: '10px', borderRadius: '14px', cursor: 'pointer' }}>✖</button>
                            </div>
                            <form onSubmit={handleAddRider} style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
                                <div>
                                    <label style={{ fontSize: '0.85rem', fontWeight: '900', color: '#667C68', marginBottom: '8px', display: 'block', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Unit Designation</label>
                                    <input type="text" required value={newRider.name} onChange={e => setNewRider({ ...newRider, name: e.target.value })} placeholder="e.g. Rahul Sharma" style={{ width: '100%', padding: '18px', borderRadius: '16px', border: '2px solid #F4F7FE', outline: 'none', fontSize: '1.1rem', fontWeight: '800' }} />
                                </div>
                                <div>
                                    <label style={{ fontSize: '0.85rem', fontWeight: '900', color: '#667C68', marginBottom: '8px', display: 'block', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Network Contact</label>
                                    <input type="text" required value={newRider.phone} onChange={e => setNewRider({ ...newRider, phone: e.target.value })} placeholder="+91 ***** *****" style={{ width: '100%', padding: '18px', borderRadius: '16px', border: '2px solid #F4F7FE', outline: 'none', fontSize: '1.1rem', fontWeight: '800' }} />
                                </div>
                                <div className="form-actions-rider" style={{ display: 'flex', gap: '20px', marginTop: '20px' }}>
                                    <button type="button" onClick={() => setShowAddModal(false)} style={{ flex: 1, padding: '20px', borderRadius: '20px', border: 'none', background: '#F4F7FE', color: '#0F172A', fontWeight: '800', cursor: 'pointer', fontSize: '1.1rem' }}>Abort</button>
                                    <button type="submit" style={{ flex: 1, padding: '20px', borderRadius: '20px', border: 'none', background: '#FFD600', color: '#0F172A', fontWeight: '900', cursor: 'pointer', fontSize: '1.1rem', boxShadow: '0 10px 20px rgba(255, 214, 0, 0.2)' }}>Deploy Unit</button>
                                </div>
                            </form>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>
            <style>{`
                .pulse-green {
                    animation: pulse 2s infinite;
                }
                @keyframes pulse {
                    0% { transform: scale(1); opacity: 1; }
                    50% { transform: scale(1.5); opacity: 0.5; }
                    100% { transform: scale(1); opacity: 1; }
                }
            `}</style>
        </div>
    );
};

export default DeliveryTeam;
