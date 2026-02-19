# 🚀 System Update Implementation Roadmap
**TalyerOTG - Comprehensive Feature Implementation Plan**

Generated: February 19, 2026

---

## 📋 **FEATURES TO IMPLEMENT**

1. ⭐ Rating Mechanic & Shop
2. 📉 Every decline reduce queue priority (Algo)
3. 🎯 Queueing (Location + Queue Priority + Specialization)
4. 💬 Payment Communication (Owner - Customer)
5. 📋 Assessment for the Mechanic
6. ⏱️ Estimated Time of Repair
7. 💵 Labor cost not in Mechanic side
8. 💰 Must accept cash payment
9. 🚫 Number of time can cancel request
10. 💭 Comment and Review
11. 🧪 Test Case must be Comprehensive

---

## 🎯 **IMPLEMENTATION STRATEGY**

### **PHASE 1: CORE INFRASTRUCTURE (Week 1-2)** 🔴 CRITICAL

#### **1.1 Database Schema Extensions**

**New Tables to Create:**

```sql
-- Queue Priority Tracking
CREATE TABLE mechanic_queue_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mechanic_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  base_score DECIMAL(5,2) DEFAULT 100.00,
  decline_penalty DECIMAL(5,2) DEFAULT 0.00,
  completion_bonus DECIMAL(5,2) DEFAULT 0.00,
  rating_bonus DECIMAL(5,2) DEFAULT 0.00,
  total_score DECIMAL(5,2) GENERATED ALWAYS AS (base_score - decline_penalty + completion_bonus + rating_bonus) STORED,
  declines_today INTEGER DEFAULT 0,
  declines_this_week INTEGER DEFAULT 0,
  declines_this_month INTEGER DEFAULT 0,
  last_decline_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Customer Cancellation Tracking
CREATE TABLE customer_cancellation_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  cancellations_today INTEGER DEFAULT 0,
  cancellations_this_week INTEGER DEFAULT 0,
  cancellations_this_month INTEGER DEFAULT 0,
  total_cancellations INTEGER DEFAULT 0,
  last_cancellation_at TIMESTAMPTZ,
  is_restricted BOOLEAN DEFAULT FALSE,
  restriction_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(customer_id)
);

-- Estimated Time of Repair
CREATE TABLE repair_time_estimates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
  mechanic_id UUID REFERENCES user_profiles(id),
  estimated_hours DECIMAL(5,2),
  estimated_minutes INTEGER,
  estimated_start_time TIMESTAMPTZ,
  estimated_completion_time TIMESTAMPTZ,
  actual_start_time TIMESTAMPTZ,
  actual_completion_time TIMESTAMPTZ,
  is_accurate BOOLEAN,
  variance_minutes INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Mechanic Assessment/Skills
CREATE TABLE mechanic_assessments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mechanic_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
  assessment_type VARCHAR(100), -- 'skills_test', 'customer_feedback', 'admin_review'
  category_id UUID REFERENCES service_categories(id),
  skill_level VARCHAR(50), -- 'beginner', 'intermediate', 'expert', 'master'
  assessment_score DECIMAL(5,2),
  assessed_by UUID REFERENCES user_profiles(id),
  assessment_notes TEXT,
  certificate_url TEXT,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Reviews and Comments
CREATE TABLE service_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES user_profiles(id),
  mechanic_id UUID REFERENCES user_profiles(id),
  shop_id UUID REFERENCES shops(id),
  
  -- Ratings (1-5 scale)
  overall_rating DECIMAL(2,1) CHECK (overall_rating >= 1 AND overall_rating <= 5),
  quality_rating DECIMAL(2,1) CHECK (quality_rating >= 1 AND quality_rating <= 5),
  professionalism_rating DECIMAL(2,1) CHECK (professionalism_rating >= 1 AND professionalism_rating <= 5),
  timeliness_rating DECIMAL(2,1) CHECK (timeliness_rating >= 1 AND timeliness_rating <= 5),
  communication_rating DECIMAL(2,1) CHECK (communication_rating >= 1 AND communication_rating <= 5),
  
  -- Review content
  review_title VARCHAR(200),
  review_text TEXT,
  pros TEXT,
  cons TEXT,
  
  -- Media
  review_images JSONB DEFAULT '[]',
  
  -- Metadata
  is_verified_service BOOLEAN DEFAULT FALSE,
  helpful_count INTEGER DEFAULT 0,
  reported_count INTEGER DEFAULT 0,
  is_hidden BOOLEAN DEFAULT FALSE,
  admin_notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Labor Cost Breakdown
CREATE TABLE service_cost_breakdown (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
  
  -- Parts
  parts_cost DECIMAL(10,2) DEFAULT 0.00,
  parts_list JSONB DEFAULT '[]', -- [{name, quantity, unit_price, total}]
  
  -- Labor (goes to shop, not mechanic directly)
  labor_cost DECIMAL(10,2) DEFAULT 0.00,
  labor_hours DECIMAL(5,2),
  hourly_rate DECIMAL(10,2),
  
  -- Service fees
  service_fee DECIMAL(10,2) DEFAULT 0.00, -- Platform fee
  travel_fee DECIMAL(10,2) DEFAULT 0.00,
  emergency_fee DECIMAL(10,2) DEFAULT 0.00,
  
  -- Distribution
  shop_earnings DECIMAL(10,2),
  mechanic_earnings DECIMAL(10,2), -- Fixed salary/commission from shop
  platform_earnings DECIMAL(10,2),
  
  -- Totals
  subtotal DECIMAL(10,2),
  tax_amount DECIMAL(10,2) DEFAULT 0.00,
  total_amount DECIMAL(10,2),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Payment Communication Log
CREATE TABLE payment_communications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID REFERENCES service_requests(id),
  payment_id UUID REFERENCES payments(id),
  
  sender_id UUID REFERENCES user_profiles(id),
  sender_type VARCHAR(50), -- 'customer', 'shop_owner', 'mechanic', 'admin'
  receiver_id UUID REFERENCES user_profiles(id),
  receiver_type VARCHAR(50),
  
  message_type VARCHAR(50), -- 'payment_request', 'payment_confirmation', 'dispute', 'clarification'
  message TEXT,
  attachments JSONB DEFAULT '[]',
  
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Request Queue (for matching algorithm)
CREATE TABLE service_request_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE,
  
  -- Queue metadata
  queue_position INTEGER,
  priority_score DECIMAL(8,2),
  
  -- Matching criteria
  required_skills JSONB DEFAULT '[]',
  preferred_location GEOGRAPHY(POINT),
  max_distance_km DECIMAL(6,2),
  urgency_level VARCHAR(50), -- 'low', 'normal', 'high', 'emergency'
  
  -- Broadcast tracking
  broadcast_count INTEGER DEFAULT 0,
  mechanics_notified JSONB DEFAULT '[]',
  mechanics_declined JSONB DEFAULT '[]',
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  matched_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Add Indexes:**

```sql
-- Performance indexes
CREATE INDEX idx_queue_scores_mechanic ON mechanic_queue_scores(mechanic_id);
CREATE INDEX idx_queue_scores_total ON mechanic_queue_scores(total_score DESC);
CREATE INDEX idx_cancellation_customer ON customer_cancellation_limits(customer_id);
CREATE INDEX idx_reviews_mechanic ON service_reviews(mechanic_id);
CREATE INDEX idx_reviews_shop ON service_reviews(shop_id);
CREATE INDEX idx_reviews_rating ON service_reviews(overall_rating DESC);
CREATE INDEX idx_cost_breakdown_request ON service_cost_breakdown(request_id);
CREATE INDEX idx_payment_comm_request ON payment_communications(request_id);
CREATE INDEX idx_request_queue_active ON service_request_queue(is_active, priority_score DESC);
```

---

#### **1.2 Queue Priority Algorithm Implementation**

**Algorithm Logic:**

```typescript
// lib/algorithms/mechanicQueuePriority.ts

