import React, { useState } from 'react';
import { Upload, X, Image as ImageIcon, Loader } from 'lucide-react';
import { supabase } from '../supabase';
import { toast } from 'react-hot-toast';

const ImageUpload = ({ value, onUpload, onChange, label = "Upload Image", folder = "uploads" }) => {
    const [uploading, setUploading] = useState(false);

    const handleFileChange = async (event) => {
        try {
            setUploading(true);
            const file = event.target.files[0];
            if (!file) return;

            // Generate unique filename
            const fileExt = file.name.split('.').pop();
            const fileName = `${folder}/${Date.now()}-${Math.random().toString(36).substring(2)}.${fileExt}`;

            // Upload to Supabase
            const { error: uploadError } = await supabase.storage
                .from('images')
                .upload(fileName, file);

            if (uploadError) {
                throw uploadError;
            }

            // Get Public URL
            const { data } = supabase.storage
                .from('images')
                .getPublicUrl(fileName);

            const url = data.publicUrl;
            if (onUpload) onUpload(url);
            if (onChange) onChange(url);

            toast.success('Image uploaded successfully');

        } catch (error) {
            console.error('Upload Error:', error);
            toast.error('Error uploading image');
        } finally {
            setUploading(false);
        }
    };

    const handleRemove = () => {
        if (onUpload) onUpload('');
        if (onChange) onChange('');
    };

    return (
        <div className="form-group">
            <label style={{ fontWeight: 600, fontSize: '0.9rem', marginBottom: '0.5rem', display: 'block' }}>
                {label}
            </label>

            {value ? (
                <div style={{ position: 'relative', width: '100%', borderRadius: '8px', overflow: 'hidden', border: '1px solid #ddd' }}>
                    <img
                        src={value}
                        alt="Preview"
                        style={{ width: '100%', height: '200px', objectFit: 'cover', display: 'block' }}
                    />
                    <button
                        type="button"
                        onClick={handleRemove}
                        style={{
                            position: 'absolute',
                            top: '8px',
                            right: '8px',
                            background: 'white',
                            border: 'none',
                            borderRadius: '50%',
                            padding: '6px',
                            cursor: 'pointer',
                            boxShadow: '0 2px 4px rgba(0,0,0,0.2)'
                        }}
                    >
                        <X size={16} color="red" />
                    </button>
                    <div style={{
                        position: 'absolute',
                        bottom: 0,
                        left: 0,
                        right: 0,
                        background: 'rgba(0,0,0,0.5)',
                        color: 'white',
                        padding: '4px 8px',
                        fontSize: '0.75rem',
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis'
                    }}>
                        {value.split('/').pop()}
                    </div>
                </div>
            ) : (
                <label style={{
                    border: '2px dashed #ccc',
                    borderRadius: '8px',
                    padding: '2rem',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: uploading ? 'not-allowed' : 'pointer',
                    background: '#f9f9f9',
                    transition: 'all 0.2s'
                }}>
                    <input
                        type="file"
                        accept="image/*"
                        onChange={handleFileChange}
                        disabled={uploading}
                        style={{ display: 'none' }}
                    />
                    {uploading ? (
                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', color: '#666' }}>
                            <Loader className="spin" size={24} style={{ marginBottom: '0.5rem' }} />
                            <span>Uploading...</span>
                        </div>
                    ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', color: '#666' }}>
                            <Upload size={24} style={{ marginBottom: '0.5rem', color: '#888' }} />
                            <span style={{ fontWeight: '500' }}>Click to Upload</span>
                            <span style={{ fontSize: '0.8rem', color: '#999' }}>SVG, PNG, JPG or GIF</span>
                        </div>
                    )}
                </label>
            )}
            <style>{`
                .spin { animation: spin 1s linear infinite; }
                @keyframes spin { 100% { transform: rotate(360deg); } }
            `}</style>
        </div>
    );
};

export default ImageUpload;
