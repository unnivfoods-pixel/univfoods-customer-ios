import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
    Plus, Search, Edit2, Trash2, Loader2,
    X, Image as ImageIcon, CheckCircle, Smartphone
} from 'lucide-react';
import { supabase } from '../supabase';
import { COLLECTIONS } from '../constants';
import { toast } from 'react-hot-toast';
import ImageUpload from '../components/ImageUpload';
import './Categories-Beautiful.css';

const Categories = () => {
    const [categories, setCategories] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [isEditing, setIsEditing] = useState(false);
    const [selectedCategory, setSelectedCategory] = useState(null);

    const [formData, setFormData] = useState({
        name: '',
        image_url: ''
    });

    useEffect(() => {
        fetchCategories();
        const sub = supabase.channel('categories-sync')
            .on('postgres_changes', { event: '*', schema: 'public', table: COLLECTIONS.CATEGORIES }, fetchCategories)
            .subscribe();
        return () => sub.unsubscribe();
    }, []);

    const fetchCategories = async () => {
        try {
            const { data, error } = await supabase
                .from(COLLECTIONS.CATEGORIES)
                .select('*')
                .order('created_at', { ascending: false });

            if (error) throw error;
            setCategories(data || []);
        } catch (error) {
            console.error('Error fetching categories:', error);
            toast.error('Failed to load categories');
        } finally {
            setLoading(false);
        }
    };

    const handleSave = async (e) => {
        e.preventDefault();
        const toastId = toast.loading(isEditing ? 'Updating category...' : 'Adding category...');

        try {
            if (isEditing) {
                const { error } = await supabase
                    .from(COLLECTIONS.CATEGORIES)
                    .update(formData)
                    .eq('id', selectedCategory.id);
                if (error) throw error;
                toast.success('Category updated', { id: toastId });
            } else {
                const { error } = await supabase
                    .from(COLLECTIONS.CATEGORIES)
                    .insert(formData);
                if (error) throw error;
                toast.success('Category added', { id: toastId });
            }

            setIsModalOpen(false);
            setFormData({ name: '', image_url: '' });
            fetchCategories();
        } catch (error) {
            console.error('Error saving category:', error);
            toast.error('Failed to save category', { id: toastId });
        }
    };

    const handleDelete = async (id) => {
        if (!window.confirm('Are you sure you want to delete this category?')) return;

        try {
            const { error } = await supabase
                .from(COLLECTIONS.CATEGORIES)
                .delete()
                .eq('id', id);

            if (error) throw error;
            toast.success('Category deleted');
            fetchCategories();
        } catch (error) {
            console.error('Error deleting category:', error);
            toast.error('Failed to delete category');
        }
    };

    const openEditModal = (category) => {
        setSelectedCategory(category);
        setFormData({
            name: category.name || '',
            image_url: category.image_url || ''
        });
        setIsEditing(true);
        setIsModalOpen(true);
    };

    const openAddModal = () => {
        setSelectedCategory(null);
        setFormData({ name: '', image_url: '' });
        setIsEditing(false);
        setIsModalOpen(true);
    };

    const filteredCategories = categories.filter(c =>
        c.name?.toLowerCase().includes(searchTerm.toLowerCase())
    );

    return (
        <div className="categories-beautiful-page">
            <header className="categories-header">
                <div>
                    <h1>Categories</h1>
                    <p>Manage food categories and their display order.</p>
                </div>
                <div className="page-actions">
                    <button
                        className="new-category-btn"
                        onClick={openAddModal}
                    >
                        <Plus size={20} /> Deploy Category
                    </button>
                </div>
            </header>

            <div className="categories-search-bar">
                <div className="search-input-wrapper">
                    <Search size={20} />
                    <input
                        type="text"
                        placeholder="Search categories..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                    />
                </div>
                <div className="categories-stats">
                    <span>Total: {categories.length}</span>
                    <span>Active: {categories.length}</span>
                </div>
            </div>

            {loading ? (
                <div className="loading-state">
                    <Loader2 className="animate-spin" size={40} />
                </div>
            ) : (
                <div className="categories-grid">
                    {filteredCategories.map((category, idx) => (
                        <motion.div
                            key={category.id}
                            className="category-card"
                            initial={{ opacity: 0, y: 20 }}
                            animate={{ opacity: 1, y: 0 }}
                            whileHover={{ y: -5 }}
                        >
                            <div className="category-image-wrapper">
                                {category.image_url ? (
                                    <img src={category.image_url} alt={category.name} />
                                ) : (
                                    <div className="category-placeholder">
                                        <ImageIcon size={40} />
                                    </div>
                                )}
                            </div>
                            <div className="category-info">
                                <h3>{category.name}</h3>
                                <p>Operational Cluster: {idx + 1}</p>
                            </div>
                            <div className="category-actions">
                                <button
                                    className="edit-btn"
                                    onClick={() => openEditModal(category)}
                                >
                                    <Edit2 size={16} /> Edit
                                </button>
                                <button
                                    className="delete-icon-btn"
                                    onClick={() => handleDelete(category.id)}
                                >
                                    <Trash2 size={18} />
                                </button>
                            </div>
                        </motion.div>
                    ))}
                    {filteredCategories.length === 0 && (
                        <div className="empty-state-card">
                            <ImageIcon size={60} />
                            <h3>No categories found</h3>
                            <p>Create your first category to get started</p>
                        </div>
                    )}
                </div>
            )}

            <AnimatePresence>
                {isModalOpen && (
                    <div className="modal-overlay">
                        <motion.div
                            className="modal-content"
                            initial={{ opacity: 0, scale: 0.95 }}
                            animate={{ opacity: 1, scale: 1 }}
                            exit={{ opacity: 0, scale: 0.95 }}
                        >
                            <div className="modal-header">
                                <h2>{isEditing ? 'Edit Category' : 'Add New Category'}</h2>
                                <button className="close-btn" onClick={() => setIsModalOpen(false)}>
                                    <X size={24} />
                                </button>
                            </div>

                            <form onSubmit={handleSave}>
                                <div className="form-group">
                                    <label>Category Name</label>
                                    <input
                                        type="text"
                                        required
                                        value={formData.name}
                                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                        placeholder="e.g. Biryani, Curries"
                                    />
                                </div>

                                <div className="form-group">
                                    <label>Category Image</label>
                                    <ImageUpload
                                        value={formData.image_url}
                                        onChange={(url) => setFormData({ ...formData, image_url: url })}
                                        folder="categories"
                                    />
                                </div>

                                <div className="modal-footer">
                                    <button
                                        type="button"
                                        className="cancel-btn"
                                        onClick={() => setIsModalOpen(false)}
                                    >
                                        Cancel
                                    </button>
                                    <button type="submit" className="save-btn">
                                        {isEditing ? 'Save Changes' : 'Create Category'}
                                    </button>
                                </div>
                            </form>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default Categories;