interface MechanicQueueScore {
  mechanicId: string;
  baseScore: number;        // Starting: 100
  declinePenalty: number;   // -5 per decline (resets weekly)
  completionBonus: number;  // +2 per completed job
  ratingBonus: number;      // +10 if rating > 4.5, +5 if > 4.0
  totalScore: number;
}

interface QueueFactors {
  location: {
    latitude: number;
    longitude: number;
    maxDistanceKm: number;
  };
  specialization: string[];
  urgencyLevel: 'low' | 'normal' | 'high' | 'emergency';
  customerPreference?: {
    minRating?: number;
    preferredShop?: string;
  };
}

export async function calculateMechanicPriority(
  mechanicId: string, 
  requestFactors: QueueFactors
): Promise<number> {
  
  // 1. Get mechanic queue score
  const queueScore = await getMechanicQueueScore(mechanicId);
  
  // 2. Calculate distance factor (closer = higher score)
  const distance = await calculateDistance(
    mechanicId, 
    requestFactors.location
  );
  const distanceFactor = Math.max(0, 100 - (distance * 5)); // -5 per km
  
  // 3. Calculate specialization match
  const specializationMatch = await checkSpecializationMatch(
    mechanicId,
    requestFactors.specialization
  );
  const specializationFactor = specializationMatch ? 50 : 0;
  
  // 4. Calculate availability factor
  const isAvailable = await checkMechanicAvailability(mechanicId);
  const availabilityFactor = isAvailable ? 30 : -100;
  
  // 5. Rating factor
  const rating = await getMechanicRating(mechanicId);
  const ratingFactor = (rating / 5) * 20; // 0-20 points
  
  // Final Priority Score
  const priorityScore = 
    queueScore.totalScore +
    distanceFactor +
    specializationFactor +
    availabilityFactor +
    ratingFactor;
    
  return priorityScore;
}

export async function getRankedMechanics(
  request: ServiceRequest,
  filters: QueueFactors
): Promise<MechanicWithScore[]> {
  
  // Get all available mechanics
  const mechanics = await getAvailableMechanics(filters);
  
  // Calculate priority for each
  const rankedMechanics = await Promise.all(
    mechanics.map(async (mechanic) => ({
      ...mechanic,
      priorityScore: await calculateMechanicPriority(
        mechanic.id, 
        filters
      )
    }))
  );
  
  // Sort by priority (highest first)
  return rankedMechanics.sort((a, b) => 
    b.priorityScore - a.priorityScore
  );
}
```

**Decline Penalty System:**

```sql
-- Function to handle mechanic decline
CREATE OR REPLACE FUNCTION handle_mechanic_decline(
  p_mechanic_id UUID,
  p_request_id UUID
) RETURNS VOID AS $$
DECLARE
  v_declines_today INTEGER;
