import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FarmerEarningsPage extends StatefulWidget {
  const FarmerEarningsPage({super.key});

  @override
  FarmerEarningsPageState createState() => FarmerEarningsPageState();
}

class FarmerEarningsPageState extends State<FarmerEarningsPage> {
  num _totalEarnings = 0;

  @override
  void initState() {
    super.initState();
    _calculateTotalEarnings();
  }

  void _calculateTotalEarnings() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final String farmerId = currentUser.uid;

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('farmers')
          .doc(farmerId)
          .collection('orders')
          .where('status', isEqualTo: 'delivered') // Filter delivered orders
          .get();

      num earnings = 0;
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        earnings += (data['price'] ?? 0) * (data['quantity'] ?? 1); // Calculate total price
      }

      if (mounted) {
        setState(() {
          _totalEarnings = earnings;
        });
      }
    } catch (e) {
      debugPrint("Error calculating earnings: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view your earnings.")),
      );
    }

    final String farmerId = currentUser.uid;

    return Scaffold(
      // Gradient AppBar
      appBar: AppBar(
        title: const Text('Earnings'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B5E20), Color(0xFF66BB6A)],
            ),
          ),
        ),
      ),
      body: Container(
        color: Colors.grey[100],
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Earnings Card with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF66BB6A), Color(0xFF81C784)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Earnings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '₹$_totalEarnings',
                    style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Delivered Orders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('farmers')
                    .doc(farmerId)
                    .collection('orders')
                    .where('status', isEqualTo: 'delivered') // Filter for delivered orders
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No delivered orders found."));
                  }

                  final orders = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final data = order.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: data['imageUrl'] != null ? NetworkImage(data['imageUrl']) : null,
                            child: data['imageUrl'] == null ? const Icon(Icons.image, size: 30, color: Colors.grey) : null,
                          ),
                          title: Text(
                            data['productName'] ?? "Unnamed Product",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "₹${data['price'] ?? 'N/A'} x ${data['quantity'] ?? 1}",
                            style: const TextStyle(color: Colors.green),
                          ),
                          trailing: Text(
                            '₹${(data['price'] ?? 0) * (data['quantity'] ?? 1)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
      ),
    );
  }
}
