import 'package:flutter/material.dart';
import 'package:sugar_plus/services/auth_service.dart';
import 'package:sugar_plus/screens/login_screen.dart';
import 'package:sugar_plus/test/enhanced_camera_detection.dart';
import 'package:sugar_plus/algorithm/history_screen.dart';
import 'package:sugar_plus/algorithm/analytics_screen.dart';
import 'package:sugar_plus/utils/colors.dart';
import 'package:sugar_plus/utils/permissions_helper.dart';
import 'package:sugar_plus/widgets/stat_card.dart';
import 'package:sugar_plus/widgets/feature_card.dart';
import 'package:sugar_plus/widgets/activity_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final authService = AuthService();
  Map<String, dynamic>? userData;
  bool isLoading = true;
  int _currentIndex = 0;
  
  // Latest stats
  double? latestSugarLevel;
  String? lastScanTime;
  int totalTests = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStats();
  }

  Future<void> _loadUserData() async {
    final user = authService.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists && mounted) {
          setState(() {
            userData = doc.data();
            isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    } else {
      setState(() => isLoading = false);
    }
  }
  
  Future<void> _loadStats() async {
    final user = authService.currentUser;
    if (user == null) return;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('diabetes_tests')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty && mounted) {
        final latestTest = snapshot.docs.first.data();
        final timestamp = latestTest['timestamp'] as Timestamp?;
        
        setState(() {
          latestSugarLevel = (latestTest['sugarLevel'] as num?)?.toDouble();
          if (timestamp != null) {
            final now = DateTime.now();
            final testDate = timestamp.toDate();
            final difference = now.difference(testDate);
            
            if (difference.inDays > 0) {
              lastScanTime = '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
            } else if (difference.inHours > 0) {
              lastScanTime = '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
            } else {
              lastScanTime = 'Today';
            }
          }
        });
      }
      
      // Get total test count
      final countSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('diabetes_tests')
          .count()
          .get();
      
      if (mounted) {
        setState(() {
          totalTests = countSnapshot.count ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _openCamera() async {
    final hasPermission = await PermissionsHelper.requestCameraPermission(context);
    
    if (hasPermission && mounted) {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FixedDiabetesDetectionScreen()),
      );
      
      // Reload stats after returning from camera
      if (result != null || mounted) {
        _loadStats();
      }
    }
  }

  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true && mounted) {
      await authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }
  
  void _navigateToScreen(int index) {
    if (index == _currentIndex) return;
    
    setState(() => _currentIndex = index);
    
    Widget? screen;
    switch (index) {
      case 0:
        return; // Already on home
      case 1:
        screen = const HistoryScreen();
        break;
      case 2:
        screen = const AnalyticsScreen();
        break;
      case 3:
        _showProfileMenu();
        return;
    }
    
    if (screen != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen!),
      ).then((_) {
        setState(() => _currentIndex = 0);
        _loadStats(); // Reload stats when returning
      });
    }
  }
  
  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile editing coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Help coming soon')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _handleSignOut();
              },
            ),
          ],
        ),
      ),
    );
    
    // Reset to home after closing
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _currentIndex = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final user = authService.currentUser;
    final username = userData?['username'] ?? user?.displayName ?? 'User';

    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      toolbarHeight: 70,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: user?.photoURL != null
                ? NetworkImage(user!.photoURL!)
                : null,
            child: user?.photoURL == null
                ? const Icon(Icons.person, color: AppColors.primary, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications coming soon')),
            );
          },
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20),
                  SizedBox(width: 12),
                  Text('Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Settings'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: AppColors.error),
                  SizedBox(width: 12),
                  Text('Sign Out', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'logout') {
              _handleSignOut();
            }
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserData();
        await _loadStats();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsSection(),
            const SizedBox(height: 24),
            _buildFeaturesSection(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Latest Reading',
                value: latestSugarLevel != null 
                    ? '${latestSugarLevel!.toStringAsFixed(0)} mg/dL'
                    : 'No data',
                icon: Icons.water_drop,
                color: latestSugarLevel != null && latestSugarLevel! < 140
                    ? AppColors.success
                    : Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Last Scan',
                value: lastScanTime ?? 'Never',
                icon: Icons.remove_red_eye,
                color: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StatCard(
          title: 'Total Tests Completed',
          value: '$totalTests ${totalTests == 1 ? 'test' : 'tests'}',
          icon: Icons.analytics,
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: [
            FeatureCard(
              title: 'Eye Scan',
              icon: Icons.remove_red_eye,
              onTap: _openCamera,
            ),
            FeatureCard(
              title: 'History',
              icon: Icons.history,
              onTap: () => _navigateToScreen(1),
            ),
            FeatureCard(
              title: 'Analytics',
              icon: Icons.analytics,
              onTap: () => _navigateToScreen(2),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final user = authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToScreen(1),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('diabetes_tests')
              .orderBy('timestamp', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.analytics_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No recent activity',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _openCamera,
                        child: const Text('Start First Test'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: snapshot.data!.docs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final doc = entry.value;
                  final data = doc.data() as Map<String, dynamic>;
                  final sugarLevel = (data['sugarLevel'] as num?)?.toDouble() ?? 0;
                  final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                  
                  String timeAgo = 'Unknown';
                  if (timestamp != null) {
                    final difference = DateTime.now().difference(timestamp);
                    if (difference.inDays > 0) {
                      timeAgo = '${difference.inDays}d ago';
                    } else if (difference.inHours > 0) {
                      timeAgo = '${difference.inHours}h ago';
                    } else {
                      timeAgo = '${difference.inMinutes}m ago';
                    }
                  }
                  
                  return Column(
                    children: [
                      ActivityItem(
                        title: '${sugarLevel.toStringAsFixed(0)} mg/dL',
                        time: timeAgo,
                        icon: Icons.water_drop,
                        color: sugarLevel < 140 ? AppColors.success : Colors.orange,
                      ),
                      if (index < snapshot.data!.docs.length - 1)
                        Divider(height: 1, color: AppColors.grey.withValues(alpha: 0.3)),
                    ],
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFloatingButton() {
    return FloatingActionButton(
      onPressed: _openCamera,
      backgroundColor: AppColors.primary,
      elevation: 2,
      child: const Icon(Icons.camera_alt, color: Colors.white),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: AppColors.surface,
      elevation: 8,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Home', 0),
            _buildNavItem(Icons.history, 'History', 1),
            const SizedBox(width: 40),
            _buildNavItem(Icons.analytics, 'Analytics', 2),
            _buildNavItem(Icons.person, 'Profile', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _navigateToScreen(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}