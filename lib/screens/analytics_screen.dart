// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sugar_plus/utils/colors.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text('Please login to view analytics'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('diabetes_tests')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final tests = snapshot.data!.docs;
                return _buildAnalytics(tests);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No data to analyze',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete tests to see analytics',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalytics(List<QueryDocumentSnapshot> tests) {
    // Prepare data
    final chartData = <ChartData>[];
    final refractiveData = <ChartData>[];
    double totalSugar = 0;
    double totalRefractive = 0;
    int normalCount = 0;
    int highCount = 0;

    for (var test in tests) {
      final data = test.data() as Map<String, dynamic>;
      final sugarLevel = (data['sugarLevel'] as num?)?.toDouble() ?? 0.0;
      final refractiveIndex = (data['refractiveIndex'] as num?)?.toDouble() ?? 0.0;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

      chartData.add(ChartData(timestamp, sugarLevel));
      refractiveData.add(ChartData(timestamp, refractiveIndex));
      
      totalSugar += sugarLevel;
      totalRefractive += refractiveIndex;
      
      if (sugarLevel < 140) {
        normalCount++;
      } else {
        highCount++;
      }
    }

    final avgSugar = totalSugar / tests.length;
    final avgRefractive = totalRefractive / tests.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'EXPERIMENTAL DATA - Not validated for medical use',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Average Sugar',
                  '${avgSugar.toStringAsFixed(1)} mg/dL',
                  Icons.water_drop,
                  avgSugar < 140 ? AppColors.success : Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Tests',
                  '${tests.length}',
                  Icons.analytics,
                  AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Normal',
                  '$normalCount',
                  Icons.check_circle,
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'High',
                  '$highCount',
                  Icons.warning,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sugar Level Graph
          const Text(
            'Sugar Level Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SfCartesianChart(
              primaryXAxis: DateTimeAxis(
                dateFormat: DateFormat('MM/dd'),
                majorGridLines: const MajorGridLines(width: 0),
              ),
              primaryYAxis: NumericAxis(
                title: AxisTitle(text: 'mg/dL'),
                plotBands: <PlotBand>[
                  PlotBand(
                    start: 0,
                    end: 140,
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderColor: AppColors.success,
                    borderWidth: 1,
                  ),
                ],
              ),
              series: <LineSeries<ChartData, DateTime>>[
                LineSeries<ChartData, DateTime>(
                  dataSource: chartData,
                  xValueMapper: (ChartData data, _) => data.date,
                  yValueMapper: (ChartData data, _) => data.value,
                  color: AppColors.primary,
                  width: 3,
                  markerSettings: const MarkerSettings(
                    isVisible: true,
                    shape: DataMarkerType.circle,
                  ),
                ),
              ],
              tooltipBehavior: TooltipBehavior(enable: true),
            ),
          ),
          const SizedBox(height: 24),

          // Refractive Index Graph
          const Text(
            'Refractive Index Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SfCartesianChart(
              primaryXAxis: DateTimeAxis(
                dateFormat: DateFormat('MM/dd'),
                majorGridLines: const MajorGridLines(width: 0),
              ),
              primaryYAxis: NumericAxis(
                title: AxisTitle(text: 'Refractive Index'),
              ),
              series: <LineSeries<ChartData, DateTime>>[
                LineSeries<ChartData, DateTime>(
                  dataSource: refractiveData,
                  xValueMapper: (ChartData data, _) => data.date,
                  yValueMapper: (ChartData data, _) => data.value,
                  color: AppColors.info,
                  width: 3,
                  markerSettings: const MarkerSettings(
                    isVisible: true,
                    shape: DataMarkerType.diamond,
                  ),
                ),
              ],
              tooltipBehavior: TooltipBehavior(enable: true),
            ),
          ),
          const SizedBox(height: 24),

          // Correlation Graph
          const Text(
            'Sugar vs Refractive Index',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SfCartesianChart(
              primaryXAxis: NumericAxis(
                title: AxisTitle(text: 'Refractive Index'),
              ),
              primaryYAxis: NumericAxis(
                title: AxisTitle(text: 'Sugar Level (mg/dL)'),
              ),
              series: <ScatterSeries<CorrelationData, double>>[
                ScatterSeries<CorrelationData, double>(
                  dataSource: _getCorrelationData(tests),
                  xValueMapper: (CorrelationData data, _) => data.refractive,
                  yValueMapper: (CorrelationData data, _) => data.sugar,
                  color: AppColors.primary,
                  markerSettings: const MarkerSettings(
                    height: 10,
                    width: 10,
                  ),
                ),
              ],
              tooltipBehavior: TooltipBehavior(enable: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<CorrelationData> _getCorrelationData(List<QueryDocumentSnapshot> tests) {
    return tests.map((test) {
      final data = test.data() as Map<String, dynamic>;
      return CorrelationData(
        (data['refractiveIndex'] as num?)?.toDouble() ?? 0.0,
        (data['sugarLevel'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }
}

class ChartData {
  final DateTime date;
  final double value;

  ChartData(this.date, this.value);
}

class CorrelationData {
  final double refractive;
  final double sugar;

  CorrelationData(this.refractive, this.sugar);
}