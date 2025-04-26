import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductListingPage extends StatefulWidget {
  const ProductListingPage({super.key});

  @override
  ProductListingPageState createState() => ProductListingPageState();
}

class ProductListingPageState extends State<ProductListingPage> {
  String _selectedCategory = 'All';

  void _changeCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  Future<void> _addToCart(QueryDocumentSnapshot doc, Map<String, dynamic> farmerData) async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      String farmerId = doc["farmerId"] as String? ?? "unknown"; // use product's farmerId

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .collection("cart")
          .add({
        "name": doc["name"] ?? "Unknown Product",
        "price": doc["price"] ?? 0.0,
        "description": doc["description"] ?? "No Description",
        "imageUrl": doc["imageUrl"] ?? "",
        "farmerId": farmerId,
        "farmerName": farmerData["name"] ?? "Unknown Farmer",
        "farmerPhone": farmerData["phone"] ?? "N/A",
        "farmerPlace": farmerData["place"] ?? "Unknown Place",
        "timestamp": FieldValue.serverTimestamp(),
        "quantity": 1,
        "totalPrice": doc["price"] ?? 0.0,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product added to cart!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding product to cart: $e")),
      );
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getFarmerDetails(String farmerId) async {
    return await FirebaseFirestore.instance.collection("farmers").doc(farmerId).get();
  }

  @override
  Widget build(BuildContext context) {
    // Simplified query to avoid index requirements
    Query query = FirebaseFirestore.instance.collection("products");
    
    if (_selectedCategory != "All") {
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text("Available Products"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: CategoryButton(label: "All", isSelected: _selectedCategory == "All", onTap: () => _changeCategory('All')),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: CategoryButton(label: "Fruits", isSelected: _selectedCategory == "Fruits", onTap: () => _changeCategory('Fruits')),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: CategoryButton(label: "Vegetables", isSelected: _selectedCategory == "Vegetables", onTap: () => _changeCategory('Vegetables')),
                ),
                CategoryButton(label: "Dairy", isSelected: _selectedCategory == "Dairy", onTap: () => _changeCategory('Dairy')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No products available"));
                }

                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    Map<String, dynamic> productData = doc.data() as Map<String, dynamic>;
                    String farmerId = productData["farmerId"] ?? "";
                    
                    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: _getFarmerDetails(farmerId),
                      builder: (context, farmerSnapshot) {
                        if (farmerSnapshot.connectionState == ConnectionState.waiting) {
                          return Card(
                            margin: const EdgeInsets.all(10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: const SizedBox(
                              height: 100,
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                ),
                              ),
                            ),
                          );
                        }
                        if (farmerSnapshot.hasError) {
                          return const Center(child: Text("Failed to load farmer details"));
                        }
                        if (!farmerSnapshot.hasData || !farmerSnapshot.data!.exists) {
                          return const SizedBox(); // Skip if farmer details are unavailable
                        }

                        Map<String, dynamic> farmerData = farmerSnapshot.data!.data()!;
                        return Card(
                          margin: const EdgeInsets.all(10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    doc["imageUrl"] ?? "",
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(doc["name"] ?? "Unknown Product", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text("₹${doc["price"] ?? 0.0}", style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w500)),
                                Text(doc["description"] ?? "No Description Available", style: const TextStyle(fontSize: 14)),
                                const SizedBox(height: 10),
                                Text("Farmer: ${farmerData["name"] ?? "Unknown Farmer"}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                Text("Phone: ${farmerData["phone"] ?? "N/A"}", style: const TextStyle(fontSize: 14)),
                                Text("Place: ${farmerData["place"] ?? "Unknown"}", style: const TextStyle(fontSize: 14)),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: () => _addToCart(doc, farmerData),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    child: const Text("Add to Cart", style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const CategoryButton({required this.label, required this.onTap, required this.isSelected, super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.green[700] : Colors.green[100],
        foregroundColor: isSelected ? Colors.white : Colors.green[900],
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        elevation: isSelected ? 3 : 1,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}
