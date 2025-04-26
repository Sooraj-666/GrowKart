import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as dev;

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  CartPageState createState() => CartPageState();
}

class CartPageState extends State<CartPage> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  bool _isPlacingOrder = false;

  static const String usersCollection = "users";
  static const String farmersCollection = "farmers";
  static const String cartCollection = "cart";
  static const String ordersCollection = "orders";

  @override
  Widget build(BuildContext context) {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Your Cart",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        elevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              onPressed: null,
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(usersCollection)
            .doc(userId)
            .collection(cartCollection)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            dev.log("Error fetching cart data: ${snapshot.error}");
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Your cart is empty",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  isThreeLine: true,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      data["imageUrl"] ?? "",
                      height: 50,
                      width: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                  title: Text(data["name"] ?? "Unknown Product",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Price: ₹${data["price"] ?? 0}",
                          style: const TextStyle(color: Colors.green)),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection(farmersCollection)
                            .doc(data['farmerId'])
                            .get(),
                        builder: (context, farmerSnapshot) {
                          if (farmerSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox();
                          }
                          if (farmerSnapshot.hasError ||
                              !farmerSnapshot.hasData ||
                              !farmerSnapshot.data!.exists) {
                            return const SizedBox();
                          }
                          final farmerData =
                              farmerSnapshot.data!.data() as Map<String, dynamic>;
                          final farmerName = farmerData['name'] ?? '';
                          final farmName = farmerData['farmName'] ?? '';
                          final phone = farmerData['phone'] ?? '';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Farmer: $farmerName',
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.bold)),
                              Text('Farm: $farmName',
                                  style: const TextStyle(fontSize: 14)),
                              Text('Phone: $phone',
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 4),
                            ],
                          );
                        },
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              int currentQty = data["quantity"] ?? 1;
                              _updateCartItemQuantity(userId, doc.id, currentQty - 1);
                            },
                          ),
                          Text("${data["quantity"] ?? 1}",
                              style: const TextStyle(fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              int currentQty = data["quantity"] ?? 1;
                              _updateCartItemQuantity(userId, doc.id, currentQty + 1);
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                              "Total: ₹${data["totalPrice"] ?? (data["price"] ?? 0)}",
                              style: const TextStyle(color: Colors.green)),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(userId, doc.id),
                      ),
                      ElevatedButton(
                        onPressed: () => _showAddressDialog(
                            context, data, doc.id),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue),
                        child: const Text("Buy Now",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // Confirm deletion dialog
  void _confirmDelete(String userId, String cartDocId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Item"),
        content: const Text(
            "Are you sure you want to remove this item from your cart?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCartItem(userId, cartDocId);
            },
            child: const Text("Remove"),
          ),
        ],
      ),
    );
  }

  // Show address dialog for order placement
  void _showAddressDialog(BuildContext context, Map<String, dynamic> productData,
      String cartDocId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Address"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: "Address",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _landmarkController,
                  decoration: const InputDecoration(
                    labelText: "Landmark",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _placeOrder(productData, cartDocId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Place Order"),
            ),
          ],
        );
      },
    );
  }

  // Place order
  Future<void> _placeOrder(Map<String, dynamic> productData,
      String cartDocId) async {
    if (_isPlacingOrder) return;

    setState(() => _isPlacingOrder = true);
    String userId = FirebaseAuth.instance.currentUser!.uid;
    String farmerId = productData["farmerId"] ?? "";

    try {
      if (_addressController.text.trim().isEmpty ||
          _landmarkController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter address and landmark.")),
        );
        return;
      }

      if (farmerId.isEmpty) throw Exception("Farmer ID is missing");

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) throw Exception("User details not found");

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // Prepare order data
      Map<String, dynamic> orderData = {
        "productName": productData["name"] ?? "Unknown Product",
        "price": productData["price"] ?? 0,
        "imageUrl": productData["imageUrl"] ?? "",
        "deliveryAddress": {
          "street": _addressController.text.trim(),
          "landmark": _landmarkController.text.trim(),
          "city": userData["city"] ?? "",
          "state": userData["state"] ?? "",
          "pincode": userData["pincode"] ?? "",
        },
        "timestamp": FieldValue.serverTimestamp(),
        "status": "pending",
        "quantity": productData["quantity"] ?? 1,
        "totalPrice": productData["totalPrice"] ?? (productData["price"] ?? 0),
      };

      // User order
      DocumentReference orderRef = await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(userId)
          .collection(ordersCollection)
          .add({
        ...orderData,
        "farmerId": farmerId,
      });

      // Farmer order
      try {
        dev.log("Creating farmer order for farmerId: $farmerId");
        await FirebaseFirestore.instance
            .collection(farmersCollection)
            .doc(farmerId)
            .collection(ordersCollection)
            .doc(orderRef.id) // Ensure matching order ID
            .set({
          ...orderData,
          "userId": userId,
          "userName": userData["name"] ?? "Unknown User",
          "userPhone": userData["phone"] ?? "N/A",
          "orderId": orderRef.id, // Add the order ID explicitly
        });
        dev.log("Successfully created farmer order with ID: ${orderRef.id}");
      } catch (e) {
        dev.log("Error creating farmer order: $e");
      }

      // Remove cart item
      await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(userId)
          .collection(cartCollection)
          .doc(cartDocId)
          .delete();

      _addressController.clear();
      _landmarkController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order placed successfully!")),
        );
      }
    } catch (e) {
      dev.log("Error placing order: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to place order: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  // Delete cart item
  Future<void> _deleteCartItem(String userId, String cartDocId) async {
    try {
      await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(userId)
          .collection(cartCollection)
          .doc(cartDocId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Item removed from cart")),
        );
      }
    } catch (e) {
      dev.log("Error deleting cart item: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete item: $e")),
        );
      }
    }
  }

  // Update cart item quantity and total price
  Future<void> _updateCartItemQuantity(String userId, String cartDocId, int newQuantity) async {
    if (newQuantity < 1) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(userId)
          .collection(cartCollection)
          .doc(cartDocId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        final double price = (data["price"] as num).toDouble();
        await docRef.update({
          "quantity": newQuantity,
          "totalPrice": price * newQuantity,
        });
      }
    } catch (e) {
      dev.log("Error updating quantity: $e");
    }
  }
}
