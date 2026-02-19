import 'package:flutter/material.dart';
import '../widgets/responsive_layout.dart';
import '../utils/responsive_helper.dart';

/// Example: Converting ShopSettingsScreen to be fully responsive
/// This shows BEFORE and AFTER comparisons

// ============================================
// BEFORE: Fixed Layout (Not Responsive)
// ============================================

class ShopSettingsScreenOld extends StatefulWidget {
  @override
  State<ShopSettingsScreenOld> createState() => _ShopSettingsScreenOldState();
}

class _ShopSettingsScreenOldState extends State<ShopSettingsScreenOld> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shop Settings'),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16), // ❌ Fixed padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headline
            Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 20, // ❌ Fixed font size
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16), // ❌ Fixed spacing
            
            // Card
            Card(
              elevation: 2, // ❌ Fixed elevation
              child: Padding(
                padding: EdgeInsets.all(16), // ❌ Fixed padding
                child: Column(
                  children: [
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Shop Name',
                        labelStyle: TextStyle(fontSize: 14), // ❌ Fixed
                      ),
                    ),
                    SizedBox(height: 16), // ❌ Fixed spacing
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Address',
                        labelStyle: TextStyle(fontSize: 14), // ❌ Fixed
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24), // ❌ Fixed spacing
            
            // Button
            SizedBox(
              width: double.infinity,
              height: 48, // ❌ Fixed height
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16), // ❌ Fixed font size
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// AFTER: Responsive Layout
// ============================================

class ShopSettingsScreenNew extends StatefulWidget {
  @override
  State<ShopSettingsScreenNew> createState() => _ShopSettingsScreenNewState();
}

class _ShopSettingsScreenNewState extends State<ShopSettingsScreenNew> {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Shop Settings',
      constrainContent: true, // ✅ Constrains width on desktop
      body: SingleChildScrollView(
        padding: ResponsiveHelper.responsivePadding(context), // ✅ Responsive
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headline with responsive font size
            ResponsiveText(
              'Basic Information',
              type: ResponsiveTextType.title, // ✅ Responsive
            ),
            ResponsiveSpacing.medium(), // ✅ Responsive spacing
            
            // Responsive card
            ResponsiveCard(
              child: Column(
                children: [
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Shop Name',
                      labelStyle: TextStyle(
                        fontSize: ResponsiveHelper.bodyFontSize(context), // ✅
                      ),
                      contentPadding: EdgeInsets.all(
                        ResponsiveHelper.spacing(context, base: 12), // ✅
                      ),
                    ),
                  ),
                  ResponsiveSpacing.medium(), // ✅
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Address',
                      labelStyle: TextStyle(
                        fontSize: ResponsiveHelper.bodyFontSize(context), // ✅
                      ),
                      contentPadding: EdgeInsets.all(
                        ResponsiveHelper.spacing(context, base: 12), // ✅
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            ResponsiveSpacing.large(), // ✅ Responsive spacing
            
            // Responsive button
            ResponsiveButton(
              text: 'Save Changes',
              onPressed: () {},
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Example: List Screen with Responsive Grid
// ============================================

class ShopsListScreenExample extends StatelessWidget {
  final List<Map<String, String>> shops = [
    {'name': 'Shop 1', 'address': 'Address 1'},
    {'name': 'Shop 2', 'address': 'Address 2'},
    {'name': 'Shop 3', 'address': 'Address 3'},
    {'name': 'Shop 4', 'address': 'Address 4'},
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Available Shops',
      constrainContent: true,
      body: ResponsiveLayout(
        // Mobile: ListView
        mobile: _buildListView(context),
        
        // Tablet & Desktop: GridView
        tablet: _buildGridView(context),
        desktop: _buildGridView(context),
      ),
    );
  }

  Widget _buildListView(BuildContext context) {
    return ListView.builder(
      padding: ResponsiveHelper.responsivePadding(context),
      itemCount: shops.length,
      itemBuilder: (context, index) {
        return ResponsiveCard(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveText(
                shops[index]['name']!,
                type: ResponsiveTextType.title,
              ),
              ResponsiveSpacing.small(),
              ResponsiveText(
                shops[index]['address']!,
                type: ResponsiveTextType.caption,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridView(BuildContext context) {
    return ResponsiveGrid(
      children: shops.map((shop) {
        return ResponsiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveText(
                shop['name']!,
                type: ResponsiveTextType.title,
              ),
              ResponsiveSpacing.small(),
              ResponsiveText(
                shop['address']!,
                type: ResponsiveTextType.caption,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ============================================
// Example: Form with Responsive Layout
// ============================================

class ResponsiveFormExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Request Service',
      constrainContent: true,
      body: SingleChildScrollView(
        padding: ResponsiveHelper.responsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveText(
              'Service Details',
              type: ResponsiveTextType.headline,
            ),
            ResponsiveSpacing.large(),
            
            // Service Type Selection
            ResponsiveCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveText(
                    'Select Service Type',
                    type: ResponsiveTextType.title,
                  ),
                  ResponsiveSpacing.medium(),
                  
                  // Options in responsive grid
                  ResponsiveLayout(
                    mobile: Column(
                      children: [
                        _buildServiceOption(context, 'Towing', Icons.local_shipping),
                        ResponsiveSpacing.small(),
                        _buildServiceOption(context, 'Repair', Icons.build),
                        ResponsiveSpacing.small(),
                        _buildServiceOption(context, 'Battery', Icons.battery_charging_full),
                      ],
                    ),
                    tablet: Wrap(
                      spacing: ResponsiveHelper.spacing(context),
                      runSpacing: ResponsiveHelper.spacing(context),
                      children: [
                        _buildServiceOption(context, 'Towing', Icons.local_shipping),
                        _buildServiceOption(context, 'Repair', Icons.build),
                        _buildServiceOption(context, 'Battery', Icons.battery_charging_full),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            ResponsiveSpacing.large(),
            
            // Description
            ResponsiveCard(
              child: TextFormField(
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Describe the problem',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(
                    ResponsiveHelper.spacing(context),
                  ),
                ),
                style: TextStyle(
                  fontSize: ResponsiveHelper.bodyFontSize(context),
                ),
              ),
            ),
            
            ResponsiveSpacing.large(),
            
            // Submit button
            ResponsiveButton(
              text: 'Submit Request',
              icon: Icons.send,
              onPressed: () {},
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceOption(BuildContext context, String label, IconData icon) {
    return InkWell(
      onTap: () {},
      child: Container(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(context)),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(context),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: ResponsiveHelper.iconSize(context),
              color: Colors.red,
            ),
            SizedBox(width: ResponsiveHelper.smallSpacing(context)),
            ResponsiveText(
              label,
              type: ResponsiveTextType.body,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Example: Dashboard with Adaptive Layout
// ============================================

class ResponsiveDashboardExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Dashboard',
      constrainContent: true,
      body: ResponsiveLayout(
        // Mobile: Stack layout (vertical)
        mobile: SingleChildScrollView(
          padding: ResponsiveHelper.responsivePadding(context),
          child: Column(
            children: [
              _buildStatsCard(context),
              ResponsiveSpacing.medium(),
              _buildRecentActivityCard(context),
              ResponsiveSpacing.medium(),
              _buildQuickActionsCard(context),
            ],
          ),
        ),
        
        // Tablet: 2 columns
        tablet: Padding(
          padding: ResponsiveHelper.responsivePadding(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildStatsCard(context),
                    ResponsiveSpacing.medium(),
                    _buildRecentActivityCard(context),
                  ],
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context)),
              Expanded(
                flex: 1,
                child: _buildQuickActionsCard(context),
              ),
            ],
          ),
        ),
        
        // Desktop: 3 columns
        desktop: Padding(
          padding: ResponsiveHelper.responsivePadding(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildStatsCard(context)),
              SizedBox(width: ResponsiveHelper.spacing(context)),
              Expanded(child: _buildRecentActivityCard(context)),
              SizedBox(width: ResponsiveHelper.spacing(context)),
              Expanded(child: _buildQuickActionsCard(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveText(
            'Statistics',
            type: ResponsiveTextType.title,
          ),
          ResponsiveSpacing.medium(),
          ResponsiveText(
            '24 Active Requests',
            type: ResponsiveTextType.body,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context) {
    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveText(
            'Recent Activity',
            type: ResponsiveTextType.title,
          ),
          ResponsiveSpacing.medium(),
          ResponsiveText(
            'Last request: 5 minutes ago',
            type: ResponsiveTextType.body,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context) {
    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveText(
            'Quick Actions',
            type: ResponsiveTextType.title,
          ),
          ResponsiveSpacing.medium(),
          ResponsiveButton(
            text: 'New Request',
            onPressed: () {},
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
