import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'doctor_signup_page.dart';
import '../Screens/doctor_dashboard.dart';

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  bool _isObscure = true;
  bool _isLoading = false;

  // Real-time email validation state
  String _emailError = '';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmailRealTime);
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

  @override
  void dispose() {
    _emailController.removeListener(_validateEmailRealTime);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Login Function
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
        MaterialPageRoute(builder: (context) => const DoctorDashboard()),
      );

    } on FirebaseAuthException catch (e) {
      String message = "Login failed";

      if (e.code == 'user-not-found') {
        message = "No user found for that email.";
      }
      // --- UPDATE START: Smart Error Message ---
      else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = "Wrong password. If you reset it recently, use the new one.";
      }
      // --- UPDATE END ---
      else if (e.code == 'invalid-email') {
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

  // Forgot Password Dialog
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

                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter your email"), backgroundColor: Colors.red),
                  );
                  return;
                }

                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

                  if (!context.mounted) return;

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Reset link sent! Check your inbox."),
                      backgroundColor: Colors.green,
                    ),
                  );
                } on FirebaseAuthException catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? "Error"), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
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
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // Back Button
                FadeInAnimation(
                  delay: 1,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF0D47A1),
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Logo
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
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_person_rounded,
                        size: 70,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Texts
                FadeInAnimation(
                  delay: 3,
                  child: Center(
                    child: Column(
                      children: const [
                        Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Login to your account',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

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
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 12),
                        child: _emailError.isNotEmpty
                            ? Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 15),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      _emailError,
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 12.5, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Use your registered Gmail address (example@gmail.com)',
                                style: TextStyle(color: Colors.blue[700], fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

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
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscure ? Icons.visibility_off : Icons.visibility,
                            color: Colors.blue[800],
                          ),
                          onPressed: () {
                            setState(() {
                              _isObscure = !_isObscure;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 12),
                        child: Text(
                          'Required: 8+ chars, uppercase, lowercase, number & special character',
                          style: TextStyle(color: Colors.blue[700], fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Forgot Password
                FadeInAnimation(
                  delay: 6,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showForgotPasswordDialog();
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Login Button
                FadeInAnimation(
                  delay: 7,
                  child: ScaleButton(
                    onTap: _isLoading ? () {} : _handleLogin,
                    child: Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                          color: const Color(0xFF0D47A1),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF0D47A1).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5)
                            )
                          ]
                      ),
                      alignment: Alignment.center,
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

                // Sign Up Row
                FadeInAnimation(
                  delay: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: Color(0xFF1976D2)),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DoctorSignupScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
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
    );
  }

  // Helper Widget
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
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.13),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _isObscure : false,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: const Color(0xFF0D47A1)),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 20,
          ),
        ),
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

    Future.delayed(Duration(milliseconds: widget.delay * 150), () {
      if (mounted) _controller.forward();
    });

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}