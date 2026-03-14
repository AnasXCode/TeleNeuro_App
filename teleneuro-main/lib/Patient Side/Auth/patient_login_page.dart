import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Screens/patient_dashboard.dart';

import 'patient_signup_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscure = true;
  bool _isLoading = false;

  // Professional Blue Theme Colors
  final Color kPrimaryColor = const Color(0xFF1565C0);
  final Color kSecondaryColor = const Color(0xFF42A5F5);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIN LOGIC ---
  Future<void> _handleLogin() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Email and Password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (context, animation, secondaryAnimation) => const PatientDashboard(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutQuart;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );

    } on FirebaseAuthException catch (e) {
      String message = "Login failed";
      if (e.code == 'user-not-found') {
        message = "No user found for that email.";
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = "Wrong password.";
      } else if (e.code == 'invalid-email') {
        message = "Email address is invalid.";
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

  // --- FORGOT PASSWORD DIALOG ---
  void _showForgotPasswordDialog() {
    TextEditingController resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter your email to receive a password reset link."),
              const SizedBox(height: 10),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: "Email Address",
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
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
                String email = resetEmailController.text.trim();
                if (email.isEmpty) return;

                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Link sent! Please check your email."), backgroundColor: Colors.green),
                  );
                } on FirebaseAuthException catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? "Error"), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              child: const Text("Send Link", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // --- FIX IS HERE: BACK BUTTON ---
                  FadeInAnimation(
                    delay: 1,
                    child: Align(
                      alignment: Alignment.centerLeft, // Align left for better UI
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: kPrimaryColor, size: 28),
                        onPressed: () {
                          // CHANGE: PushReplacement hata kar Pop laga diya
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Icon
                  FadeInAnimation(
                    delay: 2,
                    child: Center(
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Icon(Icons.lock_person_rounded, size: 70, color: kPrimaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Text
                  FadeInAnimation(
                    delay: 3,
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            'Welcome Back',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kPrimaryColor),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Login to your account',
                            style: TextStyle(fontSize: 16, color: kSecondaryColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Email
                  FadeInAnimation(
                    delay: 4,
                    child: _buildTextField(
                      controller: _emailController,
                      hintText: 'Email Address',
                      icon: Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 35),

                  // Password
                  FadeInAnimation(
                    delay: 5,
                    child: _buildTextField(
                      controller: _passwordController,
                      hintText: 'Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      suffixIcon: IconButton(
                        icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: kPrimaryColor),
                        onPressed: () {
                          setState(() {
                            _isObscure = !_isObscure;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Forgot Password
                  FadeInAnimation(
                    delay: 6,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // LOGIN BUTTON
                  FadeInAnimation(
                    delay: 7,
                    child: ScaleButton(
                      onTap: _isLoading ? () {} : _handleLogin,
                      child: Container(
                        width: double.infinity,
                        height: 55,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: kPrimaryColor,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 4))
                            ]
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'LOGIN',
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

                  const SizedBox(height: 25),

                  // Sign Up Link
                  FadeInAnimation(
                    delay: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ", style: TextStyle(color: kSecondaryColor)),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const SignupScreen()),
                            );
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
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
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _isObscure : false,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      ),
    );
  }
}

// Custom Animations (Keep as is)
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