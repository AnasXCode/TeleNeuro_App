import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctor_login_page.dart';
import '../../services/email_validation.dart';
import '../../services/username_validation.dart';
import '../../services/birth_date_utils.dart';
import '../../data/medical_signup_options.dart';
import '../../Widgets/birth_date_picker_field.dart';
import '../../Widgets/searchable_dropdown_field.dart';

class DoctorSignupScreen extends StatefulWidget {
  const DoctorSignupScreen({super.key});

  @override
  State<DoctorSignupScreen> createState() => _DoctorSignupScreenState();
}

class _DoctorSignupScreenState extends State<DoctorSignupScreen> {
  bool _isObscure = true;
  bool _isConfirmObscure = true;
  bool _isLoading = false;

  // Real-time validation state
  String _emailError = '';
  String _usernameError = '';
  String _password = '';

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  DateTime? _selectedDob;
  String? _specialization;
  String? _qualifications;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateUsernameRealTime);
    _emailController.addListener(_validateEmailRealTime);
    _passwordController.addListener(_validatePasswordRealTime);
  }

  void _validateUsernameRealTime() {
    final username = _nameController.text.trim();
    setState(() {
      _usernameError = UsernameValidation.validate(username) ?? '';
    });
  }

  void _validateEmailRealTime() {
    final email = _emailController.text.trim();
    setState(() {
      _emailError = EmailValidation.validateGmailForSignup(email) ?? '';
    });
  }

  void _validatePasswordRealTime() {
    setState(() {
      _password = _passwordController.text;
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_validateUsernameRealTime);
    _emailController.removeListener(_validateEmailRealTime);
    _passwordController.removeListener(_validatePasswordRealTime);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    final dobDate = _selectedDob;
    final specialization = _specialization;
    final qualifications = _qualifications;

    // Validation
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        dobDate == null ||
        specialization == null ||
        qualifications == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!BirthDateUtils.isValidBirthDate(dobDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid date of birth'), backgroundColor: Colors.red),
      );
      return;
    }

    final dob = BirthDateUtils.formatDisplay(dobDate);

    // Username validation
    final usernameValidationError = UsernameValidation.validate(name);
    if (usernameValidationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(usernameValidationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Email validation
    final emailValidationError = EmailValidation.validateGmailForSignup(email);
    if (emailValidationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(emailValidationError),
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

    // Start Loading
    setState(() {
      _isLoading = true;
    });

    try {
      final usernameCheck = UsernameValidation.validate(name);
      if (usernameCheck != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(usernameCheck), backgroundColor: Colors.red),
        );
        return;
      }

      // 1. Create User in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Save Data to Firestore Database (Users Collection)
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'role': 'Doctor',
        'registeredVia': 'doctor_signup',
        'dob': dob,
        'speciality': specialization,
        'specialization': specialization,
        'qualifications': qualifications,

        // ✅ NEW LOGIC: Default rating for new doctors
        'rating': 0.0,
        'totalReviews': 0,

        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Update Auth Profile Display Name
      await userCredential.user?.updateDisplayName(name);

      // 4. Sign out
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Success Message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Account Created! Please Login now.'),
            backgroundColor: Colors.green
        ),
      );

      // Navigate back to Login Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DoctorLoginScreen()),
      );

    } on FirebaseAuthException catch (e) {
      String message = "Signup failed";
      if (e.code == 'weak-password') {
        message = "The password is too weak.";
      } else if (e.code == 'email-already-in-use') {
        message = "The account already exists for that email.";
      } else if (e.code == 'invalid-email') {
        message = "The email is invalid.";
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
            colors: [Color(0xFF42A5F5), Color(0xFF0D47A1)],
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
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Back',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
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
                        children: const [
                          Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 80,
                            color: Colors.white,
                          ),
                          SizedBox(height: 15),
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Fill in the details to get started',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Fields
                  FadeInAnimation(
                    delay: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          hintText: 'Full Name',
                          icon: Icons.person_outline,
                        ),
                        if (_usernameError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _usernameError,
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
                    child: BirthDatePickerField(
                      selectedDate: _selectedDob,
                      accentColor: Colors.blue.shade900,
                      onDateSelected: (date) => setState(() => _selectedDob = date),
                    ),
                  ),
                  const SizedBox(height: 20),

                  FadeInAnimation(
                    delay: 8,
                    child: SearchableDropdownField(
                      value: _specialization,
                      options: MedicalSignupOptions.specializations,
                      hintText: 'Select Specialization',
                      icon: Icons.medical_services_outlined,
                      accentColor: Colors.blue.shade900,
                      onSelected: (v) => setState(() => _specialization = v),
                    ),
                  ),
                  const SizedBox(height: 20),

                  FadeInAnimation(
                    delay: 9,
                    child: SearchableDropdownField(
                      value: _qualifications,
                      options: MedicalSignupOptions.qualifications,
                      hintText: 'Select Qualification',
                      icon: Icons.school_outlined,
                      accentColor: Colors.blue.shade900,
                      onSelected: (v) => setState(() => _qualifications = v),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Signup Button
                  FadeInAnimation(
                    delay: 10,
                    child: ScaleButton(
                      onTap: _isLoading ? () {} : _handleSignup,
                      child: Container(
                        width: double.infinity,
                        height: 55,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: Colors.blue[900],
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5)
                              )
                            ]
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
                    delay: 11,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(color: Colors.white70),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DoctorLoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
        color: const Color.fromARGB(230, 255, 255, 255),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(13, 0, 0, 0),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword
            ? (isConfirmField ? _isConfirmObscure : _isObscure)
            : false,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.blue[900]),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              (isConfirmField ? _isConfirmObscure : _isObscure)
                  ? Icons.visibility_off
                  : Icons.visibility,
              color: Colors.blue[900],
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
          contentPadding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 20,
          ),
        ),
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
                  color: passed ? Colors.greenAccent : Colors.redAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  check['label'] as String,
                  style: TextStyle(
                    color: passed ? Colors.white : Colors.white70,
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

// Animation Classes
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