import React, { useState, useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { supabase } from '../supabase';
import { Bike } from 'lucide-react';

// Custom Marker Icons
const riderIcon = (heading = 0) => new L.DivIcon({
    className: 'custom-rider-icon',
    html: `<div style="transform: rotate(${heading}deg); transition: transform 0.5s;">
             <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#0F172A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
               <path d="M5.5 17.5L2 14l3.5-3.5" />
               <path d="M18.5 17.5L22 14l-3.5-3.5" />
               <circle cx="12" cy="5" r="3" />
               <path d="M12 8v11" />
               <path d="M9 13h6" />
             </svg>
           </div>`,
    iconSize: [32, 32],
    iconAnchor: [16, 16]
});

const vendorIcon = new L.Icon({
    iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41]
});

const customerIcon = new L.Icon({
    iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41]
});

const MissionMap = () => {
    const [missions, setMissions] = useState([]);
    const [riders, setRiders] = useState({});

    useEffect(() => {
        fetchActiveMissions();

        const channel = supabase.channel('live-missions-master-v16')
            .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'orders' }, fetchActiveMissions)
            .on('postgres_changes', { event: '*', schema: 'public', table: 'delivery_live_location' }, (payload) => {
                const updatedRider = payload.new;
                setRiders(prev => ({
                    ...prev,
                    [updatedRider.delivery_id]: {
                        ...prev[updatedRider.delivery_id],
                        current_lat: updatedRider.latitude,
                        current_lng: updatedRider.longitude,
                        heading: updatedRider.heading,
                        last_location_update: updatedRider.updated_at
                    }
                }));
            })
            .subscribe();

        return () => supabase.removeChannel(channel);
    }, []);

    const fetchActiveMissions = async () => {
        const { data: orders } = await supabase.from('orders')
            .select(`
                id, status, 
                delivery_lat, delivery_lng, 
                pickup_lat, pickup_lng,
                rider_id,
                vendors (name)
            `)
            .in('status', ['accepted', 'preparing', 'ready', 'picked_up', 'on_the_way', 'ACCEPTED', 'PREPARING', 'READY', 'PICKED_UP', 'ON_THE_WAY', 'rider_assigned']);

        if (orders) setMissions(orders);

        // Fetch riders details and their LAST LIVE location
        const { data: riderData } = await supabase.from('delivery_riders').select('*');
        const { data: liveData } = await supabase.from('delivery_live_location').select('*');

        if (riderData) {
            const rMap = {};
            riderData.forEach(r => {
                const live = liveData?.find(l => l.delivery_id === r.id);
                rMap[r.id] = {
                    ...r,
                    current_lat: live?.latitude || r.last_lat,
                    current_lng: live?.longitude || r.last_lng,
                    heading: live?.heading || 0
                };
            });
            setRiders(rMap);
        }
    };

    return (
        <div style={{ height: '500px', width: '100%', borderRadius: '24px', overflow: 'hidden', boxShadow: '0 10px 30px rgba(0,0,0,0.1)' }}>
            <MapContainer center={[12.9716, 77.5946]} zoom={13} style={{ height: '100%', width: '100%' }}>
                <TileLayer url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png" />

                {missions.map(m => {
                    const rider = riders[m.rider_id];
                    const rLat = rider?.current_lat || m.current_lat;
                    const rLng = rider?.current_lng || m.current_lng;
                    const rHeading = riders[m.rider_id]?.heading || 0;

                    return (
                        <React.Fragment key={m.id}>
                            {/* Vendor Marker */}
                            {m.pickup_lat && (
                                <Marker position={[m.pickup_lat, m.pickup_lng]} icon={vendorIcon}>
                                    <Popup>Vendor: {m.vendors?.name}<br />Order: {m.id.slice(0, 8)}</Popup>
                                </Marker>
                            )}

                            {/* Customer Marker */}
                            {m.delivery_lat && (
                                <Marker position={[m.delivery_lat, m.delivery_lng]} icon={customerIcon}>
                                    <Popup>Customer Delivery Point<br />Order: {m.id.slice(0, 8)}</Popup>
                                </Marker>
                            )}

                            {/* Rider Marker */}
                            {rLat && (
                                <Marker position={[rLat, rLng]} icon={riderIcon(rHeading)}>
                                    <Popup>Rider: {riders[m.rider_id]?.name || 'On Mission'}<br />Status: {m.status}</Popup>
                                </Marker>
                            )}

                            {/* Tracking Line */}
                            {rLat && m.delivery_lat && (
                                <Polyline
                                    positions={[[rLat, rLng], [m.delivery_lat, m.delivery_lng]]}
                                    pathOptions={{ color: '#0F172A', dashArray: '10, 10', weight: 2, opacity: 0.5 }}
                                />
                            )}
                        </React.Fragment>
                    );
                })}
            </MapContainer>
        </div>
    );
};

export default MissionMap;
