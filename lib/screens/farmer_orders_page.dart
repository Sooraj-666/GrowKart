import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/delivery_address.dart';
import 'dart:developer' as dev;

class FarmerOrdersPage extends StatefulWidget {
  const FarmerOrdersPage({super.key});

  @override
  FarmerOrdersPageState createState() => FarmerOrdersPageState();
}

class FarmerOrdersPageState extends State<FarmerOrdersPage> {
  String _selectedFilter = 'all';
  final TextEditingController _deliveryDateController = TextEditingController();

  @override
  void dispose() {
    _deliveryDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            "Please log in as a farmer to view orders.",
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    final String farmerId = currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Orders Received"),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // Order Filter
          Padding(
            padding: const EdgeInsets.all(8.0),
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
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Pending'),
                    selected: _selectedFilter == 'pending',
                    onSelected: (bool selected) {
                      setState(() => _selectedFilter = 'pending');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Accepted'),
                    selected: _selectedFilter == 'accepted',
                    onSelected: (bool selected) {
                      setState(() => _selectedFilter = 'accepted');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Delivered'),
                    selected: _selectedFilter == 'delivered',
                    onSelected: (bool selected) {
                      setState(() => _selectedFilter = 'delivered');
                    },
                  ),
                ],
              ),
            ),
          ),
          // Orders List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredOrdersStream(farmerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No orders received yet.",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Orders will appear here when customers place them.",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final orders = snapshot.data!.docs;
                dev.log("Found ${orders.length} orders for farmer");

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final data = order.data() as Map<String, dynamic>;
                    final orderId = order.id;
                    final String userId = data['userId'] ?? '';
                    final orderStatus = data['status'] ?? 'pending';
                    final deliveryAddress = DeliveryAddress.fromMap(
                        data['deliveryAddress'] ?? {});
                    final quantity = data['quantity'] ?? 1;
                    final totalPrice = data['totalPrice'] ?? 0.0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data["imageUrl"] != null &&
                                (data["imageUrl"] as String).isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  data["imageUrl"],
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data["productName"] ?? "Unknown Product",
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        "Total: ₹${totalPrice.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.green,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        "Quantity: $quantity",
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(orderStatus).withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    orderStatus.toUpperCase(),
                                    style: TextStyle(
                                      color: _getStatusColor(orderStatus),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Display user name and phone number
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                              builder: (context, userSnapshot) {
                                if (userSnapshot.connectionState == ConnectionState.waiting) {
                                  return const SizedBox();
                                }
                                if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
                                  return const SizedBox();
                                }
                                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                final userName = userData['name'] ?? '';
                                final phone = userData['phone'] ?? '';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Name: $userName',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Phone: $phone',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                );
                              },
                            ),
                            Text(
                              "Delivery Address:",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700]),
                            ),
                            Text(
                              "${deliveryAddress.street}\n${deliveryAddress.city}, ${deliveryAddress.state}\n${deliveryAddress.pincode}",
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            if (data["timestamp"] != null)
                              Text(
                                "Order Date: ${_formatDate((data["timestamp"] as Timestamp).toDate())}",
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                              ),
                            const SizedBox(height: 10),

                            // ACTION BUTTONS FOR FARMERS
                            if (orderStatus == 'pending') ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showAcceptDialog(
                                          farmerId, userId, orderId),
                                      icon: const Icon(Icons.check),
                                      label: const Text("Accept"),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _updateOrderStatus(
                                          farmerId, userId, orderId, 'rejected'),
                                      icon: const Icon(Icons.close),
                                      label: const Text("Reject"),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (orderStatus == 'accepted') ...[
                              if (data['estimatedDeliveryDate'] != null)
                                Text(
                                  "Estimated Delivery: ${_formatDate((data['estimatedDeliveryDate'] as Timestamp).toDate())}",
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue),
                                ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () => _updateOrderStatus(
                                    farmerId, userId, orderId, 'delivered'),
                                icon: const Icon(Icons.local_shipping),
                                label: const Text("Mark as Delivered"),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange),
                              ),
                            ],
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

  Stream<QuerySnapshot> _getFilteredOrdersStream(String farmerId) {
    dev.log("Getting orders for farmer ID: $farmerId");
    
    var query = FirebaseFirestore.instance
        .collection("farmers")
        .doc(farmerId)
        .collection("orders")
        .orderBy("timestamp", descending: true);

    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    return query.snapshots();
  }

  Future<void> _showAcceptDialog(
      String farmerId, String userId, String orderId) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (selectedDate != null && mounted) {
      TimeOfDay? selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (selectedTime != null && mounted) {
        DateTime estimatedDelivery = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        await _updateOrderStatus(farmerId, userId, orderId, 'accepted',
            estimatedDeliveryDate: estimatedDelivery);
      }
    }
  }

  Future<void> _updateOrderStatus(
    String farmerId,
    String userId,
    String orderId,
    String status, {
    DateTime? estimatedDeliveryDate,
  }) async {
    try {
      Map<String, dynamic> updateData = {"status": status};
      if (estimatedDeliveryDate != null) {
        updateData["estimatedDeliveryDate"] = Timestamp.fromDate(estimatedDeliveryDate);
      }

      // Update farmer's order copy
      await FirebaseFirestore.instance
          .collection("farmers")
          .doc(farmerId)
          .collection("orders")
          .doc(orderId)
          .update(updateData);
          
      // Update user's order copy
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .collection("orders")
          .doc(orderId)
          .update(updateData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'accepted'
              ? "Order accepted with delivery date: ${_formatDate(estimatedDeliveryDate!)}"
              : "Order status updated to: $status"),
        ),
      );

      dev.log("Order status updated successfully to $status.");
    } catch (e) {
      dev.log("Error updating order status: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating order status: $e")),
      );
    }
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
}