BEGIN
  -- Update queue score
  INSERT INTO mechanic_queue_scores (mechanic_id, declines_today, last_decline_at)
  VALUES (p_mechanic_id, 1, NOW())
  ON CONFLICT (mechanic_id) DO UPDATE SET
    declines_today = mechanic_queue_scores.declines_today + 1,
    declines_this_week = mechanic_queue_scores.declines_this_week + 1,
    declines_this_month = mechanic_queue_scores.declines_this_month + 1,
    decline_penalty = CASE
      WHEN mechanic_queue_scores.declines_today >= 5 THEN 50.00  -- Heavy penalty
      WHEN mechanic_queue_scores.declines_today >= 3 THEN 25.00  -- Moderate penalty
      ELSE mechanic_queue_scores.decline_penalty + 5.00          -- Regular penalty
    END,
    last_decline_at = NOW(),
    updated_at = NOW();
    
  -- Log the decline
  INSERT INTO activity_logs (
    user_id, action_type, description, additional_data
  ) VALUES (
    p_mechanic_id,
    'request_declined',
    'Declined service request',
    jsonb_build_object('request_id', p_request_id)
  );
  
  -- Check if should suspend from queue temporarily
  SELECT declines_today INTO v_declines_today
  FROM mechanic_queue_scores
  WHERE mechanic_id = p_mechanic_id;
  
  IF v_declines_today >= 5 THEN
    -- Suspend from receiving requests for 1 hour
    UPDATE mechanics
    SET is_available = FALSE,
        availability_notes = 'Temporarily suspended due to multiple declines'
    WHERE user_id = p_mechanic_id;
  END IF;
END;
$$ LANGUAGE plpgsql;
```

---

### **PHASE 2: RATING & REVIEW SYSTEM (Week 2-3)** 🟡 HIGH

#### **2.1 Customer Rating Flow**

**After Service Completion:**

```dart
// lib/customer/rate_service_screen.dart

class RateServiceScreen extends StatefulWidget {
  final String requestId;
  final String mechanicId;
  final String? shopId;

  @override
  _RateServiceScreenState createState() => _RateServiceScreenState();
}

class _RateServiceScreenState extends State<RateServiceScreen> {
  double overallRating = 5.0;
  double qualityRating = 5.0;
  double professionalismRating = 5.0;
  double timelinessRating = 5.0;
  double communicationRating = 5.0;
  
  final TextEditingController reviewTitleController = TextEditingController();
  final TextEditingController reviewTextController = TextEditingController();
  final TextEditingController prosController = TextEditingController();
  final TextEditingController consController = TextEditingController();
  
  List<String> selectedImages = [];

