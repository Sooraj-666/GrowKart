import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FarmerProfileScreen extends StatefulWidget {
  const FarmerProfileScreen({super.key});

  @override
  FarmerProfileScreenState createState() => FarmerProfileScreenState();
}

class FarmerProfileScreenState extends State<FarmerProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController farmNameController = TextEditingController();

  File? _profileImage;
  String? _profileImageUrl;

  bool isLoading = true;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadFarmerData();
  }

  Future<void> _loadFarmerData() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot farmerDoc =
          await _firestore.collection('farmers').doc(user.uid).get();
      if (farmerDoc.exists && mounted) {
        setState(() {
          nameController.text = farmerDoc['name'] ?? '';
          phoneController.text = farmerDoc['phone'] ?? '';
          locationController.text = farmerDoc['location'] ?? '';
          farmNameController.text = farmerDoc['farmName'] ?? '';
          _profileImageUrl = farmerDoc['profileImageUrl'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error loading farmer data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error loading profile. Please try again.")),
        );
      }
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateFarmerData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isUpdating = true;
    });

    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      // Upload profile image if selected
      if (_profileImage != null) {
        final ref = _storage.ref().child('profile_images/${user.uid}.jpg');
        await ref.putFile(_profileImage!);
        _profileImageUrl = await ref.getDownloadURL();
      }

      await _firestore.collection('farmers').doc(user.uid).set({
        'name': nameController.text,
        'phone': phoneController.text,
        'location': locationController.text,
        'farmName': farmNameController.text,
        'profileImageUrl': _profileImageUrl,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!")),
        );
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update profile. Try again!")),
        );
      }
    }
    if (mounted) {
      setState(() {
        isUpdating = false;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  void _logout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        // Navigate to login screen and clear all previous routes
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      [TextInputType type = TextInputType.text, String? Function(String?)? validator]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        validator: validator ?? (value) => value!.isEmpty ? "This field cannot be empty" : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.lightBlue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.lightBlue),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                  ? NetworkImage(_profileImageUrl!)
                                  : null) as ImageProvider?,
                          backgroundColor: Colors.grey[200],
                          child: _profileImage == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                              ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildTextField(nameController, 'Name', Icons.person),
                            _buildTextField(phoneController, 'Phone', Icons.phone, TextInputType.phone, (value) {
                              if (value == null || value.isEmpty) return 'Phone is required';
                              if (value.length != 10) return 'Enter valid 10-digit phone';
                              return null;
                            }),
                            _buildTextField(locationController, 'Location', Icons.location_on),
                            _buildTextField(farmNameController, 'Farm Name', Icons.agriculture),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isUpdating ? null : _updateFarmerData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B5E20),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: isUpdating
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text('Update Profile', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
