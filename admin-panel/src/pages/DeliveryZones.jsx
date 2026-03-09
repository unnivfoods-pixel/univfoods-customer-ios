import React, { useState, useEffect, useMemo } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polygon, Tooltip, useMapEvents, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { GeoSearchControl, OpenStreetMapProvider } from 'leaflet-geosearch';
import 'leaflet-geosearch/dist/geosearch.css';
import { supabase } from '../supabase';
import { COLLECTIONS } from '../constants';
import { motion, AnimatePresence } from 'framer-motion';
import { Save, Trash2, Edit3, X, Map as MapIcon, Layers, Zap, Clock, DollarSign, Shield, Eye, Users, Search, AlertTriangle, CheckCircle } from 'lucide-react';
import './DeliveryZonesV3.css';

// Fix Icons
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

// Custom Icons
const vendorIcon = new L.Icon({
    iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41],
    popupAnchor: [1, -34]
});

const riderIcon = new L.Icon({
    iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-blue.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41]
});

// --- Components ---

const SearchField = () => { /* Same Search Component */
    const map = useMap();
    useEffect(() => {
        const provider = new OpenStreetMapProvider();
        const searchControl = new GeoSearchControl({
            provider: provider,
            style: 'bar',
            showMarker: true,
            showPopup: false,
            autoClose: true,
            retainZoomLevel: false,
            animateZoom: true,
            keepResult: true,
            searchLabel: 'Search area...',
        });
        map.addControl(searchControl);
        return () => map.removeControl(searchControl);
    }, [map]);
    return null;
};

const MapClickEvents = ({ isDrawing, onMapClick }) => {
    useMapEvents({
        click(e) { if (isDrawing) onMapClick(e.latlng); }
    });
    return null;
};

const MapFlyTo = ({ center }) => {
    const map = useMap();
    useEffect(() => {
        if (center) map.flyTo(center, 14, { duration: 1.5 });
    }, [center, map]);
    return null;
};

