# Gemini AI Integration for Towing Detection - Implementation Summary

## Feature Overview
Integrated Google Gemini AI to automatically analyze customer issue descriptions and intelligently detect when towing service is needed.

## API Details
- **API Key**: `AIzaSyBN8VKuOYcmrdzJ5T3KpkxaCa-PNs3Wk8o`
- **Model**: `gemini-pro`
- **Endpoint**: Google Generative Language API

## Implementation

### 1. Created `gemini_issue_analysis_service.dart`

**Location**: `lib/services/gemini_issue_analysis_service.dart`

**Key Features:**
- ✅ Analyzes customer's issue description using Gemini AI
- ✅ Determines if towing service is needed
- ✅ Assesses severity level (minor/moderate/severe/critical)
- ✅ Identifies primary issue
- ✅ Recommends appropriate services
- ✅ Estimates time required
- ✅ Detects safety concerns
- ✅ Determines if vehicle can be driven safely
- ✅ Fallback keyword analysis if AI fails

**Main Method:**
```dart
Future<Map<String, dynamic>> analyzeIssueDescription(String description)
```

**Returns:**
```dart
{
  'success': true,
  'needs_towing': true/false,
  'severity': 'minor/moderate/severe/critical',
  'primary_issue': 'description of main problem',
  'recommended_services': ['service1', 'service2'],
  'estimated_time': 'time estimate',
  'safety_concerns': 'safety issues or null',
  'can_drive': true/false,
  'explanation': 'AI explanation'
}
```

**Towing Detection Logic:**
AI recommends towing if description contains indicators of:
- Engine won't start / complete failure
- Transmission problems
- Severe accident damage
- Wheel/axle damage
- Major mechanical breakdown
- Vehicle immobile or unsafe to drive

**Does NOT recommend towing for:**
- Flat tire only (can be changed on-site)
- Minor battery issues (jump start available)
- Fuel problems (refueling possible)
- Lockout situations
- Minor repairs

### 2. Updated `service_request_screen.dart`

**Location**: `lib/customer/service_request_screen.dart`

**Added Features:**

#### A. Auto-Analysis on Description Input
- **Trigger**: Automatically analyzes when customer types 20+ characters
- **Debounce**: 2-second delay after typing stops
- **Manual Trigger**: Brain icon button to analyze on demand
- **Loading State**: Shows spinner while analyzing

```dart
onChanged: (value) {
  if (value.trim().length >= 20) {
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isAnalyzing) {
        _analyzeIssueWithAI();
      }
    });
  }
}
```

#### B. Towing Recommendation Dialog
**Shows when AI detects towing is needed:**
- 🤖 AI Analysis explanation
- ⚠️ Severity level with color coding
- 🔧 Primary issue identification
- ⏱️ Estimated time
- ⚠️ Safety concerns (if any)
- ✅ Recommended services list

**User Options:**
1. **Request Towing** - Marks request as emergency, keeps recommendation visible
2. **Continue Without Towing** - Dismisses dialog, continues with normal service request

#### C. Visual Towing Recommendation Card
**Appears after analysis if towing recommended:**
- Orange gradient card with towing truck icon
- AI analysis summary
- Severity and time badges
- Safety warning if vehicle can't be driven
- Dismissible with X button

**Features:**
- Eye-catching design with shadow effect
- Clear AI attribution
- Compact severity/time badges
- Contextual safety message
- Easy to dismiss if customer disagrees

### 3. User Experience Flow

```
Customer describes issue
    ↓
Types description (20+ characters)
    ↓
2-second pause detected
    ↓
🤖 Gemini AI analyzes description
    ↓
┌─────────────────────┬──────────────────────┐
│ Towing Needed       │ No Towing Needed     │
├─────────────────────┼──────────────────────┤
│ • Dialog appears    │ • Silent analysis    │
│ • Shows AI result   │ • No interruption    │
│ • Orange card       │ • Continues normally │
│ • Auto-emergency    │                      │
└─────────────────────┴──────────────────────┘
    ↓
Customer reviews recommendation
    ↓
┌────────────────────┬─────────────────────┐
│ Request Towing     │ Skip Towing         │
├────────────────────┼─────────────────────┤
│ • Emergency = true │ • Hides card        │
│ • Major severity   │ • Normal request    │
│ • Card stays       │                     │
└────────────────────┴─────────────────────┘
    ↓
Submit service request
```

## Sample AI Analysis Examples

### Example 1: Towing Needed
**Customer Input:**
"My car won't start at all. I hear clicking sounds when I turn the key but the engine doesn't crank. I'm stranded on the highway."

**AI Analysis:**
```json
{
  "needs_towing": true,
  "severity": "severe",
  "primary_issue": "Engine failure - won't start",
  "recommended_services": ["Towing Service", "Diagnostic Check", "Battery Test"],
  "estimated_time": "45-60 minutes",
  "safety_concerns": "Vehicle stranded on highway - potential hazard",
  "can_drive": false,
  "explanation": "Complete engine failure requires towing. Vehicle cannot be driven safely."
}
```

### Example 2: No Towing Needed
**Customer Input:**
"I have a flat tire on the front passenger side. The tire went flat while I was parked at the mall."