  Future<void> submitReview() async {
    final review = {
      'request_id': widget.requestId,
      'mechanic_id': widget.mechanicId,
      'shop_id': widget.shopId,
      'overall_rating': overallRating,
      'quality_rating': qualityRating,
      'professionalism_rating': professionalismRating,
      'timeliness_rating': timelinessRating,
      'communication_rating': communicationRating,
      'review_title': reviewTitleController.text,
      'review_text': reviewTextController.text,
      'pros': prosController.text,
      'cons': consController.text,
      'review_images': selectedImages,
      'is_verified_service': true,
    };

    final response = await supabase
      .from('service_reviews')
      .insert(review);

    if (response.error == null) {
      // Update mechanic/shop average rating
      await updateAverageRating(widget.mechanicId, widget.shopId);
      
      // Navigate to success screen
      Navigator.pushReplacement(/*...*/);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rate Your Service'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Overall Rating
            _buildRatingSection(
              'Overall Experience',
              overallRating,
              (rating) => setState(() => overallRating = rating),
            ),
            
            // Detailed Ratings
            _buildRatingSection('Quality of Work', qualityRating, /*...*/),
            _buildRatingSection('Professionalism', professionalismRating, /*...*/),
            _buildRatingSection('Timeliness', timelinessRating, /*...*/),
            _buildRatingSection('Communication', communicationRating, /*...*/),
            
            // Review Text
            TextField(
              controller: reviewTitleController,
              decoration: InputDecoration(
                labelText: 'Review Title',
                hintText: 'Sum up your experience',
              ),
            ),
            
            TextField(
              controller: reviewTextController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Your Review',
                hintText: 'Share details of your experience...',
              ),
            ),
            
            // Pros and Cons
            TextField(
              controller: prosController,
              decoration: InputDecoration(
                labelText: 'What went well?',
              ),
            ),
            
            TextField(
              controller: consController,
              decoration: InputDecoration(
                labelText: 'What could be improved?',
              ),
            ),
            
            // Photo upload
            _buildPhotoUpload(),
            
            // Submit Button
            ElevatedButton(
              onPressed: submitReview,
              child: Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Auto-calculate Average Ratings:**

```sql
-- Function to update mechanic/shop average rating
CREATE OR REPLACE FUNCTION update_average_ratings()
RETURNS TRIGGER AS $$
BEGIN
  -- Update mechanic rating
  IF NEW.mechanic_id IS NOT NULL THEN
    UPDATE user_profiles
    SET rating = (
      SELECT AVG(overall_rating)
      FROM service_reviews
      WHERE mechanic_id = NEW.mechanic_id
        AND is_hidden = FALSE
    )
    WHERE id = NEW.mechanic_id;
  END IF;
  
  -- Update shop rating
  IF NEW.shop_id IS NOT NULL THEN
    UPDATE shops
    SET average_rating = (
      SELECT AVG(overall_rating)
      FROM service_reviews
      WHERE shop_id = NEW.shop_id
        AND is_hidden = FALSE
    ),
    total_reviews = (
      SELECT COUNT(*)
      FROM service_reviews
      WHERE shop_id = NEW.shop_id
        AND is_hidden = FALSE
    )
    WHERE id = NEW.shop_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_ratings
AFTER INSERT OR UPDATE ON service_reviews
FOR EACH ROW
EXECUTE FUNCTION update_average_ratings();
```

---

### **PHASE 3: CANCELLATION LIMITS & PENALTIES (Week 3-4)** 🟢 MEDIUM

#### **3.1 Cancellation Policy**

**Rules:**
- ✅ **Free cancellations:** 2 per week
- ⚠️ **Warning after:** 3 cancellations in a week
- 🚫 **Temporary ban:** 5 cancellations in a week (24-hour restriction)
- 🔴 **Account review:** 10 cancellations in a month

```sql
-- Function to handle customer cancellation
CREATE OR REPLACE FUNCTION handle_customer_cancellation(
  p_customer_id UUID,
  p_request_id UUID,
  p_reason TEXT
) RETURNS JSONB AS $$
DECLARE
  v_cancellations_this_week INTEGER;
  v_can_cancel BOOLEAN := TRUE;
  v_penalty_message TEXT := '';
  v_restriction_hours INTEGER := 0;
BEGIN
  -- Get current cancellation count
  SELECT 
    cancellations_this_week,
    is_restricted
  INTO 
    v_cancellations_this_week,
    v_can_cancel
  FROM customer_cancellation_limits
  WHERE customer_id = p_customer_id;
  
  -- Check if restricted
  IF NOT v_can_cancel THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'You are temporarily restricted from cancelling requests',
      'can_cancel', false
    );
  END IF;
  
  -- Update cancellation count
  INSERT INTO customer_cancellation_limits (
    customer_id,
    cancellations_today,
    cancellations_this_week,
    cancellations_this_month,
    total_cancellations,
    last_cancellation_at
  ) VALUES (
    p_customer_id, 1, 1, 1, 1, NOW()
  )
  ON CONFLICT (customer_id) DO UPDATE SET
    cancellations_today = customer_cancellation_limits.cancellations_today + 1,
    cancellations_this_week = customer_cancellation_limits.cancellations_this_week + 1,
    cancellations_this_month = customer_cancellation_limits.cancellations_this_month + 1,
    total_cancellations = customer_cancellation_limits.total_cancellations + 1,
    last_cancellation_at = NOW();
  
  -- Get updated count
  SELECT cancellations_this_week INTO v_cancellations_this_week
  FROM customer_cancellation_limits
  WHERE customer_id = p_customer_id;
  
  -- Apply penalties based on count
  IF v_cancellations_this_week >= 5 THEN
    -- Restrict for 24 hours
    UPDATE customer_cancellation_limits
    SET 
      is_restricted = TRUE,
      restriction_until = NOW() + INTERVAL '24 hours'
    WHERE customer_id = p_customer_id;
    
    v_penalty_message := 'Account temporarily restricted for 24 hours due to multiple cancellations';
    v_restriction_hours := 24;
    
  ELSIF v_cancellations_this_week >= 3 THEN
    v_penalty_message := 'Warning: You have cancelled 3+ times this week. Further cancellations may result in restrictions.';
  END IF;
  
  -- Cancel the request
  UPDATE service_requests
  SET 
    status = 'cancelled',
    cancellation_reason = p_reason,
    cancelled_at = NOW(),
    cancelled_by = p_customer_id
  WHERE id = p_request_id;
  
  -- Log the cancellation
  INSERT INTO activity_logs (
    user_id, action_type, description, additional_data
  ) VALUES (
    p_customer_id,
    'request_cancelled',
    'Customer cancelled service request',
    jsonb_build_object(
      'request_id', p_request_id,
      'reason', p_reason,
      'cancellations_this_week', v_cancellations_this_week
    )
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Request cancelled successfully',
    'warning', v_penalty_message,
    'cancellations_this_week', v_cancellations_this_week,
    'restriction_hours', v_restriction_hours
  );
END;
$$ LANGUAGE plpgsql;
```

---

### **PHASE 4: ESTIMATED TIME & LABOR COST (Week 4-5)** 🟢 MEDIUM

#### **4.1 Time Estimation System**

```dart
// lib/mechanic/estimate_time_dialog.dart

class EstimateTimeDialog extends StatefulWidget {
  final String requestId;

  @override
  _EstimateTimeDialogState createState() => _EstimateTimeDialogState();
}

class _EstimateTimeDialogState extends State<EstimateTimeDialog> {
  int estimatedHours = 1;
  int estimatedMinutes = 0;
  DateTime? estimatedStartTime;
  DateTime? estimatedCompletionTime;

  void calculateCompletionTime() {
    if (estimatedStartTime != null) {
      setState(() {
        estimatedCompletionTime = estimatedStartTime!.add(
          Duration(hours: estimatedHours, minutes: estimatedMinutes)
        );
      });
    }
  }

  Future<void> submitEstimate() async {
    await supabase.from('repair_time_estimates').insert({
      'request_id': widget.requestId,
      'mechanic_id': userId,
      'estimated_hours': estimatedHours,
      'estimated_minutes': estimatedMinutes,
      'estimated_start_time': estimatedStartTime?.toIso8601String(),
      'estimated_completion_time': estimatedCompletionTime?.toIso8601String(),
    });

    // Update service request
    await supabase
      .from('service_requests')
      .update({
        'estimated_completion_time': estimatedCompletionTime?.toIso8601String(),
      })
      .eq('id', widget.requestId);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Estimate Repair Time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Hours',
                  ),
                  onChanged: (value) {
                    estimatedHours = int.tryParse(value) ?? 0;
                    calculateCompletionTime();
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Minutes',
                  ),
                  onChanged: (value) {
                    estimatedMinutes = int.tryParse(value) ?? 0;
                    calculateCompletionTime();
                  },
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          ListTile(
            title: Text('Start Time'),
            subtitle: Text(estimatedStartTime?.toString() ?? 'Not set'),
            onTap: () async {
              final time = await showDatePicker(/*...*/);
              setState(() => estimatedStartTime = time);
              calculateCompletionTime();
            },
          ),
          
          if (estimatedCompletionTime != null)
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text('Estimated Completion'),
                    Text(
                      estimatedCompletionTime!.toString(),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: submitEstimate,
          child: Text('Submit Estimate'),
        ),
      ],
    );
  }
}
```

#### **4.2 Labor Cost Separation**

**Key Concept:** Labor cost goes to the **shop owner**, not directly to the mechanic. Mechanic receives salary/commission from shop.

```sql
-- Function to calculate and split costs
CREATE OR REPLACE FUNCTION calculate_service_costs(
  p_request_id UUID,
  p_parts_cost DECIMAL,
  p_labor_hours DECIMAL,
  p_hourly_rate DECIMAL
) RETURNS VOID AS $$
DECLARE
  v_labor_cost DECIMAL;
  v_service_fee DECIMAL;
  v_total DECIMAL;
  v_shop_earnings DECIMAL;
  v_platform_earnings DECIMAL;
BEGIN
  -- Calculate labor cost
  v_labor_cost := p_labor_hours * p_hourly_rate;
  
  -- Platform takes 10% service fee
  v_service_fee := (p_parts_cost + v_labor_cost) * 0.10;
  
  -- Total
  v_total := p_parts_cost + v_labor_cost + v_service_fee;
  
  -- Shop gets parts cost + labor cost
  v_shop_earnings := p_parts_cost + v_labor_cost;
  
  -- Platform gets service fee
  v_platform_earnings := v_service_fee;
  
  -- Insert breakdown
  INSERT INTO service_cost_breakdown (
    request_id,
    parts_cost,
    labor_cost,
    labor_hours,
    hourly_rate,
    service_fee,
    shop_earnings,
    platform_earnings,
    subtotal,
    total_amount
  ) VALUES (
    p_request_id,
    p_parts_cost,
    v_labor_cost,
    p_labor_hours,
    p_hourly_rate,
    v_service_fee,
    v_shop_earnings,
    v_platform_earnings,
    p_parts_cost + v_labor_cost,
    v_total
  );
  
  -- Update service request final price
  UPDATE service_requests
  SET final_price = v_total
  WHERE id = p_request_id;
END;
$$ LANGUAGE plpgsql;
```

---

### **PHASE 5: COMMUNICATION & ASSESSMENT (Week 5-6)** 🟡 MEDIUM

#### **5.1 Payment Communication System**

```dart
// lib/shared/payment_chat_screen.dart

class PaymentChatScreen extends StatefulWidget {
  final String requestId;
  final String customerId;
  final String shopOwnerId;

  @override
  _PaymentChatScreenState createState() => _PaymentChatScreenState();
}

class _PaymentChatScreenState extends State<PaymentChatScreen> {
  List<PaymentMessage> messages = [];
  final TextEditingController messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadMessages();
    subscribeToMessages();
  }

  void loadMessages() async {
    final response = await supabase
      .from('payment_communications')
      .select('*')
      .eq('request_id', widget.requestId)
      .order('created_at', ascending: true);

    setState(() {
      messages = response.map((m) => PaymentMessage.fromJson(m)).toList();
    });
  }

  void subscribeToMessages() {
    supabase
      .from('payment_communications')
      .stream(primaryKey: ['id'])
      .eq('request_id', widget.requestId)
      .listen((data) {
        loadMessages(); // Refresh messages
      });
  }

  void sendMessage(String messageType, String text) async {
    await supabase.from('payment_communications').insert({
      'request_id': widget.requestId,
      'sender_id': currentUserId,
      'sender_type': currentUserType,
      'receiver_id': widget.shopOwnerId,
      'receiver_type': 'shop_owner',
      'message_type': messageType,
      'message': text,
    });

    messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Payment Discussion')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message.senderId == currentUserId;
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.all(8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.senderType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(message.message),
                        SizedBox(height: 4),
                        Text(
                          message.createdAt.toString(),
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    if (messageController.text.isNotEmpty) {
                      sendMessage('clarification', messageController.text);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### **5.2 Mechanic Assessment System**

```sql
-- Admin creates assessment for mechanic
CREATE OR REPLACE FUNCTION create_mechanic_assessment(
  p_mechanic_id UUID,
  p_assessment_type VARCHAR,
  p_category_id UUID,
  p_skill_level VARCHAR,
  p_score DECIMAL,
  p_notes TEXT,
  p_assessed_by UUID
) RETURNS UUID AS $$
DECLARE
  v_assessment_id UUID;
BEGIN
  INSERT INTO mechanic_assessments (
    mechanic_id,
    assessment_type,
    category_id,
    skill_level,
    assessment_score,
    assessment_notes,
    assessed_by
  ) VALUES (
    p_mechanic_id,
    p_assessment_type,
    p_category_id,
    p_skill_level,
    p_score,
    p_notes,
    p_assessed_by
  ) RETURNING id INTO v_assessment_id;
  
  -- Update mechanic's specializations based on assessment
  UPDATE mechanics
  SET 
    specializations = array_append(
      COALESCE(specializations, ARRAY[]::VARCHAR[]),
      (SELECT name FROM service_categories WHERE id = p_category_id)
    )
  WHERE user_id = p_mechanic_id
    AND NOT EXISTS (
      SELECT 1 FROM unnest(COALESCE(specializations, ARRAY[]::VARCHAR[])) 
      WHERE unnest = (SELECT name FROM service_categories WHERE id = p_category_id)
    );
  
  RETURN v_assessment_id;
END;
$$ LANGUAGE plpgsql;
```

---

### **PHASE 6: COMPREHENSIVE TESTING (Week 6-7)** 🔴 CRITICAL

#### **6.1 Test Cases Structure**

```typescript
// tests/queue-system.test.ts

describe('Queue Priority Algorithm', () => {
  
  test('Mechanic with higher rating gets higher priority', async () => {
    const mechanic1 = { id: '1', rating: 4.8 };
    const mechanic2 = { id: '2', rating: 4.2 };
    
    const priority1 = await calculateMechanicPriority(mechanic1.id, testRequest);
    const priority2 = await calculateMechanicPriority(mechanic2.id, testRequest);
    
    expect(priority1).toBeGreaterThan(priority2);
  });
  
  test('Decline penalty reduces queue score', async () => {
    const mechanicId = '123';
    
    // Initial score
    const initialScore = await getMechanicQueueScore(mechanicId);
    
    // Simulate decline
    await handleMechanicDecline(mechanicId, 'request-1');
    
    // Check updated score
    const newScore = await getMechanicQueueScore(mechanicId);
    
    expect(newScore.totalScore).toBeLessThan(initialScore.totalScore);
    expect(newScore.declinePenalty).toBeGreaterThan(initialScore.declinePenalty);
  });
  
  test('5 declines in a day suspends mechanic', async () => {
    const mechanicId = '123';
    
    // Decline 5 times
    for (let i = 0; i < 5; i++) {
      await handleMechanicDecline(mechanicId, `request-${i}`);
    }
    
    // Check if suspended
    const mechanic = await getMechanic(mechanicId);
    expect(mechanic.is_available).toBe(false);
  });
  
  test('Closer mechanic gets higher priority', async () => {
    const nearMechanic = { id: '1', distance: 2 }; // 2km away
    const farMechanic = { id: '2', distance: 10 }; // 10km away
    
    const priority1 = await calculateMechanicPriority(nearMechanic.id, testRequest);
    const priority2 = await calculateMechanicPriority(farMechanic.id, testRequest);
    
    expect(priority1).toBeGreaterThan(priority2);
  });
});

describe('Cancellation Limits', () => {
  
  test('Customer can cancel freely first 2 times', async () => {
    const customerId = '123';
    
    // First cancellation
    const result1 = await handleCustomerCancellation(customerId, 'req1', 'Changed mind');
    expect(result1.success).toBe(true);
    expect(result1.warning).toBe('');
    
    // Second cancellation
    const result2 = await handleCustomerCancellation(customerId, 'req2', 'Changed mind');
    expect(result2.success).toBe(true);
  });
  
  test('3rd cancellation shows warning', async () => {
    const customerId = '123';
    
    // Cancel 3 times
    for (let i = 0; i < 3; i++) {
      await handleCustomerCancellation(customerId, `req${i}`, 'Changed mind');
    }
    
    const limits = await getCustomerCancellationLimits(customerId);
    expect(limits.cancellations_this_week).toBe(3);
  });
  
  test('5 cancellations in a week restricts account', async () => {
    const customerId = '123';
    
    // Cancel 5 times
    for (let i = 0; i < 5; i++) {
      await handleCustomerCancellation(customerId, `req${i}`, 'Changed mind');
    }
    
    // Try 6th cancellation
    const result = await handleCustomerCancellation(customerId, 'req6', 'Changed mind');
    expect(result.success).toBe(false);
    expect(result.can_cancel).toBe(false);
  });
});

describe('Rating System', () => {
  
  test('Review updates mechanic average rating', async () => {
    const mechanicId = '123';
    
    // Initial rating
    const initialRating = await getMechanicRating(mechanicId);
    
    // Submit new review
    await submitReview({
      mechanic_id: mechanicId,
      overall_rating: 5.0,
      quality_rating: 5.0,
      // ...
    });
    
    // Check updated rating
    const newRating = await getMechanicRating(mechanicId);
    expect(newRating).not.toBe(initialRating);
  });
  
  test('Hidden reviews do not affect average', async () => {
    const mechanicId = '123';
    
    const initialRating = await getMechanicRating(mechanicId);
    
    // Submit hidden review
    await submitReview({
      mechanic_id: mechanicId,
      overall_rating: 1.0,
      is_hidden: true,
    });
    
    // Rating should not change
    const newRating = await getMechanicRating(mechanicId);
    expect(newRating).toBe(initialRating);
  });
});

describe('Time Estimation', () => {
  
  test('Mechanic can provide repair time estimate', async () => {
    const requestId = 'req-123';
    const mechanicId = 'mech-456';
    
    const estimate = await createRepairTimeEstimate({
      request_id: requestId,
      mechanic_id: mechanicId,
      estimated_hours: 2,
      estimated_minutes: 30,
    });
    
    expect(estimate.id).toBeDefined();
    expect(estimate.estimated_hours).toBe(2);
  });
  
  test('Completion time is calculated correctly', async () => {
    const startTime = new Date('2026-02-19T10:00:00');
    const hours = 2;
    const minutes = 30;
    
    const completionTime = calculateCompletionTime(startTime, hours, minutes);
    
    expect(completionTime.getHours()).toBe(12);
    expect(completionTime.getMinutes()).toBe(30);
  });
  
  test('Actual time vs estimated variance is tracked', async () => {
    const estimateId = 'est-123';
    
    await updateActualTime(estimateId, {
      actual_start_time: new Date('2026-02-19T10:00:00'),
      actual_completion_time: new Date('2026-02-19T13:00:00'), // 3 hours actual
    });
    
    const estimate = await getRepairTimeEstimate(estimateId);
    expect(estimate.variance_minutes).toBe(30); // 30 minutes over
    expect(estimate.is_accurate).toBe(false);
  });
});

describe('Labor Cost Separation', () => {
  
  test('Labor cost goes to shop, not mechanic', async () => {
    const requestId = 'req-123';
    
    await calculateServiceCosts(requestId, {
      parts_cost: 1000,
      labor_hours: 2,
      hourly_rate: 500,
    });
    
    const breakdown = await getServiceCostBreakdown(requestId);
    
    expect(breakdown.labor_cost).toBe(1000); // 2 hours * 500
    expect(breakdown.shop_earnings).toBe(2000); // parts + labor
    expect(breakdown.mechanic_earnings).toBe(0); // Mechanic paid by shop
  });
  
  test('Platform gets 10% service fee', async () => {
    const requestId = 'req-123';
    
    await calculateServiceCosts(requestId, {
      parts_cost: 1000,
      labor_hours: 2,
      hourly_rate: 500,
    });
    
    const breakdown = await getServiceCostBreakdown(requestId);
    
    const subtotal = breakdown.parts_cost + breakdown.labor_cost; // 2000
    const expectedFee = subtotal * 0.10; // 200
    
    expect(breakdown.service_fee).toBe(expectedFee);
    expect(breakdown.platform_earnings).toBe(expectedFee);
  });
});

describe('Payment Communication', () => {
  
  test('Customer can message shop owner about payment', async () => {
    const result = await sendPaymentMessage({
      request_id: 'req-123',
      sender_id: 'customer-1',
      sender_type: 'customer',
      receiver_id: 'shop-1',
      receiver_type: 'shop_owner',
      message_type: 'payment_clarification',
      message: 'Can we split the payment?',
    });
    
    expect(result.id).toBeDefined();
  });
  
  test('Payment messages are real-time', async () => {
    const messageSent = sendPaymentMessage(/*...*/);
    
    // Subscribe to messages
    const messages = await subscribeToPaymentMessages('req-123');
    
    // Should receive the message
    expect(messages).toContainEqual(expect.objectContaining({
      message: 'Can we split the payment?'
    }));
  });
});
```

#### **6.2 Integration Tests**

```typescript
// tests/integration/complete-service-flow.test.ts

describe('Complete Service Flow', () => {
  
  test('Customer requests service → Mechanic accepts → Completes → Rated', async () => {
    // 1. Customer creates request
    const request = await createServiceRequest({
      customer_id: 'customer-1',
      title: 'Oil Change',
      category_id: 'oil-change-cat',
      location: { lat: 14.5995, lng: 120.9842 },
    });
    
    expect(request.status).toBe('pending');
    
    // 2. System finds best mechanic
    const rankedMechanics = await getRankedMechanics(request, {
      location: request.location,
      specialization: ['Oil Change'],
      urgencyLevel: 'normal',
    });
    
    expect(rankedMechanics.length).toBeGreaterThan(0);
    const bestMechanic = rankedMechanics[0];
    
    // 3. Mechanic accepts
    await acceptRequest(bestMechanic.id, request.id);
    
    const updatedRequest = await getServiceRequest(request.id);
    expect(updatedRequest.status).toBe('accepted');
    expect(updatedRequest.assigned_mechanic_id).toBe(bestMechanic.id);
    
    // 4. Mechanic provides estimate
    await createRepairTimeEstimate({
      request_id: request.id,
      mechanic_id: bestMechanic.id,
      estimated_hours: 1,
      estimated_minutes: 0,
    });
    
    // 5. Service completed
    await completeServiceRequest(request.id);
    
    // 6. Customer rates service
    await submitReview({
      request_id: request.id,
      mechanic_id: bestMechanic.id,
      overall_rating: 5.0,
      review_text: 'Excellent service!',
    });
    
    // 7. Verify mechanic rating updated
    const mechanic = await getMechanic(bestMechanic.id);
    expect(mechanic.rating).toBeGreaterThan(0);
  });
});
```

---

## 📊 **IMPLEMENTATION TIMELINE SUMMARY**

| Phase | Duration | Priority | Features |
|-------|----------|----------|----------|
| **Phase 1** | Week 1-2 | 🔴 Critical | Database schema, Queue algorithm, Decline penalty |
| **Phase 2** | Week 2-3 | 🟡 High | Rating system, Review workflow, Auto-calculate ratings |
| **Phase 3** | Week 3-4 | 🟢 Medium | Cancellation limits, Penalties, Restrictions |
| **Phase 4** | Week 4-5 | 🟢 Medium | Time estimation, Labor cost separation |
| **Phase 5** | Week 5-6 | 🟡 Medium | Payment chat, Mechanic assessment |
| **Phase 6** | Week 6-7 | 🔴 Critical | Comprehensive testing, Integration tests |

**Total Duration:** 6-7 weeks

---

## ✅ **SUCCESS CRITERIA**

### **Functional Requirements:**
- [x] Queue algorithm ranks mechanics by location, rating, specialization
- [x] Declining 5 times/day suspends mechanic temporarily
- [x] Customers can cancel 2x/week freely, 5x/week = 24h restriction
- [x] Reviews update average ratings automatically
- [x] Time estimates provided by mechanics, variance tracked
- [x] Labor cost goes to shop, not mechanic directly
- [x] Shop owners and customers can communicate about payment
- [x] Mechanic skills can be assessed and certified
- [x] Cash payment accepted and verified

### **Non-Functional Requirements:**
- [x] All features have comprehensive test coverage (>80%)
- [x] Queue matching happens within 2 seconds
- [x] Real-time updates for ratings and messages
- [x] Mobile-responsive UI for all screens
- [x] Analytics dashboard tracks all metrics

---

## 🎯 **QUICK START CHECKLIST**

### **Week 1 - Day 1:**
1. [ ] Create all new database tables
2. [ ] Add indexes for performance
3. [ ] Create RLS policies for security
4. [ ] Test database migrations

### **Week 1 - Day 2-3:**
1. [ ] Implement queue priority algorithm
2. [ ] Write unit tests for algorithm
3. [ ] Create decline penalty function
4. [ ] Test with sample data

### **Week 1 - Day 4-5:**
1. [ ] Build cancellation limit system
2. [ ] Create restriction logic
3. [ ] Test cancellation flows
4. [ ] Add activity logging

### **Week 2:**
1. [ ] Build rating UI (customer side)
2. [ ] Create review submission flow
3. [ ] Implement auto-rating calculation
4. [ ] Add review moderation for admin

### **Continue weekly checkpoints...**

---

## 📈 **METRICS TO TRACK**

1. **Queue Performance:**
   - Average time to match mechanic: < 2 seconds
   - Successful match rate: > 90%
   - Decline rate: < 10%

2. **Cancellation Rates:**
   - Customer cancellation rate: < 5%
   - Restricted users: < 1%

3. **Rating System:**
   - Average rating: > 4.0
   - Review submission rate: > 60%
   - Rating accuracy vs actual performance

4. **Time Estimation:**
   - Estimate accuracy: ±30 minutes
   - On-time completion rate: > 80%

5. **Payment:**
   - Successful payment rate: > 95%
   - Dispute rate: < 2%
   - Communication response time: < 30 minutes

---

## 🔧 **TECHNICAL STACK**

- **Backend:** Supabase (PostgreSQL + Real-time)
- **Mobile:** Flutter/Dart
- **Web Admin:** Next.js + TypeScript
- **Testing:** Jest + Supertest
- **Deployment:** Vercel + Supabase Cloud

---

## 📞 **SUPPORT & QUESTIONS**

For implementation questions:
1. Check each phase documentation
2. Review test cases for examples
3. Consult database schema comments
4. Test with sample data first

**Good luck with implementation! 🚀**
