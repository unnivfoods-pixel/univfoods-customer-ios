import React from 'react';
import { Search, User, LogOut } from 'lucide-react';
import NotificationCenter from '../NotificationCenter';
import { supabase } from '../../supabase';
import { useNavigate } from 'react-router-dom';
import './DashboardHeader.css';

const DashboardHeader = ({ title }) => {
    const navigate = useNavigate();
    const [isMobile, setIsMobile] = React.useState(window.innerWidth <= 1024);

    React.useEffect(() => {
        const handleResize = () => setIsMobile(window.innerWidth <= 1024);
        window.addEventListener('resize', handleResize);
        return () => window.removeEventListener('resize', handleResize);
    }, []);

    if (isMobile) return null;

    const handleLogout = async () => {
        await supabase.auth.signOut();
        navigate('/login');
    };

    return (
        <header className="dashboard-header">
            <div className="header-left-tools">
                <div className="header-search-container">
                    <Search className="header-search-icon" size={20} />
                    <input
                        type="text"
                        placeholder="Search orders, vendors..."
                        className="header-search-input"
                    />
                </div>
            </div>

            <div className="header-brand">
                <span className="header-brand-text">
                    UNIV <span>FOODS</span>
                </span>
            </div>

            <div className="header-right-tools">
                <NotificationCenter />
                <div className="user-profile-header">
                    <div className="user-meta">
                        <span className="user-name">Admin User</span>
                        <span className="user-role">Super Admin</span>
                    </div>
                    <div className="user-avatar-small">
                        <User size={24} color="#0F172A" />
                    </div>
                    <button onClick={handleLogout} className="logout-icon-btn">
                        <LogOut size={20} />
                    </button>
                </div>
            </div>
        </header>
    );
};

export default DashboardHeader;
