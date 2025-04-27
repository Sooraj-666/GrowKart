import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _formKey = GlobalKey<FormState>();

  String _role = "User";
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _farmLocationController = TextEditingController();
  final TextEditingController _cropTypeController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  File? _certificateFile;
  String? _certificateFileName;
  bool _isLoading = false;

  /// Picks a certificate (PDF only)
  Future<void> _pickCertificate() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
      setState(() {
        _certificateFile = File(result.files.single.path!);
        _certificateFileName = result.files.single.name;
      });
    }
  }

  /// Uploads the certificate to Firebase Storage and returns the URL
  Future<String?> _uploadCertificate(String uid) async {
    if (_certificateFile == null) return null;
    try {
      Reference ref = _storage.ref().child("certificates/$uid.pdf");
      UploadTask uploadTask = ref.putFile(_certificateFile!);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  /// Handles user signup
  void _signup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == "Farmer") {
      final username = _usernameController.text.trim();
      if (username.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a username")));
        return;
      }
      final snap = await _firestore.collection('farmers').where('username', isEqualTo: username).get();
      if (snap.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Username already taken")));
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        String? certificateUrl;
        if (_role == "Farmer") {
          certificateUrl = await _uploadCertificate(user.uid);
        }

        Map<String, dynamic> userData = {
          "name": _nameController.text.trim(),
          "email": _emailController.text.trim(),
          "place": _placeController.text.trim(),
          "phone": _phoneController.text.trim(),
          "role": _role,
          "uid": user.uid,
        };

        if (_role == "Farmer") {
          userData['username'] = _usernameController.text.trim();
          userData.addAll({
            "farm_name": _farmNameController.text.trim(),
            "farm_location": _farmLocationController.text.trim(),
            "crop_type": _cropTypeController.text.trim(),
            "certificate_url": certificateUrl,
            "status": "pending",
          });
          await _firestore.collection('farmers').doc(user.uid).set(userData);
        } else {
          await _firestore.collection('users').doc(user.uid).set(userData);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_role == "Farmer" ? "Signup successful! Awaiting admin approval." : "Signup successful!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(title: const Text("Signup"), backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Center(
                child: Image.asset(
                  'assets/images/growkart_logo.png',
                  height: 100,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 30),
              Card(
                elevation: 4,
                color: Colors.white.withOpacity(0.9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Role Selection (User or Farmer)
                        Row(
                          children: [
                            Expanded(child: RadioListTile(title: const Text("User"), value: "User", groupValue: _role, onChanged: (value) => setState(() => _role = value.toString()))),
                            Expanded(child: RadioListTile(title: const Text("Farmer"), value: "Farmer", groupValue: _role, onChanged: (value) => setState(() => _role = value.toString()))),
                          ],
                        ),

                        /// Common Fields
                        TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name"), validator: (value) => value!.isEmpty ? "Enter your name" : null),
                        TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: "Email"), keyboardType: TextInputType.emailAddress, validator: (value) => value!.isEmpty ? "Enter your email" : null),
                        TextFormField(controller: _placeController, decoration: const InputDecoration(labelText: "Place"), validator: (value) => value!.isEmpty ? "Enter your place" : null),
                        TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: "Phone Number"), keyboardType: TextInputType.phone, validator: (value) => value!.isEmpty || value.length != 10 ? "Enter a valid phone number" : null),
                        TextFormField(controller: _passwordController, decoration: const InputDecoration(labelText: "Password"), obscureText: true, validator: (value) => value!.length < 6 ? "Password must be at least 6 characters" : null),
                        TextFormField(controller: _confirmPasswordController, decoration: const InputDecoration(labelText: "Confirm Password"), obscureText: true, validator: (value) => value != _passwordController.text ? "Passwords do not match" : null),

                        /// Farmer-Specific Fields
                        if (_role == "Farmer") ...[
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(labelText: "Username"),
                            validator: (value) => value!.isEmpty ? "Enter a username" : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _farmNameController,
                            decoration: const InputDecoration(labelText: "Farm Name"),
                            validator: (value) => value!.isEmpty ? "Enter farm name" : null,
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(onPressed: _pickCertificate, child: const Text("Upload Certificate (PDF)")),
                          if (_certificateFileName != null) Text("Selected: $_certificateFileName", style: TextStyle(color: Colors.green)),
                        ],

                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _signup,
                          child: _isLoading ? const CircularProgressIndicator() : const Text("Signup"),
                        ),
                      ],
                    ),
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
