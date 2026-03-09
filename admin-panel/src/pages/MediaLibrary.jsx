import React, { useState, useEffect } from 'react';
import { supabase } from '../supabase';
import {
    Upload, Trash2, Copy, Image as ImageIcon,
    Folder, RefreshCw, Grid, List, Search,
    MoreVertical, ExternalLink, Download
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { toast } from 'react-hot-toast';
import './MediaLibrary.css';

const MediaLibrary = () => {
    const [images, setImages] = useState([]);
    const [loading, setLoading] = useState(false);
    const [currentFolder, setCurrentFolder] = useState('uploads');
    const [uploading, setUploading] = useState(false);

    const folders = ['uploads', 'banners', 'vendors', 'menu-items'];

    useEffect(() => {
        fetchImages();
    }, [currentFolder]);

    const fetchImages = async () => {
        setLoading(true);
        try {
            const { data, error } = await supabase.storage
                .from('images')
                .list(currentFolder, {
                    limit: 100,
                    offset: 0,
                    sortBy: { column: 'created_at', order: 'desc' },
                });

            if (error) throw error;
            setImages(data || []);
        } catch (error) {
            console.error('Error loading media:', error);
        } finally {
            setLoading(false);
        }
    };

    const handleFileUpload = async (e) => {
        try {
            const file = e.target.files[0];
            if (!file) return;

            setUploading(true);
            const fileExt = file.name.split('.').pop();
            const fileName = `${currentFolder}/${Date.now()}-${Math.random().toString(36).substring(2)}.${fileExt}`;

            const { error: uploadError } = await supabase.storage
                .from('images')
                .upload(fileName, file);

            if (uploadError) throw uploadError;

            toast.success('Asset uploaded successfully');
            fetchImages();
        } catch (error) {
            console.error(error);
            toast.error('Upload failed: ' + error.message);
        } finally {
            setUploading(false);
        }
    };

    const handleDelete = async (fileName) => {
        if (!window.confirm('Delete this asset permanently?')) return;
        const toastId = toast.loading('Deleting asset...');
        try {
            const { error } = await supabase.storage
                .from('images')
                .remove([`${currentFolder}/${fileName}`]);

            if (error) throw error;
            toast.success('Asset deleted', { id: toastId });
            fetchImages();
        } catch (error) {
            toast.error('Delete failed', { id: toastId });
        }
    };

    const copyUrl = (fileName) => {
        const { data } = supabase.storage.from('images').getPublicUrl(`${currentFolder}/${fileName}`);
        navigator.clipboard.writeText(data.publicUrl);
        toast.success('Link copied to clipboard!');
    };

    return (
        <div className="page-container media-page">
            <header className="page-header">
                <div>
                    <h1 className="page-title">Media Library</h1>
                    <p className="page-subtitle">Centralized asset management for all Curry Point applications.</p>
                </div>
                <div className="page-actions">
                    <button
                        onClick={fetchImages}
                        className="btn-secondary"
                        style={{ width: '50px', height: '50px', borderRadius: '16px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                        title="Refresh"
                    >
                        <RefreshCw size={20} className={loading ? 'animate-spin' : ''} />
                    </button>
                    <label className="btn-deploy-media">
                        {uploading ? <RefreshCw size={18} className="animate-spin" /> : <Upload size={18} />}
                        {uploading ? 'Uploading...' : 'Deploy Asset'}
                        <input type="file" hidden onChange={handleFileUpload} disabled={uploading} accept="image/*" />
                    </label>
                </div>
            </header>

            <div className="folder-nav">
                {folders.map(folder => (
                    <button
                        key={folder}
                        onClick={() => setCurrentFolder(folder)}
                        className={`folder-btn ${currentFolder === folder ? 'active' : ''}`}
                    >
                        <Folder size={18} fill={currentFolder === folder ? "var(--primary)" : "none"} />
                        {folder.charAt(0).toUpperCase() + folder.slice(1).replace('-', ' ')}
                    </button>
                ))}
            </div>

            <div style={{ flex: 1, overflowY: 'auto' }}>
                <AnimatePresence mode="wait">
                    {loading ? (
                        <motion.div
                            key="loading"
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                            style={{ padding: '4rem', textAlign: 'center' }}
                        >
                            <RefreshCw size={32} className="animate-spin" style={{ color: '#cbd5e1', margin: '0 auto' }} />
                            <p style={{ marginTop: '1rem', color: '#64748b' }}>Indexing files...</p>
                        </motion.div>
                    ) : images.filter(f => f.name !== '.emptyFolderPlaceholder').length === 0 ? (
                        <motion.div
                            key="empty"
                            initial={{ opacity: 0, scale: 0.95 }}
                            animate={{ opacity: 1, scale: 1 }}
                            style={{ padding: '6rem', textAlign: 'center', color: '#94a3b8' }}
                        >
                            <div style={{ background: '#f8fafc', width: '80px', height: '80px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 1.5rem' }}>
                                <ImageIcon size={40} style={{ opacity: 0.3 }} />
                            </div>
                            <h3>No Assets Found</h3>
                            <p>Upload your first image to this folder to see it here.</p>
                        </motion.div>
                    ) : (
                        <motion.div
                            key="grid"
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            className="media-grid"
                        >
                            {images.map((file, idx) => {
                                if (file.name === '.emptyFolderPlaceholder') return null;
                                const url = supabase.storage.from('images').getPublicUrl(`${currentFolder}/${file.name}`).data.publicUrl;
                                return (
                                    <motion.div
                                        key={file.id}
                                        className="media-card"
                                        initial={{ opacity: 0, y: 20 }}
                                        animate={{ opacity: 1, y: 0 }}
                                        transition={{ delay: idx * 0.05 }}
                                    >
                                        <div className="media-preview">
                                            <img src={url} alt={file.name} loading="lazy" />
                                            <div className="media-overlay">
                                                <button onClick={() => window.open(url, '_blank')} className="icon-btn-white" title="View Full">
                                                    <ExternalLink size={16} />
                                                </button>
                                            </div>
                                        </div>
                                        <div className="media-info">
                                            <p className="media-name" title={file.name}>{file.name}</p>
                                            <div className="media-actions">
                                                <button onClick={() => copyUrl(file.name)} className="copy-btn">
                                                    <Copy size={14} /> Copy URL
                                                </button>
                                                <button onClick={() => handleDelete(file.name)} className="delete-btn-small">
                                                    <Trash2 size={14} />
                                                </button>
                                            </div>
                                        </div>
                                    </motion.div>
                                );
                            })}
                        </motion.div>
                    )}
                </AnimatePresence>
            </div>

        </div>
    );
};

export default MediaLibrary;

