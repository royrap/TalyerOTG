# 🎯 Queue Priority System - Implementation Guide

## Overview

This guide shows you how to implement the **Queue Priority & Matching Algorithm** system that includes:

✅ **Decline Penalty System** - Every decline reduces queue priority  
✅ **Smart Queueing** - Based on Location + Queue Priority + Specialization  
✅ **Auto-Matching** - Intelligent mechanic-customer matching  
✅ **Broadcast System** - Multi-mechanic notification when needed  

---

## 🗄️ Database Setup

### Step 1: Run SQL Scripts in Order

Execute these files in your Supabase SQL Editor:

```bash
1. database/queue_priority_system.sql
2. database/queue_matching_algorithm.sql
3. database/queue_rpc_functions.sql
```

**What these do:**
- Creates `mechanic_queue_scores` table
- Creates `service_request_queue` table
- Adds decline penalty functions
- Implements matching algorithm
- Exposes RPC functions for your app

---

## 📱 Flutter Implementation

### A. Mechanic App - Decline Request

```dart
// lib/mechanic/services/queue_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class QueueService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Mechanic declines a service request
  Future<Map<String, dynamic>> declineRequest({
    required String mechanicId,
    required String requestId,
    String? reason,
  }) async {
    try {
      final response = await _supabase.rpc(
        'rpc_mechanic_decline_request',
        params: {
          'p_mechanic_id': mechanicId,
          'p_request_id': requestId,
          'p_reason': reason ?? 'Not available',
        },
      );

      if (response['success'] == true) {
        // Check if suspended
        if (response['is_suspended'] == true) {
          // Show suspension warning
          _showSuspensionDialog(
            declinestoday: response['declines_today'],
            message: response['message'],
          );
        } else if (response['declines_today'] >= 3) {
          // Show warning
          _showWarningDialog(
            'Warning: You have declined ${response['declines_today']} requests today. '
            'Further declines may result in temporary suspension.',
          );
        }
      }

      return response;
    } catch (e) {
      print('Error declining request: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  void _showSuspensionDialog({
    required int declinesToday,
    required String message,
  }) {
    // Show dialog to mechanic
    // "You are temporarily suspended for 1 hour due to excessive declines"
  }

  void _showWarningDialog(String message) {
    // Show warning dialog
  }
}
```

### B. Mechanic App - Accept Request

```dart
/// Mechanic accepts a service request
Future<Map<String, dynamic>> acceptRequest({
  required String mechanicId,
  required String requestId,
}) async {
  try {
    final response = await _supabase.rpc(
      'rpc_mechanic_accept_request',
      params: {
        'p_mechanic_id': mechanicId,
        'p_request_id': requestId,
      },
    );

    if (response['success'] == true) {
      // Navigate to job details screen
      _navigateToJobDetails(requestId);
    } else {
      _showError(response['error'] ?? 'Failed to accept request');
    }

    return response;
  } catch (e) {
    print('Error accepting request: $e');
    return {'success': false, 'error': e.toString()};
  }
}
```

### C. Mechanic App - Get Queue Dashboard

```dart
/// Get mechanic's queue dashboard
Future<Map<String, dynamic>> getMyQueueDashboard(String mechanicId) async {
  try {
    final response = await _supabase.rpc(
      'rpc_get_my_queue_dashboard',
      params: {'p_mechanic_id': mechanicId},
    );

    return response;
  } catch (e) {
    print('Error getting queue dashboard: $e');
    return {};
  }
}
```

**Display Queue Dashboard Widget:**