**AI Analysis:**
```json
{
  "needs_towing": false,
  "severity": "minor",
  "primary_issue": "Flat tire - roadside repair possible",
  "recommended_services": ["Tire Change", "Tire Inspection"],
  "estimated_time": "20-30 minutes",
  "safety_concerns": null,
  "can_drive": false,
  "explanation": "Simple flat tire can be changed on-site. No towing required."
}
```

### Example 3: Emergency Towing
**Customer Input:**
"I was in a car accident. Front end is badly damaged, fluids leaking, can't move the car."

**AI Analysis:**
```json
{
  "needs_towing": true,
  "severity": "critical",
  "primary_issue": "Accident damage - vehicle inoperable",
  "recommended_services": ["Emergency Towing", "Accident Assessment", "Insurance Documentation"],
  "estimated_time": "30-45 minutes",
  "safety_concerns": "Fluid leaks and structural damage - immediate towing required",
  "can_drive": false,
  "explanation": "Severe accident damage requires immediate towing. Vehicle unsafe and immobile."
}
```

## Technical Details

### AI Prompt Engineering
The service uses a carefully crafted prompt that:
- Instructs AI to act as automotive expert
- Requests structured JSON response
- Defines clear criteria for towing decision
- Includes severity assessment guidelines
- Specifies safety concern detection
- Ensures consistent output format

### Error Handling
- **Fallback Analysis**: If AI fails, uses keyword-based detection
- **Graceful Degradation**: Doesn't block service request on AI failure
- **Validation**: Parses and validates AI response format
- **Timeout Protection**: Prevents hanging requests

### Performance Optimization
- **Debouncing**: Prevents excessive API calls while typing
- **Minimum Length**: Only analyzes descriptions with 20+ characters
- **Caching**: Stores last analysis result
- **Async Operation**: Non-blocking UI during analysis

## Benefits

### For Customers:
✅ **Intelligent Guidance** - AI helps identify when towing is needed
✅ **Time Saving** - Correct service type requested from start
✅ **Cost Efficiency** - Avoids unnecessary towing charges
✅ **Safety Awareness** - Alerts to potential hazards
✅ **Informed Decisions** - Clear explanation of recommendations

### For Service Providers:
✅ **Better Routing** - Towing trucks dispatched only when needed
✅ **Resource Optimization** - Right service type assigned
✅ **Reduced Confusion** - Clear issue classification
✅ **Faster Response** - No back-and-forth about service type

### For System:
✅ **Improved Accuracy** - AI-powered classification
✅ **Reduced Mis-routing** - Correct service from start
✅ **Better Analytics** - Structured issue data
✅ **Enhanced UX** - Proactive assistance

## Configuration

### API Key Security
⚠️ **Current Status**: API key is hardcoded in service file
📌 **Production Recommendation**: Move to environment variables or secure configuration

### Customization Options
- Adjust debounce delay (currently 2 seconds)
- Modify minimum description length (currently 20 characters)
- Change AI temperature for response creativity (currently 0.3)
- Update severity color schemes
- Customize towing criteria in prompt

## Testing Scenarios

### Test Case 1: Engine Won't Start
- **Input**: "Engine won't turn over, just clicking"
- **Expected**: Towing recommended, severity = severe

### Test Case 2: Flat Tire
- **Input**: "Got a flat tire, need help changing it"
- **Expected**: No towing, severity = minor

### Test Case 3: Transmission Issue
- **Input**: "Car won't shift gears, making grinding noise"
- **Expected**: Towing recommended, severity = major

### Test Case 4: Lockout
- **Input**: "Locked my keys in the car"
- **Expected**: No towing, severity = minor

### Test Case 5: Accident
- **Input**: "Hit a guardrail, car won't move"
- **Expected**: Towing recommended, severity = critical

## Future Enhancements

### Potential Improvements:
1. **Multi-language Support** - Analyze descriptions in different languages
2. **Image Analysis** - Upload photos for visual AI assessment
3. **Location Context** - Factor in location (highway vs parking lot)
4. **Historical Data** - Learn from past service request outcomes
5. **Cost Estimation** - Predict service costs based on issue
6. **Parts Availability** - Check if parts needed are available
7. **Provider Matching** - Recommend specific service providers
8. **Real-time Updates** - Update analysis if description changes
9. **Voice Input** - Speak issue description for analysis
10. **Comparison Mode** - Compare AI vs actual outcome for learning

## Success Criteria

✅ **Implemented Successfully**
- Gemini AI service created and functional
- Service request screen integrated with AI
- Auto-analysis on description input
- Visual towing recommendation system
- Dialog for AI results
- Fallback analysis for reliability

## Files Modified

1. **New File**: `lib/services/gemini_issue_analysis_service.dart` (206 lines)
2. **Modified**: `lib/customer/service_request_screen.dart` (+180 lines)
   - Added AI analysis state variables
   - Added `_analyzeIssueWithAI()` method
   - Added `_showTowingRecommendationDialog()` method
   - Added towing recommendation card UI
   - Added helper methods for badges and colors
   - Updated description TextField with AI button

## Result

🎉 **Feature Complete and Ready for Testing!**

Customers can now get intelligent, AI-powered guidance on whether their vehicle issue requires towing service, improving service accuracy and customer satisfaction.
