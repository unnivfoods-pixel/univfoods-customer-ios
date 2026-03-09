-- =========================================================================
-- VENDOR IMAGES UPDATE
-- Run this in Supabase SQL Editor to support Rich Vendor Profiles
-- =========================================================================

-- 1. Add new image columns to vendors table
alter table public.vendors 
add column if not exists date_created timestamp default now(), -- safety
add column if not exists banner_url text,
add column if not exists sub_banner_url text,
add column if not exists gallery_images text[]; -- Array of strings for gallery

-- 2. Comment for clarity
comment on column public.vendors.banner_url is 'Wide banner image for restaurant page';
comment on column public.vendors.sub_banner_url is 'Secondary promotional banner';
comment on column public.vendors.gallery_images is 'Array of image URLs for the gallery carousel';
