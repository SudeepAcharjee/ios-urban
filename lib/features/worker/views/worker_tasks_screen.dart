import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/worker_provider.dart';
import 'worker_task_detail_screen.dart';
import 'worker_disabled_overlay.dart';


class WorkerTasksScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const WorkerTasksScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<WorkerTasksScreen> createState() => _WorkerTasksScreenState();
}

class _WorkerTasksScreenState extends ConsumerState<WorkerTasksScreen> {
  String _selectedTab = 'All';
  static const primaryColor = Color(0xFF2029C5);
  final List<String> _tabs = ['All', 'Active', 'Completed', 'Cancelled'];

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(workerAllTasksProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 16),
          ),
        ),
        title: const Text('My Tasks',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ) : null,
      body: SafeArea(
        top: false,
        bottom: widget.showAppBar,
        child: Column(
          children: [
            // 🏷️ Dynamic Tab Chips (Styled like CategoriesScreen)
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(vertical: 15),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final tabName = _tabs[index];
                  final isSelected = _selectedTab == tabName;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedTab = tabName);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.grey.shade100,
                            width: 1.5,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ] : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            tabName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF4B5563),
                              fontWeight: isSelected ? FontWeight.bold : const Color(0xFF4B5563) == Colors.white ? FontWeight.bold : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            Expanded(
              child: tasksAsync.when(
                data: (tasks) {
                  final filteredTasks = _filterTasks(tasks, _selectedTab);
                  
                  if (filteredTasks.isEmpty) {
                    return _buildEmptyState(_selectedTab);
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 5, bottom: 30),
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      return _buildTaskCard(context, filteredTasks[index]);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: primaryColor)),
                error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    ),
    const PendingCashPaymentOverlay(),
  ]);
}

  List<Map<String, dynamic>> _filterTasks(List<Map<String, dynamic>> tasks, String tabName) {
    switch (tabName) {
      case 'Active': // Active / In Progress
        return tasks.where((t) => 
          ['Assigned', 'Confirmed', 'In Progress', 'Pending Verification'].contains(t['status'])
        ).toList();
      case 'Completed': // Completed
        return tasks.where((t) => t['status'] == 'Completed').toList();
      case 'Cancelled': // Cancelled
        return tasks.where((t) => t['status'] == 'Cancelled').toList();
      default: // All
        return tasks;
    }
  }

  Widget _buildEmptyState(String tabName) {
    String title = 'No Tasks Found';
    String subTitle = 'You don\'t have any tasks in this category.';
    
    if (tabName == 'Active') {
      title = 'No Active Tasks';
      subTitle = 'You have no tasks currently in progress.';
    } else if (tabName == 'Completed') {
      title = 'No Completed Tasks';
      subTitle = 'You haven\'t completed any tasks yet.';
    } else if (tabName == 'Cancelled') {
      title = 'No Cancelled Tasks';
      subTitle = 'Clean record! No cancelled tasks found.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_outlined, size: 80, color: primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Text(
            subTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Map<String, dynamic> task) {
    final title = task['title'] ?? 'Service';
    final price = '₹${task['totalPrice'] ?? '0'}';
    final time = task['time'] ?? 'Time not specified';
    final location = task['address'] ?? 'Location not specified';
    final image = task['imagePath'] ?? task['image'] ?? 'images/car_wash_splash.png';
    final status = task['status'] ?? 'Assigned';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkerTaskDetailScreen(taskData: task),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.grey.shade50),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'task_image_tasks_${task['id']}',
                      child: Container(
                        width: 85,
                        height: 85,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          image: DecorationImage(
                            image: image.startsWith('http') 
                                ? NetworkImage(image) as ImageProvider
                                : AssetImage(image),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Text(
                                price,
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                              const SizedBox(width: 5),
                              Text(
                                time,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'In Progress':
        return Colors.blue;
      case 'Pending Verification':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      case 'Confirmed':
        return Colors.indigo;
      default:
        return primaryColor;
    }
  }
}
