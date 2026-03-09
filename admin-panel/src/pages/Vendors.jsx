import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Plus, Search, MapPin, Store, Star, X, RefreshCw } from 'lucide-react';
import { supabase } from '../supabase';
import { COLLECTIONS } from '../constants';
import { toast } from 'react-hot-toast';
import { useNavigate, useLocation } from 'react-router-dom';
import ImageUpload from '../components/ImageUpload';
import { MapContainer, TileLayer, Marker, useMapEvents, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import './Vendors.css';

// Fix Leaflet Marker
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const MapPicker = ({ position, setPosition }) => {
    const map = useMapEvents({
        click(e) {
            setPosition(e.latlng);
        },
    });

    useEffect(() => {
        if (position) {
            map.flyTo(position, map.getZoom());
        }
    }, [position, map]);

    return position ? (
        <Marker position={position}>
            <Popup>Vendor Location</Popup>
        </Marker>
    ) : null;
};

const Toggle = ({ active, onToggle, label }) => {
    return (
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }} onClick={(e) => { e.stopPropagation(); onToggle(); }}>
            <div style={{
                width: '40px',
                height: '20px',
                backgroundColor: active ? '#10B981' : '#CBD5E1',
                borderRadius: '20px',
                position: 'relative',
                transition: 'all 0.3s ease'
            }}>
                <div style={{
                    width: '14px',
                    height: '14px',
                    backgroundColor: 'white',
                    borderRadius: '50%',
                    position: 'absolute',
                    top: '3px',
                    left: active ? '23px' : '3px',
                    transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                    boxShadow: '0 1px 3px rgba(0,0,0,0.2)'
                }} />
            </div>
            {label && <span style={{ fontSize: '0.75rem', fontWeight: '700', color: active ? '#10B981' : '#64748B', textTransform: 'uppercase' }}>{label}</span>}
        </div>
    );
};

