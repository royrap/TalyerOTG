-- ================================================================================================
-- ROADAID REVIEWS SYSTEM SETUP
-- This script sets up the complete reviews/ratings system for RoadAid
-- Run this in Supabase SQL Editor
-- ================================================================================================

-- 1. Create the reviews table
CREATE TABLE IF NOT EXISTS reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    is_verified BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_reviews_request_id ON reviews(request_id);
CREATE INDEX IF NOT EXISTS idx_reviews_customer_id ON reviews(customer_id);
CREATE INDEX IF NOT EXISTS idx_reviews_provider_id ON reviews(provider_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON reviews(created_at);

-- 3. Add unique constraint to prevent duplicate reviews
ALTER TABLE reviews ADD CONSTRAINT unique_customer_request_review 
UNIQUE (request_id, customer_id);

-- 4. Create a function to update provider ratings when reviews are added
CREATE OR REPLACE FUNCTION update_provider_rating()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the provider's rating and review count
    UPDATE user_profiles 
    SET 
        rating = (
            SELECT ROUND(AVG(rating::NUMERIC), 2)
            FROM reviews 
            WHERE provider_id = COALESCE(NEW.provider_id, OLD.provider_id)
        ),
        total_reviews = (
            SELECT COUNT(*)
            FROM reviews 
            WHERE provider_id = COALESCE(NEW.provider_id, OLD.provider_id)
        ),
        updated_at = NOW()
    WHERE id = COALESCE(NEW.provider_id, OLD.provider_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- 5. Create triggers to automatically update ratings
DROP TRIGGER IF EXISTS trigger_update_provider_rating_insert ON reviews;
CREATE TRIGGER trigger_update_provider_rating_insert
    AFTER INSERT ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_provider_rating();

DROP TRIGGER IF EXISTS trigger_update_provider_rating_update ON reviews;
CREATE TRIGGER trigger_update_provider_rating_update
    AFTER UPDATE ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_provider_rating();

DROP TRIGGER IF EXISTS trigger_update_provider_rating_delete ON reviews;
CREATE TRIGGER trigger_update_provider_rating_delete
    AFTER DELETE ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_provider_rating();

-- 6. Ensure user_profiles has rating and total_reviews columns
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS rating DECIMAL(3,2) DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS total_reviews INTEGER DEFAULT 0;

-- 7. Create a view for easy review data access
CREATE OR REPLACE VIEW reviews_with_details AS
SELECT 
    r.*,
    cp.first_name || ' ' || cp.last_name AS customer_name,
    cp.profile_image_url AS customer_image,
    pp.first_name || ' ' || pp.last_name AS provider_name,
    pp.profile_image_url AS provider_image,
    pp.rating AS provider_current_rating,
    pp.total_reviews AS provider_total_reviews,
    sr.title AS service_title,
    sr.description AS service_description
FROM reviews r
JOIN user_profiles cp ON r.customer_id = cp.id
JOIN user_profiles pp ON r.provider_id = pp.id  
JOIN service_requests sr ON r.request_id = sr.id;

-- 8. Set up Row Level Security (RLS)
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read all reviews
CREATE POLICY "Anyone can read reviews" ON reviews
    FOR SELECT USING (true);

-- Policy: Customers can insert reviews for their own requests
CREATE POLICY "Customers can create reviews for their requests" ON reviews
    FOR INSERT WITH CHECK (
        auth.uid() = customer_id AND 
        EXISTS (
            SELECT 1 FROM service_requests 
            WHERE id = request_id AND customer_id = auth.uid()
        )
    );

-- Policy: Customers can update their own reviews
CREATE POLICY "Customers can update their own reviews" ON reviews
    FOR UPDATE USING (auth.uid() = customer_id);

-- Policy: Customers can delete their own reviews  
CREATE POLICY "Customers can delete their own reviews" ON reviews
    FOR DELETE USING (auth.uid() = customer_id);

-- 9. Update existing provider ratings based on any existing data
UPDATE user_profiles 
SET 
    rating = COALESCE((
        SELECT ROUND(AVG(rating::NUMERIC), 2)
        FROM reviews 
        WHERE provider_id = user_profiles.id
    ), 0.0),
    total_reviews = COALESCE((
        SELECT COUNT(*)
        FROM reviews 
        WHERE provider_id = user_profiles.id
    ), 0)
WHERE user_type IN ('mechanic', 'shop_owner');

-- 10. Grant necessary permissions
GRANT ALL ON reviews TO authenticated;
GRANT SELECT ON reviews_with_details TO authenticated;

-- ================================================================================================
-- VERIFICATION QUERIES (Run these to test the setup)
-- ================================================================================================

-- Check if reviews table was created properly
SELECT 
    table_name, 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'reviews' 
ORDER BY ordinal_position;

-- Check if user_profiles has rating columns
SELECT 
    column_name, 
    data_type, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND column_name IN ('rating', 'total_reviews');

-- Check if triggers are created
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table
FROM information_schema.triggers 
WHERE event_object_table = 'reviews';

COMMIT;

-- ================================================================================================
-- SUCCESS MESSAGE
-- ================================================================================================
-- If you see this without errors, the reviews system is ready!
-- The reviews table is created with proper constraints and triggers
-- Provider ratings will be automatically calculated when reviews are submitted
-- ================================================================================================