import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore
import 'package:shared_preferences/shared_preferences.dart';
import 'patient_portal.dart';
import 'patient_login_page.dart'; // Login Page Import


class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isObscure = true;
  bool _isConfirmObscure = true;
  bool _isLoading = false;

  // Real-time validation state
  String _emailError = '';
  String _password = '';

  // Professional Blue Theme Colors
  final Color kPrimaryColor = const Color(0xFF1565C0);
  final Color kSecondaryColor = const Color(0xFF42A5F5);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  String _gender = "Male";
  String _bloodGroup = "B+";

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmailRealTime);
    _passwordController.addListener(_validatePasswordRealTime);
  }

  void _validateEmailRealTime() {
    final email = _emailController.text.trim();
    setState(() {
      if (email.isEmpty) {
        _emailError = '';
      } else if (!RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$').hasMatch(email)) {
        _emailError = 'Only @gmail.com emails are allowed';
      } else {
        _emailError = '';
      }
    });
  }

  void _validatePasswordRealTime() {
    setState(() {
      _password = _passwordController.text;
    });
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmailRealTime);
    _passwordController.removeListener(_validatePasswordRealTime);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // --- SIGNUP LOGIC ---
  Future<void> _handleSignup() async {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    String dob = _dobController.text.trim();
    String gender = _gender;
    String bloodGroup = _bloodGroup;

    // Validations
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty || dob.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields'), backgroundColor: Colors.red),
      );
      return;
    }

    // Email validation: only @gmail.com allowed
    final gmailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$');
    if (!gmailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Gmail addresses are allowed (e.g. user@gmail.com)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }

    // Password validation: min 8 chars, uppercase, lowercase, digit, special character
    final passwordRegex = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#$%^&*()_+\-=\[\]{};:"\\|,.<>\/?~`]).{8,}$');
    if (!passwordRegex.hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters and include uppercase, lowercase, number, and special character.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Create User in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Step 2: Save User Data in Firestore Database
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'role': 'patient',
        'dob': dob,
        'gender': gender,
        'bloodGroup': bloodGroup,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Mirror name on the FirebaseAuth user + local prefs so reports always have it
      // even when Firestore reads are denied or the device is offline.
      try {
        await userCredential.user!.updateDisplayName(name);
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', name);
      await prefs.setString('email', email);
      await prefs.setString('dob', dob);
      await prefs.setString('gender', gender);
      await prefs.setString('bloodGroup', bloodGroup);

      // Step 3: Sign out immediately so they have to log in manually
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Step 4: Success Message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account Created Successfully! Please Login.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Step 5: Navigate to Login Screen (Not Dashboard)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );

    } on FirebaseAuthException catch (e) {
      String message = "Signup failed";
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is invalid.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFBBDEFB),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // Back Button
                  FadeInAnimation(
                    delay: 1,
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: kPrimaryColor, size: 28),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const PatientPortalScreen()),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Back',
                          style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Header
                  FadeInAnimation(
                    delay: 2,
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.person_add_alt_1_rounded, size: 80, color: kPrimaryColor),
                          const SizedBox(height: 15),
                          Text(
                            'Create Account',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kPrimaryColor),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Fill in the details to get started',
                            style: TextStyle(color: kPrimaryColor.withValues(alpha: 0.7), fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Name Field
                  FadeInAnimation(
                    delay: 3,
                    child: _buildTextField(
                      controller: _nameController,
                      hintText: 'Full Name',
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Email Field
                  FadeInAnimation(
                    delay: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _emailController,
                          hintText: 'Email Address',
                          icon: Icons.email_outlined,
                        ),
                        if (_emailError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _emailError,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  FadeInAnimation(
                    delay: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _passwordController,
                          hintText: 'Password',
                          icon: Icons.lock_outline,
                          isPassword: true,
                          isConfirmField: false,
                        ),
                        if (_password.isNotEmpty)
                          _buildPasswordChecklist(_password),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm Password Field
                  FadeInAnimation(
                    delay: 6,
                    child: _buildTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm Password',
                      icon: Icons.lock_reset_outlined,
                      isPassword: true,
                      isConfirmField: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  FadeInAnimation(
                    delay: 7,
                    child: _buildTextField(
                      controller: _dobController,
                      hintText: 'Date of Birth (e.g. DD-MM-YYYY)',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(height: 20),

                  FadeInAnimation(
                    delay: 8,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            label: "Gender",
                            icon: Icons.wc_outlined,
                            value: _gender,
                            items: const ["Male", "Female", "Other"],
                            onChanged: (v) => setState(() => _gender = v!),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildDropdownField(
                            label: "Blood Group",
                            icon: Icons.water_drop_outlined,
                            value: _bloodGroup,
                            items: const ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"],
                            onChanged: (v) => setState(() => _bloodGroup = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // SIGN UP BUTTON
                  FadeInAnimation(
                    delay: 9,
                    child: ScaleButton(
                      onTap: _isLoading ? () {} : _handleSignup,
                      child: Container(
                        width: double.infinity,
                        height: 55,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: kPrimaryColor,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(color: kPrimaryColor.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 5))
                          ],
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'SIGN UP',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Login Link
                  FadeInAnimation(
                    delay: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: TextStyle(color: kPrimaryColor.withValues(alpha: 0.7)),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                          },
                          child: Text(
                            'Login',
                            style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool isConfirmField = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword
            ? (isConfirmField ? _isConfirmObscure : _isObscure)
            : false,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: kPrimaryColor),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              (isConfirmField ? _isConfirmObscure : _isObscure)
                  ? Icons.visibility_off
                  : Icons.visibility,
              color: kPrimaryColor,
            ),
            onPressed: () {
              setState(() {
                if (isConfirmField) {
                  _isConfirmObscure = !_isConfirmObscure;
                } else {
                  _isObscure = !_isObscure;
                }
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordChecklist(String password) {
    final checks = [
      {'label': 'Minimum 8 characters', 'passed': password.length >= 8},
      {'label': 'Uppercase letter (A-Z)', 'passed': RegExp(r'[A-Z]').hasMatch(password)},
      {'label': 'Lowercase letter (a-z)', 'passed': RegExp(r'[a-z]').hasMatch(password)},
      {'label': 'Number (0-9)', 'passed': RegExp(r'\d').hasMatch(password)},
      {'label': 'Special character (!@#\$%^&*)', 'passed': RegExp(r'''[!@#\$%^&*()_+\-=\[\]{};':"\\|,.<>\/?~`]''').hasMatch(password)},
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: checks.map((check) {
          final passed = check['passed'] as bool;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  passed ? Icons.check_circle : Icons.cancel,
                  color: passed ? const Color(0xFF4CAF50) : Colors.redAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  check['label'] as String,
                  style: TextStyle(
                    color: passed ? const Color(0xFF2E7D32) : Colors.red[700],
                    fontSize: 12.5,
                    fontWeight: passed ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Custom Animations
class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final int delay;
  const FadeInAnimation({super.key, required this.child, required this.delay});
  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    Future.delayed(Duration(milliseconds: widget.delay * 150), () { if (mounted) _controller.forward(); });
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacityAnimation, child: SlideTransition(position: _slideAnimation, child: widget.child));
  }
}

class ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const ScaleButton({super.key, required this.child, required this.onTap});
  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) { _controller.reverse(); widget.onTap(); },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}