```dart
// lib/mechanic/widgets/queue_dashboard_widget.dart

class QueueDashboardWidget extends StatefulWidget {
  final String mechanicId;

  const QueueDashboardWidget({required this.mechanicId});

  @override
  _QueueDashboardWidgetState createState() => _QueueDashboardWidgetState();
}

class _QueueDashboardWidgetState extends State<QueueDashboardWidget> {
  Map<String, dynamic>? dashboardData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    final data = await QueueService().getMyQueueDashboard(widget.mechanicId);
    setState(() {
      dashboardData = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return CircularProgressIndicator();
    if (dashboardData == null) return Text('No data');

    final queueScore = dashboardData!['queue_score'] ?? 100.0;
    final isSuspended = dashboardData!['is_suspended'] ?? false;
    final todayStats = dashboardData!['today_stats'] ?? {};

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Queue Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            
            // Queue Score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Queue Priority Score'),
                Text(
                  queueScore.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: queueScore > 100 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8),
            
            // Score Breakdown
            _buildScoreRow('Base Score', dashboardData!['base_score']),
            _buildScoreRow('Decline Penalty', -dashboardData!['decline_penalty'], isNegative: true),
            _buildScoreRow('Rating Bonus', dashboardData!['rating_bonus']),
            _buildScoreRow('Completion Bonus', dashboardData!['completion_bonus']),
            
            Divider(height: 24),
            
            // Today's Stats
            Text('Today\'s Activity', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            _buildStatRow('Declines', todayStats['declines'] ?? 0, Colors.red),
            _buildStatRow('Accepts', todayStats['accepts'] ?? 0, Colors.green),
            
            // Suspension Warning
            if (isSuspended) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Account Suspended - Excessive declines',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, double value, {bool isNegative = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            '${isNegative ? "-" : "+"}${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: isNegative ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.toString(),
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
```

### D. Mechanic App - Get Pending Requests

```dart
/// Get mechanic's pending requests (sorted by urgency and priority)
Future<List<Map<String, dynamic>>> getMyPendingRequests(String mechanicId) async {
  try {
    final response = await _supabase.rpc(
      'rpc_get_my_pending_requests',
      params: {'p_mechanic_id': mechanicId},
    );

    return List<Map<String, dynamic>>.from(response ?? []);
  } catch (e) {
    print('Error getting pending requests: $e');
    return [];
  }
}
```

---

### E. Customer App - Create Request with Auto-Matching

```dart
// lib/customer/services/request_service.dart

class RequestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a service request and auto-match with best mechanic
  Future<Map<String, dynamic>> createRequestWithMatching({
    required String customerId,
    required String title,
    required String description,
    required String categoryId,
    required double latitude,
    required double longitude,
    String urgencyLevel = 'normal', // 'low', 'normal', 'high', 'emergency'
  }) async {
    try {
      final response = await _supabase.rpc(
        'rpc_customer_create_request_with_matching',
        params: {
          'p_customer_id': customerId,
          'p_title': title,
          'p_description': description,
          'p_category_id': categoryId,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_urgency_level': urgencyLevel,
        },
      );

      if (response['success'] == true) {
        final matchingResult = response['matching_result'];
        final matchType = matchingResult['match_type'];

        if (matchType == 'direct') {
          // Direct match found!
          _showMatchFound(
            mechanicName: matchingResult['mechanic_name'],
            distance: matchingResult['distance_km'],
            confidence: matchingResult['match_confidence'],
          );
        } else if (matchType == 'broadcast') {
          // Broadcasting to multiple mechanics
          _showBroadcasting(
            mechanicsNotified: matchingResult['broadcast_result']['mechanics_notified'],
          );
        }
      }

      return response;
    } catch (e) {
      print('Error creating request: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  void _showMatchFound({
    required String mechanicName,
    required double distance,
    required double confidence,
  }) {
    // Show dialog: "We found a perfect match! [mechanicName] is [distance]km away"
  }

  void _showBroadcasting({required int mechanicsNotified}) {
    // Show dialog: "Finding the best mechanic for you... Notified [mechanicsNotified] mechanics"
  }
}
```

### F. Customer App - Get Nearby Mechanics

