import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ClientSignupStep2Personal extends StatefulWidget {
  final Function(String fullName, String username, String idNumber, String idImagePath)
      onComplete;
  final VoidCallback onBack;

  const ClientSignupStep2Personal({
    super.key,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<ClientSignupStep2Personal> createState() =>
      _ClientSignupStep2PersonalState();
}

class _ClientSignupStep2PersonalState extends State<ClientSignupStep2Personal> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _idNumberController = TextEditingController();
  File? _idImage;
  bool _isLoading = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _idImage = File(pickedFile.path));
    }
  }

  void _handleComplete() {
    if (_formKey.currentState!.validate() && _idImage != null) {
      setState(() => _isLoading = true);
      try {
        widget.onComplete(
          _fullNameController.text.trim(),
          _usernameController.text.trim(),
          _idNumberController.text.trim(),
          _idImage!.path,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    } else if (_idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture your ID photo')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F3A7D)),
          onPressed: widget.onBack,
        ),
        title: const Text(
          'Personal Information',
          style: TextStyle(color: Color(0xFF0F3A7D), fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0D7A7A),
                    ),
                    child: const Center(
                      child: Text(
                        '2',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 1.0,
                      minHeight: 4,
                      backgroundColor: Colors.grey[300],
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Color(0xFF0D7A7A)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Title
              const Text(
                'Personal Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3A7D),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Step 2 of 2 - Final Step',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Full name field
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        hintText: 'John Doe',
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Full name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Username field
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: 'johndoe',
                        labelText: 'Username',
                        prefixIcon: const Icon(Icons.at),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Username is required';
                        }
                        if ((value?.length ?? 0) < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value!)) {
                          return 'Username can only contain letters, numbers, and underscores';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // ID number field
                    TextFormField(
                      controller: _idNumberController,
                      decoration: InputDecoration(
                        hintText: 'Enter your ID number',
                        labelText: 'ID Number',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'ID number is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // ID photo section
              Text(
                'ID Photo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              // Photo preview or capture button
              if (_idImage == null)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to capture ID photo',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_idImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _idImage = null),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              // Complete button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isLoading || _idImage == null) ? null : _handleComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7A7A),
                    disabledBackgroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Complete Signup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