const Vendors = () => {
    const navigate = useNavigate();
    const location = useLocation();
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [vendors, setVendors] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [editingVendor, setEditingVendor] = useState(null);

    // Default center (Srivilliputhur)
    const DEFAULT_CENTER = { lat: 9.5100, lng: 77.6300 };

    const [newVendor, setNewVendor] = useState({
        name: '', address: '', phone: '', manager: '',
        cuisine: 'North Indian', openTime: '09:00', closeTime: '22:00',
        banner_url: '',
        is_pure_veg: false,
        has_offers: false,
        latitude: '',
        longitude: '',
        delivery_radius_km: 15,
        email: ''
    });

    useEffect(() => {
        if (location.state?.registrationData) {
            const reg = location.state.registrationData;
            setNewVendor({
                name: reg.name,
                address: reg.address || reg.message || '',
                phone: reg.phone,
                manager: reg.name,
                cuisine: 'North Indian',
                openTime: '09:00',
                closeTime: '22:00',
                banner_url: '',
                latitude: reg.lat || DEFAULT_CENTER.lat,
                longitude: reg.lng || DEFAULT_CENTER.lng,
                delivery_radius_km: 15,
                is_pure_veg: false,
                has_offers: false,
                email: reg.email || ''
            });
            setIsModalOpen(true);
            setEditingVendor(null);
            fetchVendors();
        }
    }, [location]);

    useEffect(() => {
        console.log("🛰️ VENDORS_MODULE_LOADED_V2.1");
        fetchVendors();
        const sub = supabase.channel('vendors-live')
            .on('postgres_changes', { event: '*', schema: 'public', table: COLLECTIONS.VENDORS }, fetchVendors)
            .subscribe();
        return () => supabase.removeChannel(sub);
    }, []);

    const fetchVendors = async () => {
        try {
            setLoading(true);
            const { data, error } = await supabase.from(COLLECTIONS.VENDORS).select('*').order('created_at', { ascending: false });

            if (error) {
                console.error('Grid Sync Error (Vendors):', error);
                toast.error(`Logistics Grid Fault: ${error.message}`);
                return;
            }

            if (data) {
                setVendors(data);
                console.log(`🛰️ Loaded ${data.length} vendors into local grid.`);
            }
        } catch (err) {
            console.error('Critical Fetch Failure:', err);
            toast.error("Critical Signal Loss: Check Supabase Connection");
        } finally {
            setLoading(false);
        }
    };

    const handleDelete = async (id) => {
        if (!confirm("This will permanently decommission this point. Proceed?")) return;
        await supabase.from(COLLECTIONS.VENDORS).delete().eq('id', id);
        toast.success("Vendor decommissioned.");
    };

    const handleCreateVendor = async (e) => {
        e.preventDefault();
        try {
            const payload = {
                name: newVendor.name,
                shop_name: newVendor.name,
                cuisine_type: newVendor.cuisine,
                address: newVendor.address,
                phone: newVendor.phone,
                email: newVendor.email,
                manager: newVendor.manager,
                open_time: newVendor.openTime,
                close_time: newVendor.closeTime,
                latitude: parseFloat(newVendor.latitude) || 9.51,
                longitude: parseFloat(newVendor.longitude) || 77.63,
                delivery_radius_km: parseFloat(newVendor.delivery_radius_km) || 15,
                is_pure_veg: !!newVendor.is_pure_veg,
                has_offers: !!newVendor.has_offers,
                banner_url: newVendor.banner_url || '',
                image_url: newVendor.banner_url || '',
                status: editingVendor ? undefined : 'ONLINE',
                rating: editingVendor ? (vendors.find(v => v.id === editingVendor)?.rating || 5.0) : 5.0,
                is_approved: true,
                approval_status: 'APPROVED',
                is_active: true,
                is_verified: true,
                commission_rate: 10,
                min_order_value: 0,
                cost_for_two: 250,
                avg_prep_time: 25,
                is_open: true
            };

            if (editingVendor) {
                const { error } = await supabase.from(COLLECTIONS.VENDORS).update(payload).eq('id', editingVendor);
                if (error) {
                    console.error("Update Error:", error);
                    throw error;
                }
                toast.success("Vendor updated successfully!");
            } else {
                const { error } = await supabase.from(COLLECTIONS.VENDORS).insert([payload]);
                if (error) {
                    console.error("Insert Error:", error);
                    throw error;
                }
                toast.success("New point deployed successfully!");
            }
            setIsModalOpen(false);
            setEditingVendor(null);
            setNewVendor({ name: '', address: '', phone: '', manager: '', cuisine: 'North Indian', openTime: '09:00', closeTime: '22:00', banner_url: '', delivery_radius_km: 15 });
            fetchVendors();

            fetchVendors();
        } catch (err) {
            console.error("FATAL_DEPLOY_FAULT:", err);
            alert("DEPLOYMENT ERROR: " + err.message + "\n\nDetails: " + JSON.stringify(err));
            toast.error(err.message);
        }
    };

    const handleEditVendor = (vendor) => {
        setEditingVendor(vendor.id);
        const lat = vendor.latitude || DEFAULT_CENTER.lat;
        const lng = vendor.longitude || DEFAULT_CENTER.lng;

        setNewVendor({
            name: vendor.name,
            address: vendor.address || '',
            phone: vendor.phone || '',
            manager: vendor.manager || '',
            cuisine: vendor.cuisine_type || 'North Indian',
            openTime: vendor.open_time || '09:00',
            closeTime: vendor.close_time || '22:00',
            banner_url: vendor.banner_url || '',
            is_pure_veg: vendor.is_pure_veg || false,
            has_offers: vendor.has_offers || false,
            latitude: lat,
            longitude: lng,
            delivery_radius_km: vendor.delivery_radius_km || 10,
            email: vendor.email || ''
        });
        setIsModalOpen(true);
    };

    const simulateVendor = async () => {
        const testVendor = {
            name: "Cloud Kitchen " + Math.floor(Math.random() * 1000),
            shop_name: "Cloud Kitchen " + Math.floor(Math.random() * 1000), // Critical missing field
            address: "Srivilliputhur Digital Zone",
            phone: "+91 99887766" + Math.floor(Math.random() * 9),
            manager: "Admin Simulation",
            cuisine_type: "Virtual Curry",
            status: "ONLINE",
            latitude: DEFAULT_CENTER.lat + (Math.random() - 0.5) * 0.01,
            longitude: DEFAULT_CENTER.lng + (Math.random() - 0.5) * 0.01,
            rating: 5.0,
            is_approved: true,
            approval_status: 'APPROVED'
        };
        const { error } = await supabase.from(COLLECTIONS.VENDORS).insert([testVendor]);
        if (error) {
            console.error("Simulation Error:", error);
            toast.error("Deployment Interrupted: " + (error.message || "Schema Mismatch"));
        }
        else {
            toast.success("Partner Node Deployed in Real-time!");
            fetchVendors();
        }
    };

    const toggleStatus = async (v) => {
        const isOnline = v.status === 'ONLINE';
        const newStatus = isOnline ? 'OFFLINE' : 'ONLINE';
        const newIsOpen = !isOnline;

        const { error } = await supabase.from(COLLECTIONS.VENDORS)
            .update({
                status: newStatus,
                is_open: newIsOpen
            })
            .eq('id', v.id);

        if (error) toast.error("Relay Fault: " + error.message);
        else {
            toast.success(`Node ${v.name} is now ${newStatus}`);
            fetchVendors(); // 🔄 INSTANT REFRESH
        }
    };

    const geocodeAddress = async () => {
        if (!newVendor.address) return toast.error("Enter address first");
        const loadingToast = toast.loading("Geocoding...");
        try {
            const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(newVendor.address)}`);
            const data = await res.json();
            if (data && data.length > 0) {
                const { lat, lon } = data[0];
                setNewVendor(prev => ({ ...prev, latitude: parseFloat(lat), longitude: parseFloat(lon) }));
                toast.success("Address found on map!");
            } else {
                toast.error("Could not locate address");
            }
        } catch (e) {
            toast.error("Geocoding failed");
        } finally {
            toast.dismiss(loadingToast);
        }
    };

    const filteredVendors = vendors.filter(v => v.name?.toLowerCase().includes(searchTerm.toLowerCase()));

    return (
        <div className="vendors-container" style={{ padding: '32px', background: 'transparent', minHeight: '100vh', paddingBottom: '100px' }}>
            {/* Header Section */}
            <header className="vendors-header">
                <div style={{ background: '#ef4444', color: 'white', padding: '12px 24px', borderRadius: '12px', marginBottom: '20px', fontWeight: '900' }}>
                    ⚠️ LOGISTICS GRID: AUTH SYNC ACTIVE
                </div>
                <div>
                    <h1 className="page-title">Vendor Partners</h1>
                    <p style={{ color: '#64748b', fontSize: '1rem', marginTop: '4px' }}>
                        Manage platform partner restaurants and service nodes.
                    </p>
                </div>
                <div style={{ display: 'flex', gap: '12px' }}>
                    <button onClick={simulateVendor} className="btn-primary" style={{ background: '#0F172A', color: 'white' }}>
                        <RefreshCw size={18} color="#FFD600" style={{ marginRight: '8px' }} /> SIMULATE PARTNER
                    </button>
                    <button
                        onClick={() => {
                            setNewVendor({
                                name: '', address: '', phone: '', manager: '',
                                cuisine: 'North Indian', openTime: '09:00', closeTime: '22:00',
                                banner_url: '',
                                latitude: DEFAULT_CENTER.lat,
                                longitude: DEFAULT_CENTER.lng,
                                delivery_radius_km: 15,
                                is_pure_veg: false, has_offers: false
                            });
                            setEditingVendor(null);
                            setIsModalOpen(true);
                        }}
                        className="btn-primary"
                    >
                        <Plus size={18} /> Add New Vendor
                    </button>
                </div>
            </header>

            {/* Stats Row */}
            <div className="vendors-stats-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '24px', marginBottom: '32px' }}>
                <div className="glass-panel" style={{ padding: '24px', display: 'flex', alignItems: 'center', gap: '16px', border: 'none', boxShadow: '0 4px 20px rgba(0,0,0,0.03)' }}>
                    <div style={{ background: '#FFD600', width: '48px', height: '48px', borderRadius: '12px', display: 'grid', placeItems: 'center', boxShadow: '0 4px 12px rgba(255, 214, 0, 0.3)' }}>
                        <Store size={22} color="#0F172A" />
                    </div>
                    <div>
                        <p style={{ fontSize: '0.75rem', color: '#64748b', fontWeight: '600', textTransform: 'uppercase' }}>Total Vendors</p>
                        <h2 style={{ fontSize: '1.25rem', fontWeight: '800', color: '#0f172a' }}>{vendors.length} Nodes</h2>
                    </div>
                </div>

                <div className="glass-panel" style={{ padding: '24px', display: 'flex', alignItems: 'center', gap: '16px', border: 'none', boxShadow: '0 4px 20px rgba(0,0,0,0.03)' }}>
                    <div style={{ background: '#FFD600', width: '48px', height: '48px', borderRadius: '12px', display: 'grid', placeItems: 'center', boxShadow: '0 4px 12px rgba(255, 214, 0, 0.3)' }}>
                        <Star size={22} color="#0F172A" />
                    </div>
                    <div>
                        <p style={{ fontSize: '0.75rem', color: '#64748B', fontWeight: '800', textTransform: 'uppercase' }}>Avg Rating</p>
                        <h2 style={{ fontSize: '1.25rem', fontWeight: '900', color: '#0F172A' }}>{vendors.length > 0 ? (vendors.reduce((acc, v) => acc + (v.rating || 0), 0) / vendors.length).toFixed(1) : '5.0'} ⭐</h2>
                    </div>
                </div>

                <div className="glass-panel" style={{ padding: '24px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <Search size={18} color="#64748b" />
                    <input
                        type="text"
                        placeholder="Search vendors..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        style={{ background: 'transparent', border: 'none', outline: 'none', fontSize: '0.9rem', fontWeight: '500', width: '100%', color: '#0f172a' }}
                    />
                </div>
            </div>

            {/* Table Section */}
            <div className="glass-panel vendors-table-container" style={{ background: 'white', padding: '40px', border: '1px solid rgba(0,0,0,0.03)' }}>
                {loading ? (
                    <div style={{ textAlign: 'center', padding: '100px 0' }}>
                        <div className="loader" style={{ fontSize: '1.2rem', fontWeight: '800', color: '#64748b' }}>Refreshing Infrastructure...</div>
                    </div>
                ) : (
                    <div style={{ overflowX: 'auto' }}>
                        <table className="responsive-table" style={{ width: '100%', borderCollapse: 'separate', borderSpacing: '0 20px' }}>
                            <thead>
                                <tr style={{ color: '#94a3b8', fontSize: '0.85rem', fontWeight: '800', textAlign: 'left', textTransform: 'uppercase', letterSpacing: '1.5px' }}>
                                    <th style={{ padding: '0 20px' }}>Vendor Info</th>
                                    <th style={{ padding: '0 20px' }}>Manager</th>
                                    <th style={{ padding: '0 20px' }}>Rating</th>
                                    <th style={{ padding: '0 20px' }}>Earnings</th>
                                    <th style={{ padding: '0 20px' }}>Status</th>
                                    <th style={{ padding: '0 20px' }}>Admin Control</th>

                                </tr>
                            </thead>
                            <tbody>
                                {filteredVendors.length === 0 ? (
                                    <tr>
                                        <td colSpan="5" style={{ textAlign: 'center', padding: '100px 0' }}>
                                            <Store size={48} color="#e2e8f0" style={{ marginBottom: '20px' }} />
                                            <h3 style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0f172a', marginBottom: '8px' }}>No Nodes Detected</h3>
                                            <p style={{ color: '#64748b', fontWeight: '600', marginBottom: '24px' }}>The logistics grid is currently empty or your search is too specific.</p>
                                            <button onClick={fetchVendors} className="btn-primary" style={{ display: 'inline-flex', gap: '8px', alignItems: 'center' }}>
                                                <RefreshCw size={18} /> RECONNECT TO GRID
                                            </button>
                                        </td>
                                    </tr>
                                ) : filteredVendors.map(v => (
                                    <tr key={v.id} style={{ borderBottom: '1px solid #f1f5f9' }} className="table-row-hover">
                                        <td data-label="Vendor Info" style={{ padding: '16px' }} onClick={() => handleEditVendor(v)}>
                                            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', cursor: 'pointer' }}>
                                                <div style={{ width: '40px', height: '40px', borderRadius: '10px', background: '#FFD600', display: 'grid', placeItems: 'center', fontSize: '1rem', fontWeight: '900', color: '#0F172A' }}>
                                                    {v.name?.[0] || 'V'}
                                                </div>
                                                <div>
                                                    <div style={{ fontSize: '0.875rem', fontWeight: '700', color: '#0f172a' }}>{v.name}</div>
                                                    <div style={{ fontSize: '0.75rem', color: '#64748b', display: 'flex', alignItems: 'center', gap: '4px' }}>
                                                        <Store size={10} /> {v.email || 'No email linked'}
                                                    </div>
                                                    <div style={{ fontSize: '0.7rem', color: '#94a3b8', display: 'flex', alignItems: 'center', gap: '4px', marginTop: '2px' }}>
                                                        <MapPin size={10} /> {v.address?.slice(0, 30)}...
                                                    </div>
                                                </div>
                                            </div>
                                        </td>
                                        <td data-label="Manager" style={{ padding: '16px' }}>
                                            <div style={{ fontWeight: '700', color: '#0F172A', fontSize: '0.875rem' }}>{v.manager}</div>
                                            <div style={{ fontSize: '0.75rem', color: '#FF9500', fontWeight: '900' }}>{v.cuisine_type}</div>
                                        </td>
                                        <td data-label="Rating" style={{ padding: '16px' }}>
                                            <div style={{ display: 'flex', alignItems: 'center', gap: '4px', background: '#FEF9C3', padding: '4px 8px', borderRadius: '8px', width: 'fit-content' }}>
                                                <Star size={14} color="#A16207" fill="#A16207" />
                                                <span style={{ fontWeight: '900', color: '#A16207', fontSize: '0.85rem' }}>{v.rating?.toFixed(1) || '5.0'}</span>
                                            </div>
                                        </td>

                                        <td data-label="Earnings" style={{ padding: '16px' }}>
                                            <div style={{ fontWeight: '900', color: '#166534', fontSize: '0.9rem' }}>₹{v.pending_payout?.toLocaleString() || '0'}</div>
                                            <div style={{ fontSize: '0.7rem', color: '#64748b' }}>Pending Payout</div>
                                        </td>
                                        <td data-label="Status" style={{ padding: '16px' }}>
                                            <div
                                                style={{
                                                    padding: '6px 12px', borderRadius: '20px',
                                                    background: v.status === 'ONLINE' ? '#ecfdf5' : '#fff1f1',
                                                    color: v.status === 'ONLINE' ? '#10b981' : '#ef4444',
                                                    fontWeight: '800', fontSize: '0.7rem', display: 'inline-block'
                                                }}
                                            >
                                                {v.status?.toUpperCase() || 'OFFLINE'}
                                            </div>
                                        </td>
                                        <td data-label="Control" style={{ padding: '16px' }}>
                                            <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
                                                <Toggle
                                                    active={v.status === 'ONLINE'}
                                                    onToggle={() => toggleStatus(v)}
                                                    label={v.status === 'ONLINE' ? 'ONLINE' : 'OFFLINE'}
                                                />
                                                <button onClick={() => handleDelete(v.id)} style={{ width: '32px', height: '32px', borderRadius: '6px', background: '#fff1f1', border: 'none', display: 'grid', placeItems: 'center', cursor: 'pointer', marginLeft: 'auto' }}><X size={14} color="#ef4444" /></button>
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>

            {/* Modal Overlay */}
            <AnimatePresence>
                {isModalOpen && (
                    <div style={{ position: 'fixed', inset: 0, zIndex: 9999, display: 'grid', placeItems: 'center', padding: '20px' }}>
                        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setIsModalOpen(false)} style={{ position: 'absolute', inset: 0, background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(10px)' }} />
                        <motion.div initial={{ opacity: 0, y: 30, scale: 0.95 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 30, scale: 0.95 }} style={{ position: 'relative', background: 'white', width: '100%', maxWidth: '800px', borderRadius: '40px', padding: '0', boxShadow: '0 50px 100px -20px rgba(15,23,42,0.25)', maxHeight: '90vh', overflowY: 'auto', display: 'flex', flexDirection: 'column' }}>

                            <div style={{ padding: '40px 40px 0 40px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                <h2 style={{ fontSize: '1.6rem', fontWeight: '900', color: '#0f172a', letterSpacing: '-0.03em' }}>{editingVendor ? 'Edit Vendor' : 'Add Vendor'}</h2>
                                <button onClick={() => { setIsModalOpen(false); setEditingVendor(null); }} style={{ background: '#f1f5f9', border: 'none', padding: '10px', borderRadius: '14px', cursor: 'pointer' }}><X size={20} /></button>
                            </div>

                            <div style={{ padding: '40px' }}>
                                <form onSubmit={handleCreateVendor} className="modal-content-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
                                    <div style={{ gridColumn: 'span 2', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: '#f8fafc', padding: '16px', borderRadius: '16px', border: '1px solid #e2e8f0', marginBottom: '10px' }}>
                                        <div>
                                            <label style={{ fontSize: '0.85rem', fontWeight: '800', color: '#0f172a', marginBottom: '4px', display: 'block' }}>Vendor Name</label>
                                            <input type="text" value={newVendor.name} onChange={e => setNewVendor({ ...newVendor, name: e.target.value })} placeholder="e.g. Royal Curry" required style={{ width: '280px', padding: '10px', borderRadius: '8px', border: '1px solid #e2e8f0', outline: 'none', fontSize: '0.95rem' }} />
                                        </div>
                                        {editingVendor && (
                                            <div style={{ textAlign: 'right' }}>
                                                <label style={{ fontSize: '0.75rem', fontWeight: '800', color: '#64748b', marginBottom: '8px', display: 'block', textTransform: 'uppercase' }}>Shop Status</label>
                                                <Toggle
                                                    active={vendors.find(v => v.id === editingVendor)?.status === 'ONLINE'}
                                                    onToggle={() => toggleStatus(vendors.find(v => v.id === editingVendor))}
                                                    label={vendors.find(v => v.id === editingVendor)?.status}
                                                />
                                            </div>
                                        )}
                                    </div>

                                    <div style={{ gridColumn: 'span 2', background: '#fef2f2', padding: '16px', borderRadius: '12px', border: '1px solid #fee2e2', marginBottom: '10px' }}>
                                        <label style={{ fontSize: '0.8rem', fontWeight: '800', color: '#dc2626', marginBottom: '8px', display: 'block', textTransform: 'uppercase' }}>Login Credentials</label>
                                        <div style={{ display: 'flex', gap: '12px' }}>
                                            <div style={{ flex: 1 }}>
                                                <input type="email" value={newVendor.email || ''} readOnly placeholder="No email linked" style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #fca5a5', background: 'white', outline: 'none', fontSize: '0.9rem', color: '#991b1b', fontWeight: '700' }} />
                                            </div>
                                            <div style={{ flex: 1 }}>
                                                <input type="tel" value={newVendor.phone} onChange={e => setNewVendor({ ...newVendor, phone: e.target.value })} placeholder="Phone" style={{ width: '100%', padding: '10px', borderRadius: '8px', border: '1px solid #e2e8f0', outline: 'none', fontSize: '0.9rem' }} />
                                            </div>
                                        </div>
                                    </div>

                                    {/* Address & Geocoding */}
                                    <div style={{ gridColumn: 'span 2' }}>
                                        <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#64748b', marginBottom: '8px', display: 'block' }}>Address</label>
                                        <div style={{ display: 'flex', gap: '8px' }}>
                                            <input type="text" value={newVendor.address} onChange={e => setNewVendor({ ...newVendor, address: e.target.value })} placeholder="Site location" required style={{ flex: 1, padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', outline: 'none', fontSize: '1rem' }} />
                                            <button type="button" onClick={geocodeAddress} style={{ padding: '0 20px', borderRadius: '8px', background: '#0F172A', color: 'white', border: 'none', fontWeight: '700', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px' }}>
                                                <Search size={16} /> Locate
                                            </button>
                                        </div>
                                    </div>

                                    {/* MAP PREVIEW */}
                                    <div style={{ gridColumn: 'span 2', height: '250px', borderRadius: '16px', overflow: 'hidden', border: '1px solid #e2e8f0' }}>
                                        <MapContainer center={[newVendor.latitude || DEFAULT_CENTER.lat, newVendor.longitude || DEFAULT_CENTER.lng]} zoom={13} style={{ height: '100%', width: '100%' }}>
                                            <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
                                            <MapPicker
                                                position={newVendor.latitude ? { lat: newVendor.latitude, lng: newVendor.longitude } : null}
                                                setPosition={(pos) => setNewVendor(prev => ({ ...prev, latitude: pos.lat, longitude: pos.lng }))}
                                            />
                                        </MapContainer>
                                    </div>
                                    <div style={{ gridColumn: 'span 2', textAlign: 'center', fontSize: '0.8rem', color: '#64748b' }}>
                                        Click on the map to fine-tune the location pin.
                                    </div>

                                    <div style={{ gridColumn: 'span 2', display: 'flex', gap: '20px' }}>
                                        <div style={{ flex: 1 }}>
                                            <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#64748b', marginBottom: '8px', display: 'block' }}>Latitude</label>
                                            <input type="number" step="any" value={newVendor.latitude} readOnly style={{ width: '100%', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', background: '#f8fafc', outline: 'none', fontSize: '1rem' }} />
                                        </div>
                                        <div style={{ flex: 1 }}>
                                            <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#64748b', marginBottom: '8px', display: 'block' }}>Longitude</label>
                                            <input type="number" step="any" value={newVendor.longitude} readOnly style={{ width: '100%', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', background: '#f8fafc', outline: 'none', fontSize: '1rem' }} />
                                        </div>
                                    </div>

                                    <div>
                                        <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#64748b', marginBottom: '8px', display: 'block' }}>Cuisine</label>
                                        <select value={newVendor.cuisine} onChange={e => setNewVendor({ ...newVendor, cuisine: e.target.value })} style={{ width: '100%', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', outline: 'none', fontSize: '1rem', background: 'white' }}>
                                            <option>North Indian</option>
                                            <option>South Indian</option>
                                            <option>Pure Vegetarian</option>
                                        </select>
                                    </div>
                                    <div>
                                        <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#64748b', marginBottom: '8px', display: 'block' }}>Delivery Radius (km)</label>
                                        <input type="number" value={newVendor.delivery_radius_km} onChange={e => setNewVendor({ ...newVendor, delivery_radius_km: e.target.value })} placeholder="10" style={{ width: '100%', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', outline: 'none', fontSize: '1rem' }} />
                                    </div>

                                    <div style={{ gridColumn: 'span 2' }}>
                                        <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#64748b', marginBottom: '8px', display: 'block' }}>Working Hours</label>
                                        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                                            <input type="time" value={newVendor.openTime} onChange={e => setNewVendor({ ...newVendor, openTime: e.target.value })} style={{ flex: 1, padding: '10px', borderRadius: '8px', border: '1px solid #e2e8f0' }} />
                                            <span style={{ color: '#94a3b8' }}>to</span>
                                            <input type="time" value={newVendor.closeTime} onChange={e => setNewVendor({ ...newVendor, closeTime: e.target.value })} style={{ flex: 1, padding: '10px', borderRadius: '8px', border: '1px solid #e2e8f0' }} />
                                        </div>
                                    </div>

                                    <div style={{ gridColumn: 'span 2', display: 'flex', gap: '24px', background: '#F8FAFC', padding: '16px', borderRadius: '16px' }}>
                                        <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer', flex: 1 }}>
                                            <input
                                                type="checkbox"
                                                checked={newVendor.is_pure_veg}
                                                onChange={e => setNewVendor({ ...newVendor, is_pure_veg: e.target.checked })}
                                                style={{ width: '20px', height: '20px', accentColor: '#10B981' }}
                                            />
                                            <span style={{ fontSize: '0.9rem', fontWeight: '700', color: '#0F172A' }}>Pure Veg Outlet</span>
                                        </label>
                                        <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer', flex: 1 }}>
                                            <input
                                                type="checkbox"
                                                checked={newVendor.has_offers}
                                                onChange={e => setNewVendor({ ...newVendor, has_offers: e.target.checked })}
                                                style={{ width: '20px', height: '20px', accentColor: '#F59E0B' }}
                                            />
                                            <span style={{ fontSize: '0.9rem', fontWeight: '700', color: '#0F172A' }}>Active Offers</span>
                                        </label>
                                    </div>
                                    <div style={{ gridColumn: 'span 2' }}>
                                        <ImageUpload
                                            label="Restaurant Banner"
                                            value={newVendor.banner_url}
                                            onUpload={(url) => setNewVendor({ ...newVendor, banner_url: url })}
                                            folder="vendors"
                                        />
                                    </div>
                                    <div style={{ gridColumn: 'span 2', display: 'flex', gap: '16px', marginTop: '24px' }}>
                                        <button type="button" onClick={() => setIsModalOpen(false)} style={{ flex: 1, padding: '14px', borderRadius: '14px', border: '2px solid #F1F5F9', color: '#0F172A', fontWeight: '800' }}>Cancel</button>
                                        <button type="submit" style={{ flex: 1, padding: '14px', borderRadius: '14px', border: 'none', background: '#FFD600', color: '#0F172A', fontWeight: '800', boxShadow: '0 8px 16px rgba(255, 214, 0, 0.3)' }}>Deploy Partner</button>
                                    </div>
                                </form>
                            </div>
                        </motion.div>
                    </div>
                )
                }
            </AnimatePresence >

            <style>{`
                .table-row-hover:hover {
                    background: #F4F7FE !important;
                    transform: scale(1.002);
                }
            `}</style>
        </div >
    );
};

export default Vendors;