// --- MAIN PAGE ---
const DeliveryZones = () => {
    // Data State
    const [zones, setZones] = useState([]);
    const [vendors, setVendors] = useState([]);
    const [riders, setRiders] = useState([]);

    // UI State
    const [selectedZoneId, setSelectedZoneId] = useState(null);
    const [isDrawing, setIsDrawing] = useState(false);
    const [currentPoints, setCurrentPoints] = useState([]);
    const [activeTab, setActiveTab] = useState('basic');
    const [mapLayers, setMapLayers] = useState({ vendors: true, riders: true, orders: false });
    const [showSidebarMobile, setShowSidebarMobile] = useState(false);

    // Editor State (Dual purpose: New or Edit)
    const [editorData, setEditorData] = useState(null);

    // Initial Fetch
    useEffect(() => {
        fetchData();

        // Subscribe to all relevant tables for true real-time map
        const channel = supabase.channel('zones-realtime-master')
            .on('postgres_changes', { event: '*', schema: 'public', table: COLLECTIONS.ZONES }, fetchZones)
            .on('postgres_changes', { event: '*', schema: 'public', table: COLLECTIONS.VENDORS }, fetchVendors)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'delivery_riders' }, fetchRiders)
            .subscribe();

        return () => {
            supabase.removeChannel(channel);
        };
    }, []);

    const fetchData = async () => {
        fetchZones();
        fetchVendors();
        fetchRiders();
    };

    const fetchZones = async () => {
        const { data } = await supabase.from(COLLECTIONS.ZONES).select('*').order('created_at', { ascending: false });
        if (data) setZones(data);
    };

    const fetchVendors = async () => {
        const { data } = await supabase.from(COLLECTIONS.VENDORS).select('*');
        if (data) setVendors(data.map(v => ({ ...v, lat: v.latitude || 17.385, lng: v.longitude || 78.486 })));
    };

    const fetchRiders = async () => {
        // Mock Riders or Fetch
        const { data } = await supabase.from('delivery_riders').select('*');
        if (data) setRiders(data.map(r => ({ ...r, lat: r.current_lat || r.latitude || 17.39, lng: r.current_lng || r.longitude || 78.49 })));
    };

    // --- ACTIONS ---

    const handleSelectZone = (zone) => {
        if (!zone) return;
        setSelectedZoneId(zone.id);
        const coords = Array.isArray(zone.coordinates) ? zone.coordinates : [];
        setEditorData({ ...zone, coordinates: coords });
        setIsDrawing(false);
    };

    const handleStartNew = () => {
        setSelectedZoneId('NEW');
        setIsDrawing(true);
        setCurrentPoints([]);
        setEditorData({
            name: '',
            type: 'allowed',
            is_active: true,
            base_delivery_fee: 40,
            per_km_charge: 5,
            surge_multiplier: 1.0,
            feature_flags: { cod_allowed: true, rain_mode: false, wallet_cashback: 0 },
            open_time: '06:00',
            close_time: '23:59',
            active_days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        });
    };

    const handleMapClick = (latlng) => {
        setCurrentPoints(prev => [...prev, latlng]);
    };

    const handleFinishDrawing = () => {
        if (currentPoints.length < 3) return alert("Need 3+ points");
        setIsDrawing(false);
        // Update editor geometry
        const coords = currentPoints.map(p => ({ lat: p.lat, lng: p.lng }));
        setEditorData(prev => ({ ...prev, coordinates: coords }));
    };

    const handleSave = async () => {
        let finalCoordinates = editorData.coordinates;

        // Auto-finish drawing if user hits save while drawing
        if (isDrawing && currentPoints.length >= 3) {
            finalCoordinates = currentPoints.map(p => ({ lat: p.lat, lng: p.lng }));
        }

        if (!editorData.name) return alert("Name required");
        if (!finalCoordinates || finalCoordinates.length < 3) return alert("Zone geometry missing");

        const payload = {
            ...editorData,
            coordinates: finalCoordinates
        };

        const { id, ...dataToUpsert } = payload;

        if (selectedZoneId === 'NEW') {
            const { error } = await supabase.from(COLLECTIONS.ZONES).insert([dataToUpsert]);
            if (error) alert(error.message);
            else {
                alert("Zone Created Live!");
                setSelectedZoneId(null);
                setEditorData(null);
                setIsDrawing(false);
                setCurrentPoints([]);
                fetchZones();
            }
        } else {
            const { error } = await supabase.from(COLLECTIONS.ZONES).update(dataToUpsert).eq('id', selectedZoneId);
            if (error) alert(error.message);
            else {
                alert("Zone Updated!");
                setIsDrawing(false);
                setCurrentPoints([]);
                fetchZones();
            }
        }
    };

    // --- CALCULATIONS ---
    const previewFee = useMemo(() => {
        if (!editorData) return 0;
        const base = Number(editorData.base_delivery_fee || 0);
        const dist = 5; // 5km sample
        const perKm = Number(editorData.per_km_charge || 0);
        const surge = Number(editorData.surge_multiplier || 1);
        return ((base + (dist * perKm)) * surge).toFixed(2);
    }, [editorData]);

    const activeZoneCenter = useMemo(() => {
        if (!selectedZoneId || selectedZoneId === 'NEW') return null;
        const z = zones.find(z => z.id === selectedZoneId);
        if (z && z.coordinates && z.coordinates[0]) return [z.coordinates[0].lat, z.coordinates[0].lng];
        return null;
    }, [selectedZoneId, zones]);


    return (
        <div className="zones-page">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Delivery Zones</h1>
                    <p className="page-subtitle">Manage your delivery areas and logistics fees.</p>
                </div>
                <div className="page-actions">
                    <button className="btn-primary" onClick={() => setShowSidebarMobile(!showSidebarMobile)} style={{ display: window.innerWidth <= 1024 ? 'flex' : 'none', background: '#0F172A', color: 'white' }}>
                        <Layers size={18} /> Spatial List
                    </button>
                    <button className="btn-primary" onClick={handleStartNew} style={{ background: '#FFD600', color: '#0F172A' }}>
                        <Edit3 size={18} /> Deploy Zone
                    </button>
                </div>
            </header>

            <div className="zones-layout">

                {/* 1. LEFT PANEL: LIST */}
                <div className={`zones-sidebar ${showSidebarMobile ? 'mobile-visible' : ''}`}>
                    <div className="sidebar-header">
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <h4>Active Zones ({zones.length})</h4>
                            <button className="icon-btn-light mobile-only" onClick={() => setShowSidebarMobile(false)} style={{ display: 'none' }}><X size={18} /></button>
                        </div>
                        <input type="text" placeholder="Filter..." className="form-control" style={{ marginTop: '10px' }} />
                    </div>
                    <div className="sidebar-list">
                        {zones.map(zone => (
                            <div
                                key={zone.id}
                                className={`zone-card-item ${selectedZoneId === zone.id ? 'active' : ''}`}
                                onClick={() => handleSelectZone(zone)}
                            >
                                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                    <strong>{zone.name}</strong>
                                    <span className={`status-dot ${zone.is_active ? 'active' : 'disabled'}`}></span>
                                </div>
                                <div className="zone-tags">
                                    <span className="badge badge-secondary" style={{ fontSize: 10 }}>{zone.type.toUpperCase()}</span>
                                    <span className="badge badge-success" style={{ fontSize: 10 }}>₹{zone.base_delivery_fee} Base</span>
                                </div>
                            </div>
                        ))}
                        {zones.length > 0 && (
                            <button className="btn-primary mobile-only" onClick={() => setShowSidebarMobile(false)} style={{ margin: '10px 20px', background: '#FFD600', width: 'calc(100% - 40px)' }}>
                                BACK TO GRID
                            </button>
                        )}
                    </div>
                </div>

                {/* 2. CENTER: MAP */}
                <div className="zones-map-wrapper">
                    <MapContainer center={[17.385, 78.486]} zoom={12} style={{ height: '100%', width: '100%' }}>
                        <TileLayer url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png" />
                        <SearchField />
                        <MapClickEvents isDrawing={isDrawing} onMapClick={handleMapClick} />
                        {activeZoneCenter && <MapFlyTo center={activeZoneCenter} />}

                        {/* Drawing Polygon */}
                        {currentPoints.length >= 3 && (
                            <Polygon positions={currentPoints} pathOptions={{ color: 'black', dashArray: '10, 10' }} />
                        )}
                        {currentPoints.map((p, i) => <Marker key={i} position={p} icon={new L.DivIcon({ className: 'point-marker' })} />)}

                        {/* Saved Zones */}
                        {zones.filter(z => Array.isArray(z.coordinates) && z.coordinates.length >= 3).map(zone => (
                            <Polygon
                                key={zone.id}
                                positions={zone.coordinates}
                                pathOptions={{
                                    color: zone.type === 'blocked' ? 'red' : zone.type === 'surge' ? 'orange' : 'green',
                                    fillOpacity: 0.2,
                                    weight: selectedZoneId === zone.id ? 4 : 2
                                }}
                                eventHandlers={{ click: () => handleSelectZone(zone) }}
                            >
                                <Tooltip permanent direction="center" className="zone-label-tooltip">
                                    {zone.name}
                                </Tooltip>
                            </Polygon>
                        ))}

                        {/* Vendors Layer */}
                        {mapLayers.vendors && vendors.map(v => (
                            <Marker key={v.id} position={[v.lat, v.lng]} icon={vendorIcon}>
                                <Popup>{v.name}</Popup>
                            </Marker>
                        ))}

                        {/* Riders Layer */}
                        {mapLayers.riders && riders.map(r => (
                            <Marker key={r.id} position={[r.lat, r.lng]} icon={riderIcon}>
                                <Popup>{r.name}</Popup>
                            </Marker>
                        ))}

                    </MapContainer>

                    {/* Layer Toggles */}
                    <div className="map-layer-toggles">
                        <div className={`toggle-chip ${mapLayers.vendors ? 'active' : ''}`} onClick={() => setMapLayers(p => ({ ...p, vendors: !p.vendors }))}>
                            <Users size={14} /> Vendors
                        </div>
                        <div className={`toggle-chip ${mapLayers.riders ? 'active' : ''}`} onClick={() => setMapLayers(p => ({ ...p, riders: !p.riders }))}>
                            <Users size={14} /> Riders
                        </div>
                    </div>

                    {/* Drawing Hint */}
                    {isDrawing && (
                        <div style={{ position: 'absolute', bottom: 20, left: '50%', transform: 'translateX(-50%)', background: 'white', padding: '10px 20px', borderRadius: 20, boxShadow: '0 5px 15px rgba(0,0,0,0.2)', zIndex: 2000 }}>
                            <span style={{ fontWeight: 'bold' }}>Click points to draw...</span>
                            <button className="btn btn-sm btn-success" style={{ marginLeft: 10 }} onClick={handleFinishDrawing}>Finish Shape</button>
                        </div>
                    )}
                </div>

                {/* 3. RIGHT: EDITOR (Conditional) */}
                <AnimatePresence>
                    {(selectedZoneId || isDrawing && selectedZoneId === 'NEW') && editorData && (
                        <motion.div
                            className="zone-editor-panel"
                            initial={{ x: '100%' }}
                            animate={{ x: 0 }}
                            exit={{ x: '100%' }}
                            transition={{ type: 'tween' }}
                        >
                            <div className="editor-header">
                                <h3>{selectedZoneId === 'NEW' ? 'New Zone' : 'Edit Zone'}</h3>
                                <div style={{ display: 'flex', gap: 10 }}>
                                    <button className="icon-btn-light" onClick={handleSave}><Save size={18} /></button>
                                    <button className="icon-btn-light" onClick={() => { setSelectedZoneId(null); setEditorData(null); setIsDrawing(false); }}><X size={18} /></button>
                                </div>
                            </div>

                            {/* PREVIEW BOX */}
                            <div style={{ padding: '1rem' }}>
                                <div className="realtime-preview-box">
                                    <div className="preview-row">
                                        <span>Sample Order (5km)</span>
                                        <span>Live Calc</span>
                                    </div>
                                    <div className="preview-row">
                                        <span>Base Fee</span>
                                        <span>₹{editorData.base_delivery_fee}</span>
                                    </div>
                                    <div className="preview-row">
                                        <span>Mileage (5km x {editorData.per_km_charge})</span>
                                        <span>₹{5 * editorData.per_km_charge}</span>
                                    </div>
                                    <div className="preview-row">
                                        <span>Surge ({editorData.surge_multiplier}x)</span>
                                        <span className="preview-total">₹{previewFee}</span>
                                    </div>
                                    <div style={{ marginTop: 10, fontSize: 11, opacity: 0.7, display: 'flex', gap: 10 }}>
                                        {editorData.feature_flags?.cod_allowed ? <span className="badge badge-success">COD ON</span> : <span className="badge badge-secondary">COD OFF</span>}
                                        {editorData.feature_flags?.rain_mode ? <span className="badge badge-warning">RAIN MODE</span> : null}
                                    </div>
                                </div>
                            </div>

                            {/* TABS */}
                            <div className="editor-tabs">
                                <button className={`tab-btn ${activeTab === 'basic' ? 'active' : ''}`} onClick={() => setActiveTab('basic')}>Basic</button>
                                <button className={`tab-btn ${activeTab === 'financials' ? 'active' : ''}`} onClick={() => setActiveTab('financials')}>Finance</button>
                                <button className={`tab-btn ${activeTab === 'ops' ? 'active' : ''}`} onClick={() => setActiveTab('ops')}>Ops</button>
                            </div>

                            <div className="editor-content">
                                {activeTab === 'basic' && (
                                    <div className="form-column">
                                        <div className="form-group">
                                            <label>Zone Name</label>
                                            <input type="text" value={editorData.name} onChange={e => setEditorData({ ...editorData, name: e.target.value })} />
                                        </div>
                                        <div className="form-group">
                                            <label>Status</label>
                                            <select value={editorData.is_active} onChange={e => setEditorData({ ...editorData, is_active: e.target.value === 'true' })}>
                                                <option value="true">Active</option>
                                                <option value="false">Disabled</option>
                                            </select>
                                        </div>
                                        <div className="form-group">
                                            <label>Zone Type</label>
                                            <select value={editorData.type} onChange={e => setEditorData({ ...editorData, type: e.target.value })}>
                                                <option value="allowed">Standard Delivery</option>
                                                <option value="surge">Surge Zone (High Demand)</option>
                                                <option value="blocked">No Service Area</option>
                                            </select>
                                        </div>
                                        <button className="btn btn-outline" style={{ width: '100%', marginTop: 10 }} onClick={() => { setIsDrawing(true); setCurrentPoints(editorData.coordinates || []) }}>
                                            <Edit3 size={14} /> Redraw Boundaries
                                        </button>
                                    </div>
                                )}

                                {activeTab === 'financials' && (
                                    <div className="form-column">
                                        <h4>Pricing Logic</h4>
                                        <div className="form-group">
                                            <label>Base Fee (₹)</label>
                                            <input type="number" value={editorData.base_delivery_fee} onChange={e => setEditorData({ ...editorData, base_delivery_fee: e.target.value })} />
                                        </div>
                                        <div className="form-group">
                                            <label>Per Km Charge (₹)</label>
                                            <input type="number" value={editorData.per_km_charge} onChange={e => setEditorData({ ...editorData, per_km_charge: e.target.value })} />
                                        </div>
                                        <div className="form-group">
                                            <label>Surge Multiplier (1.0 - 5.0)</label>
                                            <input type="number" step="0.1" value={editorData.surge_multiplier} onChange={e => setEditorData({ ...editorData, surge_multiplier: e.target.value })} />
                                        </div>
                                        <hr />
                                        <h4>Payment Methods</h4>
                                        <div className="toggle-row">
                                            <span>Cash on Delivery</span>
                                            <input type="checkbox" checked={editorData.feature_flags?.cod_allowed} onChange={e => setEditorData({ ...editorData, feature_flags: { ...editorData.feature_flags, cod_allowed: e.target.checked } })} />
                                        </div>
                                        <div className="form-group">
                                            <label>Wallet Cashback (%)</label>
                                            <input type="number" value={editorData.feature_flags?.wallet_cashback} onChange={e => setEditorData({ ...editorData, feature_flags: { ...editorData.feature_flags, wallet_cashback: e.target.value } })} />
                                        </div>
                                    </div>
                                )}

                                {activeTab === 'ops' && (
                                    <div className="form-column">
                                        <h4>Operating Hours</h4>
                                        <div className="layout-2-col">
                                            <div className="form-group">
                                                <label>Open</label>
                                                <input type="time" value={editorData.open_time} onChange={e => setEditorData({ ...editorData, open_time: e.target.value })} />
                                            </div>
                                            <div className="form-group">
                                                <label>Close</label>
                                                <input type="time" value={editorData.close_time} onChange={e => setEditorData({ ...editorData, close_time: e.target.value })} />
                                            </div>
                                        </div>
                                        <hr />
                                        <h4>Emergency Override</h4>
                                        <div className="toggle-row">
                                            <span>Rain Mode (No Bikes)</span>
                                            <input type="checkbox" checked={editorData.feature_flags?.rain_mode} onChange={e => setEditorData({ ...editorData, feature_flags: { ...editorData.feature_flags, rain_mode: e.target.checked } })} />
                                        </div>
                                    </div>
                                )}
                            </div>
                        </motion.div>
                    )}
                </AnimatePresence>

            </div>
        </div>
    );
};

export default DeliveryZones;
