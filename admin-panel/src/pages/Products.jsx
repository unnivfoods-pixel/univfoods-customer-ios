import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Plus, Search, Tag, Trash2, CheckCircle, X, ShoppingBag, Utensils, AlertCircle, Store, RefreshCw } from 'lucide-react';
import { supabase } from '../supabase';
import { COLLECTIONS } from '../constants';
import { toast } from 'react-hot-toast';
import ImageUpload from '../components/ImageUpload';
import './Products-Responsive.css';

const Products = () => {
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [products, setProducts] = useState([]);
    const [vendors, setVendors] = useState([]);
    const [loading, setLoading] = useState(true);
    const [viewMode, setViewMode] = useState('grid');
    const [search, setSearch] = useState('');
    const [editingProduct, setEditingProduct] = useState(null);
    const [categories, setCategories] = useState([]);
    const [newProduct, setNewProduct] = useState({
        name: '', description: '', price: '', category: 'Main',
        category_id: '',
        vendor_id: '', image_url: '', is_veg: true, is_available: true
    });


    useEffect(() => {
        const init = async () => {
            const vData = await fetchVendors();
            await fetchProducts(vData); // Pass vendor data to immediate enrichment
        };
        init();
        fetchCategories();
        const sub = supabase.channel('products-channel').on('postgres_changes', { event: '*', schema: 'public', table: COLLECTIONS.PRODUCTS }, () => fetchProducts()).subscribe();
        return () => sub.unsubscribe();
    }, []);

    // Re-enrich products whenever vendors list is updated
    useEffect(() => {
        if (products.length > 0 && vendors.length > 0) {
            const enriched = products.map(p => ({
                ...p,
                vendors: vendors.find(v => v.id === p.vendor_id) || p.vendors || { name: 'Unassigned' }
            }));
            // Only update if names changed to avoid loops
            if (JSON.stringify(enriched) !== JSON.stringify(products)) {
                setProducts(enriched);
            }
        }
    }, [vendors]);

    const fetchCategories = async () => {
        const { data } = await supabase.from('categories').select('id, name').eq('is_active', true).order('priority', { ascending: false });
        if (data) setCategories(data);
    };

    const fetchProducts = async (passedVendors) => {
        try {
            setLoading(true);
            // 🛰️ SIGNAL FIX: Broken Join Recovery
            // The direct join with 'vendors(name)' was failing due to relationship issues.
            // Sourcing raw products and mapping vendors locally.
            const { data, error } = await supabase.from(COLLECTIONS.PRODUCTS).select('*').order('created_at', { ascending: false });

            if (error) {
                console.error('Vault Sync Error (Products):', error);
                toast.error(`Vault Signal Fault: ${error.message}`);
                return;
            }

            if (data) {
                // Enrich items with vendor names from the local vendors state
                const currentVendors = passedVendors || vendors;
                const enrichedData = data.map(item => ({
                    ...item,
                    vendors: currentVendors.find(v => v.id === item.vendor_id) || { name: 'Unassigned' }
                }));
                setProducts(enrichedData);
                console.log(`📦 Sourced ${data.length} signature items from vault.`);
            }
        } catch (err) {

            console.error('Critical Fetch Failure (Products):', err);
            toast.error("Critical Signal Loss: Check Inventory Grid");
        } finally {
            setLoading(false);
        }
    };

    const fetchVendors = async () => {
        const { data } = await supabase.from(COLLECTIONS.VENDORS).select('id, name');
        if (data) {
            setVendors(data);
            return data;
        }
        return [];
    };

    const handleCreateProduct = async (e) => {
        e.preventDefault();
        try {
            if (editingProduct) {
                const { error } = await supabase.from(COLLECTIONS.PRODUCTS).update({
                    ...newProduct,
                    price: parseFloat(newProduct.price)
                }).eq('id', editingProduct);
                if (error) throw error;
                toast.success('Product updated successfully!');
            } else {
                const { error } = await supabase.from(COLLECTIONS.PRODUCTS).insert([{
                    ...newProduct,
                    price: parseFloat(newProduct.price)
                }]);
                if (error) throw error;
                toast.success('Signature Item Added!');
            }
            setIsModalOpen(false);
            setEditingProduct(null);
            setNewProduct({ name: '', description: '', price: '', category: 'Main', category_id: '', vendor_id: '', image_url: '', is_veg: true, is_available: true });

        } catch (error) {
            toast.error(error.message);
        }
    };

    const handleEditProduct = (item) => {
        setEditingProduct(item.id);
        setNewProduct({
            name: item.name,
            description: item.description || '',
            price: item.price,
            category: item.category || 'Main',
            category_id: item.category_id || '',
            vendor_id: item.vendor_id,
            image_url: item.image_url || '',
            is_veg: item.is_veg,
            is_available: item.is_available
        });

        setIsModalOpen(true);
    };

    const toggleAvailability = async (id, currentStatus) => {
        await supabase.from(COLLECTIONS.PRODUCTS).update({ is_available: !currentStatus }).eq('id', id);
        toast.success(`Inventory status updated.`);
    };

    const handleDelete = async (id) => {
        if (!confirm('This will end the lifecycle of this product. Proceed?')) return;
        await supabase.from(COLLECTIONS.PRODUCTS).delete().eq('id', id);
        toast.success('Item Decommissioned.');
    };

    const simulateProduct = async () => {
        if (vendors.length === 0) return toast.error("Need at least one vendor to simulate products.");
        const randomVendor = vendors[Math.floor(Math.random() * vendors.length)];
        const testItem = {
            name: "Hyper-Real Curry " + Math.floor(Math.random() * 100),
            price: Math.floor(Math.random() * 200) + 150,
            category: "Main",
            vendor_id: randomVendor.id,
            is_veg: true,
            is_available: true,
            image_url: 'https://images.unsplash.com/photo-1512152272829-e3139592d56f?auto=format&fit=crop&w=800&q=80'
        };
        const { error } = await supabase.from(COLLECTIONS.PRODUCTS).insert(testItem);
        if (error) toast.error("Simulation Failed: " + error.message);
        else toast.success(`Simulated ${testItem.name} at ${randomVendor.name}!`);
    };

    const filtered = products.filter(p =>
        p.name?.toLowerCase().includes(search.toLowerCase()) ||
        p.vendors?.name?.toLowerCase().includes(search.toLowerCase())
    );

    return (
        <div className="products-container" style={{ padding: '32px', background: 'transparent', minHeight: '100vh' }}>
            {/* Header */}
            <header className="products-header">
                <div>
                    <h1 className="page-title">Menu Management</h1>
                    <p className="page-subtitle">Manage platform offerings and product inventory.</p>
                </div>
                <div className="page-actions">
                    <button onClick={simulateProduct} className="btn-primary" style={{ background: '#0F172A', color: 'white' }}>
                        <RefreshCw size={18} color="#FFD600" style={{ marginRight: '8px' }} /> SIMULATE ITEM
                    </button>
                    <div className="glass-panel btn-view-mode" style={{ padding: '4px', borderRadius: '12px', display: 'flex', background: 'white' }}>
                        <button onClick={() => setViewMode('list')} style={{ padding: '8px 20px', borderRadius: '10px', background: viewMode === 'list' ? '#FFD600' : 'transparent', color: viewMode === 'list' ? '#0F172A' : '#64748B', fontWeight: '800', transition: 'all 0.2s' }}>List</button>
                        <button onClick={() => setViewMode('grid')} style={{ padding: '8px 20px', borderRadius: '10px', background: viewMode === 'grid' ? '#FFD600' : 'transparent', color: viewMode === 'grid' ? '#0F172A' : '#64748B', fontWeight: '800', transition: 'all 0.2s' }}>Grid</button>
                    </div>
                    <button
                        onClick={() => setIsModalOpen(true)}
                        className="btn-primary"
                    >
                        <Plus size={18} /> Add Product
                    </button>
                </div>
            </header>

            <div className="glass-panel" style={{ padding: '12px 20px', marginBottom: '32px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                <Search size={20} color="#64748b" />
                <input
                    placeholder="Search products..."
                    value={search} onChange={e => setSearch(e.target.value)}
                    style={{ background: 'transparent', border: 'none', outline: 'none', fontSize: '1rem', fontWeight: '500', color: '#0f172a', flex: 1 }}
                />
            </div>

            {loading ? (
                <div style={{ textAlign: 'center', padding: '100px 0' }}>
                    <div className="pulse-green" style={{ width: '40px', height: '40px', background: '#FFD600', borderRadius: '50%', margin: '0 auto 20px' }}></div>
                    <div style={{ fontSize: '1.2rem', fontWeight: '800', color: '#64748b' }}>Sourcing ingredients...</div>
                </div>
            ) : filtered.length === 0 ? (
                <div className="glass-panel" style={{ padding: '80px', textAlign: 'center' }}>
                    <ShoppingBag size={48} color="#e2e8f0" style={{ marginBottom: '20px' }} />
                    <h3 style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0f172a', marginBottom: '8px' }}>No items found in the vault</h3>
                    <p style={{ color: '#64748b', fontWeight: '600', marginBottom: '24px' }}>Your product catalog is currently empty or your search is too specific.</p>
                    <button onClick={fetchProducts} className="btn-primary" style={{ display: 'inline-flex', gap: '8px', alignItems: 'center' }}>
                        <RefreshCw size={18} /> MANUAL PULSE
                    </button>
                </div>
            ) : (
                <div className={viewMode === 'grid' ? 'products-grid-responsive' : 'products-table-container'}>
                    {viewMode === 'grid' ? (
                        filtered.map(item => (
                            <div key={item.id} className="glass-panel" style={{ padding: 0, overflow: 'hidden' }}>
                                <div style={{ height: '200px', position: 'relative' }}>
                                    <img src={item.image_url || item.image || 'https://images.unsplash.com/photo-1512152272829-e3139592d56f?auto=format&fit=crop&w=800&q=80'} alt={item.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                                    <div style={{ position: 'absolute', top: '12px', left: '12px', background: item.is_veg ? '#10b981' : '#ef4444', color: 'white', padding: '4px 10px', borderRadius: '6px', fontSize: '0.7rem', fontWeight: '700' }}>
                                        {item.is_veg ? 'VEG' : 'NON-VEG'}
                                    </div>
                                </div>
                                <div className="product-card-body" style={{ padding: '20px' }}>
                                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '8px' }}>
                                        <h3 style={{ margin: 0, fontSize: '1.125rem', fontWeight: '800', color: '#0F172A' }}>{item.name}</h3>
                                        <span className="product-price-badge" style={{ fontSize: '1.25rem', fontWeight: '900', color: '#0F172A', background: '#FFD600', padding: '2px 8px', borderRadius: '6px' }}>₹{item.price}</span>
                                    </div>
                                    <p style={{ color: '#64748b', fontSize: '0.875rem', fontWeight: '500', margin: 0 }}>{item.vendors?.name || 'Unassigned Station'}</p>
                                    <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '20px', alignItems: 'center' }}>
                                        <button
                                            onClick={() => toggleAvailability(item.id, item.is_available)}
                                            style={{ padding: '6px 12px', borderRadius: '6px', background: item.is_available ? '#ecfdf5' : '#fff1f2', color: item.is_available ? '#059669' : '#e11d48', border: 'none', fontWeight: '700', fontSize: '0.75rem' }}
                                        >
                                            {item.is_available ? 'AVAILABLE' : 'OUT of STOCK'}
                                        </button>
                                        <div style={{ display: 'flex', gap: '8px' }}>
                                            <button onClick={() => handleEditProduct(item)} style={{ color: '#64748b' }}><Tag size={18} /></button>
                                            <button onClick={() => handleDelete(item.id)} style={{ color: '#ef4444' }}><Trash2 size={18} /></button>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        ))
                    ) : (
                        <div className="glass-panel" style={{ padding: 0, overflow: 'hidden', background: 'white' }}>
                            <table className="responsive-table" style={{ width: '100%', borderCollapse: 'separate', borderSpacing: '0' }}>
                                <thead style={{ background: '#f8fafc' }}>
                                    <tr style={{ color: '#94a3b8', fontSize: '0.8rem', fontWeight: '900', textTransform: 'uppercase', letterSpacing: '1px', textAlign: 'left' }}>
                                        <th style={{ padding: '24px' }}>Product</th>
                                        <th style={{ padding: '24px' }}>Vendor</th>
                                        <th style={{ padding: '24px' }}>Category</th>
                                        <th style={{ padding: '24px' }}>Price</th>
                                        <th style={{ padding: '24px' }}>Status</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {filtered.map(item => (
                                        <tr key={item.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                                            <td data-label="Product" style={{ padding: '24px' }}>
                                                <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                                                    <div style={{ width: '60px', height: '60px', borderRadius: '16px', backgroundImage: `url(${item.image_url || item.image})`, backgroundSize: 'cover', backgroundPosition: 'center', backgroundRepeat: 'no-repeat' }} />
                                                    <div>
                                                        <div style={{ fontWeight: '1000', color: '#0f172a', fontSize: '1.1rem' }}>{item.name}</div>
                                                        <div style={{ fontSize: '0.75rem', fontWeight: '800', color: item.is_veg ? '#10b981' : '#ef4444', marginTop: '4px' }}>{item.is_veg ? '● VEG' : '● NON-VEG'}</div>
                                                    </div>
                                                </div>
                                            </td>
                                            <td data-label="Vendor" style={{ padding: '24px' }}>
                                                <span style={{ fontWeight: '700', color: '#64748b' }}>{item.vendors?.name || 'N/A'}</span>
                                            </td>
                                            <td data-label="Category" style={{ padding: '24px' }}>
                                                <span style={{ background: '#f1f5f9', padding: '6px 12px', borderRadius: '8px', fontSize: '0.8rem', fontWeight: '800', color: '#0f172a' }}>{item.category}</span>
                                            </td>
                                            <td data-label="Price" style={{ padding: '24px' }}>
                                                <span style={{ fontWeight: '900', color: '#0F172A', fontSize: '1.25rem' }}>₹{item.price}</span>
                                            </td>
                                            <td data-label="Status" style={{ padding: '24px' }}>
                                                <div style={{ display: 'flex', gap: '12px' }}>
                                                    <button onClick={() => toggleAvailability(item.id, item.is_available)} style={{ padding: '10px', borderRadius: '12px', background: item.is_available ? '#ecfdf5' : '#fff1f2', color: item.is_available ? '#059669' : '#e11d48', border: 'none', cursor: 'pointer' }}>
                                                        {item.is_available ? <CheckCircle size={18} /> : <AlertCircle size={18} />}
                                                    </button>
                                                    <button onClick={() => handleEditProduct(item)} style={{ padding: '10px', borderRadius: '12px', background: '#F1F5F9', border: 'none', color: '#64748B', cursor: 'pointer' }}><Tag size={18} /></button>
                                                    <button onClick={() => handleDelete(item.id)} style={{ padding: '10px', borderRadius: '12px', background: 'transparent', border: '1px solid #fee2e2', color: '#ef4444', cursor: 'pointer' }}><Trash2 size={18} /></button>
                                                </div>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    )}
                </div>
            )}

            {/* Modal */}
            <AnimatePresence>
                {isModalOpen && (
                    <div style={{ position: 'fixed', inset: 0, zIndex: 9999, display: 'grid', placeItems: 'center', padding: '20px' }}>
                        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={() => setIsModalOpen(false)} style={{ position: 'absolute', inset: 0, background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(10px)' }} />
                        <motion.div initial={{ opacity: 0, y: 30, scale: 0.95 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 30, scale: 0.95 }} style={{ position: 'relative', background: 'white', width: '100%', maxWidth: '600px', borderRadius: '40px', padding: '50px', boxShadow: '0 50px 100px -20px rgba(15,23,42,0.25)', maxHeight: '90vh', overflowY: 'auto' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px' }}>
                                <h2 style={{ fontSize: '1.6rem', fontWeight: '900', color: '#0f172a', letterSpacing: '-0.03em' }}>{editingProduct ? 'Edit Product' : 'Add Product'}</h2>
                                <button onClick={() => { setIsModalOpen(false); setEditingProduct(null); }} style={{ background: '#f1f5f9', border: 'none', padding: '10px', borderRadius: '14px', cursor: 'pointer' }}><X size={20} /></button>
                            </div>

                            <form onSubmit={handleCreateProduct} className="modal-content-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
                                <div style={{ gridColumn: 'span 2' }}>
                                    <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#64748b', marginBottom: '8px', display: 'block' }}>Product Name</label>
                                    <input required value={newProduct.name} onChange={e => setNewProduct({ ...newProduct, name: e.target.value })} placeholder="Biryani, Curry..." style={{ width: '100%', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', outline: 'none', fontSize: '1rem' }} />
                                </div>
                                <div>
                                    <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#64748b', marginBottom: '8px', display: 'block' }}>Price (₹)</label>
                                    <input type="number" required value={newProduct.price} onChange={e => setNewProduct({ ...newProduct, price: e.target.value })} style={{ width: '100%', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', outline: 'none', fontSize: '1rem' }} />
                                </div>
                                <div>
                                    <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#64748b', marginBottom: '8px', display: 'block' }}>Category</label>
                                    <select
                                        value={newProduct.category_id}
                                        onChange={e => {
                                            const cat = categories.find(c => c.id === e.target.value);
                                            setNewProduct({ ...newProduct, category_id: e.target.value, category: cat ? cat.name : 'Main' });
                                        }}
                                        style={{ width: '100%', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', outline: 'none', fontSize: '1rem', background: 'white' }}
                                    >
                                        <option value="">Select Category</option>
                                        {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                                    </select>
                                </div>

                                <div style={{ gridColumn: 'span 2' }}>
                                    <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#64748b', marginBottom: '8px', display: 'block' }}>Vendor</label>
                                    <select required value={newProduct.vendor_id} onChange={e => setNewProduct({ ...newProduct, vendor_id: e.target.value })} style={{ width: '100%', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0', outline: 'none', fontSize: '1rem', background: 'white' }}>
                                        <option value="">Select Vendor</option>
                                        {vendors.map(v => <option key={v.id} value={v.id}>{v.name}</option>)}
                                    </select>
                                </div>
                                <div style={{ gridColumn: 'span 2' }}>
                                    <ImageUpload
                                        label="Product Visual"
                                        value={newProduct.image_url}
                                        onUpload={(url) => setNewProduct({ ...newProduct, image_url: url })}
                                        folder="products"
                                    />
                                </div>
                                <div style={{ gridColumn: 'span 2' }}>
                                    <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                                        <input type="checkbox" checked={newProduct.is_veg} onChange={e => setNewProduct({ ...newProduct, is_veg: e.target.checked })} />
                                        <span style={{ fontSize: '0.875rem', fontWeight: '500' }}>Vegetarian</span>
                                    </label>
                                </div>
                                <div style={{ gridColumn: 'span 2', display: 'flex', gap: '16px', marginTop: '24px' }}>
                                    <button type="button" onClick={() => setIsModalOpen(false)} style={{ flex: 1, padding: '14px', borderRadius: '14px', border: '2px solid #F1F5F9', color: '#0F172A', fontWeight: '800' }}>Cancel</button>
                                    <button type="submit" style={{ flex: 1, padding: '14px', borderRadius: '14px', border: 'none', background: '#FFD600', color: '#0F172A', fontWeight: '800', boxShadow: '0 8px 16px rgba(255, 214, 0, 0.3)' }}>Deploy Product</button>
                                </div>
                            </form>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default Products;
