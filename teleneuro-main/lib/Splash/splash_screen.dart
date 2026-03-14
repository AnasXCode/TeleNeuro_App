import 'package:flutter/material.dart';
import '../Profile Side/profile_selection.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  void goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
              children: [
                splashPage(
                  title: "Welcome To TeleNeuro",
                  description:
                      "AI powered MRI analysis for early Alzheimer detection",
                  image: 'assets/screen1.png',
                ),
                splashPage(
                  title: "Smart MRI Analysis",
                  description:
                      "Upload MRI scans and get instant accurate diagnosis",
                  image: 'assets/screen2.jpg',
                ),
                splashPage(
                  title: "Secure Specialist Connection",
                  description:
                      "Connect with neurologists and securely share AI reports",
                  image: 'assets/screen3.jpg',
                ),
                splashPage(
                  title: "Let's Get Started",
                  description: "",
                  image: 'assets/screen4.jpg',
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: goToHome, child: const Text("Skip")),

                IconButton(
                  onPressed: () {
                    if (currentIndex == 3) {
                      goToHome();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn,
                      );
                    }
                  },
                  icon: Icon(
                    currentIndex == 3 ? Icons.check : Icons.arrow_forward,
                    color: Colors.blue,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) => buildDot(index)),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: currentIndex == index ? 12 : 8,
      height: currentIndex == index ? 12 : 8,
      decoration: BoxDecoration(
        color: currentIndex == index ? Colors.blue : Colors.grey[400],
        shape: BoxShape.circle,
      ),
    );
  }

  Widget splashPage({
    required String title,
    required String description,
    required String image,
  }) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 420,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
                image: DecorationImage(
                  image: AssetImage(image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