```dart
/// Get nearby available mechanics
Future<List<Map<String, dynamic>>> getNearbyMechanics({
  required double latitude,
  required double longitude,
  double maxDistanceKm = 50.0,
  String? specialization,
  int limit = 20,
}) async {
  try {
    final response = await _supabase.rpc(
      'rpc_get_nearby_mechanics',
      params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_max_distance_km': maxDistanceKm,
        'p_specialization': specialization,
        'p_limit': limit,
      },
    );

    return List<Map<String, dynamic>>.from(response ?? []);
  } catch (e) {
    print('Error getting nearby mechanics: $e');
    return [];
  }
}
```

---

## 🌐 Admin Dashboard (Next.js/TypeScript)

### A. View Queue Statistics

```typescript
// app/admin/queue-management/page.tsx

'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'

interface QueueStats {
  active_requests: number
  pending_broadcasts: number
  average_wait_time_minutes: number
  total_mechanics_available: number
  total_mechanics_suspended: number
  average_queue_score: number
  top_performers: Array<{
    id: string
    name: string
    total_score: number
    total_accepts: number
    rating: number
  }>
  bottom_performers: Array<{
    id: string
    name: string
    total_score: number
    declines_today: number
    is_suspended: boolean
  }>
}

export default function QueueManagementPage() {
  const [stats, setStats] = useState<QueueStats | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadStats()
    // Refresh every 30 seconds
    const interval = setInterval(loadStats, 30000)
    return () => clearInterval(interval)
  }, [])

  async function loadStats() {
    try {
      const { data, error } = await supabase.rpc('rpc_admin_get_queue_stats')
      if (error) throw error
      setStats(data[0])
    } catch (error) {
      console.error('Error loading queue stats:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) return <div>Loading...</div>
  if (!stats) return <div>No data available</div>

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold">Queue Management</h1>

      {/* Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Active Requests</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{stats.active_requests}</div>
            <p className="text-sm text-gray-500">Currently in queue</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Available Mechanics</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">
              {stats.total_mechanics_available}
            </div>
            <p className="text-sm text-gray-500">
              {stats.total_mechanics_suspended} suspended
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Avg Wait Time</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">
              {stats.average_wait_time_minutes?.toFixed(1) || 0} min
            </div>
            <p className="text-sm text-gray-500">Average queue wait</p>
          </CardContent>
        </Card>
      </div>

      {/* Top Performers */}
      <Card>
        <CardHeader>
          <CardTitle>Top Performing Mechanics</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {stats.top_performers?.map((mechanic, index) => (
              <div key={mechanic.id} className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center text-white font-bold">
                    {index + 1}
                  </div>
                  <div>
                    <div className="font-semibold">{mechanic.name}</div>
                    <div className="text-sm text-gray-500">
                      {mechanic.total_accepts} accepts • Rating: {mechanic.rating?.toFixed(1)}
                    </div>
                  </div>
                </div>
                <Badge variant="outline" className="bg-green-50">
                  Score: {mechanic.total_score?.toFixed(2)}
                </Badge>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Bottom Performers / Need Attention */}
      <Card>
        <CardHeader>
          <CardTitle>Mechanics Needing Attention</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {stats.bottom_performers?.map((mechanic) => (
              <div key={mechanic.id} className="flex items-center justify-between">
                <div>
                  <div className="font-semibold">{mechanic.name}</div>
                  <div className="text-sm text-gray-500">
                    {mechanic.declines_today} declines today
                  </div>
                </div>
                <div className="flex items-center space-x-2">
                  {mechanic.is_suspended && (
                    <Badge variant="destructive">Suspended</Badge>
                  )}
                  <Badge variant="outline" className="bg-red-50">
                    Score: {mechanic.total_score?.toFixed(2)}
                  </Badge>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
```

### B. Reset Mechanic Decline Count

```typescript
// Add to admin interface

async function resetMechanicDeclines(mechanicId: string, reason: string) {
  try {
    const { data, error } = await supabase.rpc('rpc_admin_reset_mechanic_declines', {
      p_admin_id: currentUserId,
      p_mechanic_id: mechanicId,
      p_reason: reason,
    })

    if (error) throw error

    if (data.success) {
      toast.success('Mechanic decline count has been reset')
      // Refresh the list
      loadStats()
    } else {
      toast.error(data.error)
    }
  } catch (error) {
    console.error('Error resetting declines:', error)
    toast.error('Failed to reset decline count')
  }
}
```

