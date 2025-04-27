// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/delivery_address.dart';
import 'dart:developer' as dev;

class UserOrdersPage extends StatefulWidget {
  const UserOrdersPage({super.key});

  @override
  UserOrdersPageState createState() => UserOrdersPageState();
}

class UserOrdersPageState extends State<UserOrdersPage> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view your orders.")),
      );
    }
    final String userId = currentUser.uid;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "My Orders",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Order Filter
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedFilter == 'all',
                    onSelected: (bool selected) {
                      setState(() => _selectedFilter = 'all');
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.green[100],
                    checkmarkColor: Colors.green[700],
                    labelStyle: TextStyle(
                      color: _selectedFilter == 'all'
                          ? Colors.green[700]
                          : Colors.black87,
                      fontWeight: _selectedFilter == 'all'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Pending'),
                    selected: _selectedFilter == 'pending',
                    onSelected: (bool selected) {
                      setState(() => _selectedFilter = 'pending');
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.orange[100],
                    checkmarkColor: Colors.orange[700],
                    labelStyle: TextStyle(
                      color: _selectedFilter == 'pending'
                          ? Colors.orange[700]
                          : Colors.black87,
                      fontWeight: _selectedFilter == 'pending'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Accepted'),
                    selected: _selectedFilter == 'accepted',
                    onSelected: (bool selected) {
                      setState(() => _selectedFilter = 'accepted');
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.green[100],
                    checkmarkColor: Colors.green[700],
                    labelStyle: TextStyle(
                      color: _selectedFilter == 'accepted'
                          ? Colors.green[700]
                          : Colors.black87,
                      fontWeight: _selectedFilter == 'accepted'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Delivered'),
                    selected: _selectedFilter == 'delivered',
                    onSelected: (bool selected) {
                      setState(() => _selectedFilter = 'delivered');
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.blue[100],
                    checkmarkColor: Colors.blue[700],
                    labelStyle: TextStyle(
                      color: _selectedFilter == 'delivered'
                          ? Colors.blue[700]
                          : Colors.black87,
                      fontWeight: _selectedFilter == 'delivered'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Orders List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredOrdersStream(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No orders found",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Your orders will appear here",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                dev.log("Found ${snapshot.data!.docs.length} orders for user");
                final orders = snapshot.data!.docs;
                
                return ListView.builder(
                  itemCount: orders.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final data = order.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'pending';
                    final deliveryAddress = DeliveryAddress.fromMap(
                        data['deliveryAddress'] ?? {});
                    final quantity = data['quantity'] ?? 1;
                    final totalPrice = data['totalPrice'] ?? 0.0;
                    
                    String statusMessage = "Pending Approval";
                    if (status == 'accepted') {
                      final estimatedDelivery = data['estimatedDeliveryDate'] as Timestamp?;
                      if (estimatedDelivery != null) {
                        statusMessage = "Accepted - Delivery on ${_formatDate(estimatedDelivery.toDate())}";
                      } else {
                        statusMessage = "Accepted - Delivery pending";
                      }
                    } else if (status == 'delivered') {
                      statusMessage = "Delivered";
                    } else if (status == 'rejected') {
                      statusMessage = "Rejected by Farmer";
                    } else if (status == 'cancelled') {
                      statusMessage = "Cancelled by You";
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (data["imageUrl"] != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      data["imageUrl"],
                                      height: 80,
                                      width: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                            height: 80,
                                            width: 80,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.broken_image),
                                          ),
                                    ),
                                  ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data["productName"] ?? "Unknown Product",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "₹${data["price"]} × $quantity = ₹$totalPrice",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (data['timestamp'] != null)
                                        Text(
                                          "Ordered on: ${_formatDate((data['timestamp'] as Timestamp).toDate())}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text(
                              "Delivery Address",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${deliveryAddress.street}\n${deliveryAddress.landmark}\n${deliveryAddress.city}, ${deliveryAddress.state} ${deliveryAddress.pincode}",
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withAlpha((0.1 * 255).round()),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                statusMessage,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ),
                            if (status == 'pending')
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _cancelOrder(order.id, data["farmerId"] ?? ""),
                                      icon: const Icon(Icons.cancel_outlined),
                                      label: const Text("Cancel Order"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (status == 'delivered')
                              if (data['rating'] == null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _showFeedbackDialog(order.id, data['farmerId'] ?? ''),
                                        icon: const Icon(Icons.rate_review),
                                        label: const Text("Give Feedback"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < (data['rating'] ?? 0) ? Icons.star : Icons.star_border,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['feedback'] ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            // Fetch and display farmer details for each user order
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('farmers')
                                  .doc(data['farmerId'])
                                  .get(),
                              builder: (context, farmerSnapshot) {
                                if (farmerSnapshot.connectionState == ConnectionState.waiting) {
                                  return const SizedBox();
                                }
                                if (farmerSnapshot.hasError || !farmerSnapshot.hasData || !farmerSnapshot.data!.exists) {
                                  return const SizedBox();
                                }
                                final farmerData = farmerSnapshot.data!.data() as Map<String, dynamic>;
                                final farmerName = farmerData['name'] ?? '';
                                final farmName = farmerData['farmName'] ?? '';
                                final phone = farmerData['phone'] ?? '';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Farmer: $farmerName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    Text('Farm: $farmName', style: const TextStyle(fontSize: 14)),
                                    Text('Phone: $phone', style: const TextStyle(fontSize: 14)),
                                    const SizedBox(height: 8),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            if (data['timestamp'] != null)
                              Text(
                                "Ordered on: ${_formatDate((data['timestamp'] as Timestamp).toDate())}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredOrdersStream(String userId) {
    dev.log("Getting orders for user ID: $userId");
    
    var query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('orders')
        .orderBy('timestamp', descending: true);

    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    return query.snapshots();
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'delivered':
        return Colors.blue;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Future<void> _cancelOrder(String orderId, String farmerId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Order"),
        content: const Text("Are you sure you want to cancel this order?"),
        actions: [
          TextButton(
            child: const Text("No"),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Yes, Cancel"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        dev.log("Cancelling order: $orderId");
        
        // Update user's order copy
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('orders')
            .doc(orderId)
            .update({'status': 'cancelled'});
            
        // Update farmer's order copy if farmerId is available
        if (farmerId.isNotEmpty) {
          dev.log("Updating farmer's order copy for farmer: $farmerId");
          await FirebaseFirestore.instance
              .collection('farmers')
              .doc(farmerId)
              .collection('orders')
              .doc(orderId)
              .update({'status': 'cancelled'});
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order cancelled successfully.")),
        );
      } catch (e) {
        dev.log("Error cancelling order: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error cancelling order: $e")),
        );
      }
    }
  }

  Future<void> _showFeedbackDialog(String orderId, String farmerId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    int selectedRating = 5;
    final TextEditingController feedbackController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Rate Your Experience"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      icon: Icon(
                        index < selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                      ),
                      onPressed: () => setState(() => selectedRating = index + 1),
                    ),
                  ),
                ),
                TextField(
                  controller: feedbackController,
                  decoration: const InputDecoration(
                    labelText: 'Feedback',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('orders')
                        .doc(orderId)
                        .update({
                      'rating': selectedRating,
                      'feedback': feedbackController.text.trim(),
                      'feedbackAt': FieldValue.serverTimestamp(),
                    });
                    await FirebaseFirestore.instance
                        .collection('farmers')
                        .doc(farmerId)
                        .collection('orders')
                        .doc(orderId)
                        .update({
                      'rating': selectedRating,
                      'feedback': feedbackController.text.trim(),
                      'feedbackAt': FieldValue.serverTimestamp(),
                    });
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(orderId)
                        .update({
                      'rating': selectedRating,
                      'feedback': feedbackController.text.trim(),
                      'feedbackAt': FieldValue.serverTimestamp(),
                    });
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Feedback submitted")),
                    );
                    setState(() {});
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error submitting feedback: $e")),
                    );
                  }
                },
                child: const Text("Submit"),
              ),
            ],
          );
        },
      ),
    );
  }
}