---

## 🔄 Scheduled Jobs

You need to set up these scheduled jobs (using pg_cron or external scheduler):

### 1. Daily Reset (Midnight)

```sql
-- Reset daily decline counters
SELECT cron.schedule(
  'reset-daily-declines',
  '0 0 * * *',  -- Every day at midnight
  'SELECT reset_daily_decline_counters()'
);
```

### 2. Process Expired Broadcasts (Every 5 minutes)

```sql
SELECT cron.schedule(
  'process-expired-broadcasts',
  '*/5 * * * *',  -- Every 5 minutes
  'SELECT process_expired_broadcasts()'
);
```

---

## 📊 Testing the System

### Test Scenario 1: Normal Flow

```dart
// 1. Customer creates request
final result = await requestService.createRequestWithMatching(
  customerId: 'customer-uuid',
  title: 'Oil Change',
  description: 'Need oil change for my car',
  categoryId: 'oil-change-category-uuid',
  latitude: 14.5995,
  longitude: 120.9842,
  urgencyLevel: 'normal',
);

// Expected: System finds best mechanic and notifies them
```

### Test Scenario 2: Mechanic Declines

```dart
// Mechanic declines 3 times
for (int i = 0; i < 3; i++) {
  await queueService.declineRequest(
    mechanicId: 'mechanic-uuid',
    requestId: 'request-$i-uuid',
    reason: 'Too far',
  );
}

// Expected: Warning shown on 3rd decline
```

### Test Scenario 3: Excessive Declines

```dart
// Mechanic declines 5 times
for (int i = 0; i < 5; i++) {
  await queueService.declineRequest(
    mechanicId: 'mechanic-uuid',
    requestId: 'request-$i-uuid',
    reason: 'Not available',
  );
}

// Expected: Mechanic suspended for 1 hour
```

---

## 🎯 Key Concepts

### Queue Priority Score Calculation

```
Final Score = Base Score (100) 
            - Decline Penalty (5 per decline, max 80)
            + Rating Bonus (0-20 based on rating)
            + Completion Bonus (2 per completed job)
            + Distance Factor (100 - distance*5)
            + Specialization Match (+50)
            + Availability Factor (-100 to +30)
```

### Decline Penalty Tiers

- **1-2 declines**: -5 to -10 penalty
- **3-4 declines**: -25 penalty + warning
- **5+ declines**: -50 penalty + 1 hour suspension

### Suspension Policy

- **Trigger**: 5 declines in one day
- **Duration**: 1 hour
- **Effect**: Cannot receive new requests
- **Reset**: Automatic after 1 hour OR admin manual reset

---

## ✅ Implementation Checklist

- [ ] Run all SQL scripts in Supabase
- [ ] Implement decline handler in mechanic app
- [ ] Implement accept handler in mechanic app
- [ ] Add queue dashboard widget
- [ ] Implement auto-matching in customer app
- [ ] Add admin queue management page
- [ ] Set up scheduled jobs (pg_cron)
- [ ] Test decline penalty system
- [ ] Test auto-matching algorithm
- [ ] Test broadcast system
- [ ] Monitor queue statistics

---

## 🚀 Next Steps

After implementing this system, you can add:

1. **Real-time notifications** using Supabase Realtime
2. **Analytics dashboard** for queue performance
3. **Mechanic leaderboard** based on queue scores
4. **Customer satisfaction tracking** tied to queue quality
5. **Dynamic pricing** based on queue position

---

## 📞 Support

If you encounter issues:

1. Check Supabase function logs
2. Verify RLS policies are correct
3. Ensure PostGIS is enabled
4. Check mechanic location data is populated

**System is ready! Start implementing! 🎉**
