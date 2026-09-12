import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  bool _isLoggingIn = false;

  // These are the usernames shown to staff. Firebase Authentication needs an
  // email address internally, so the app maps each displayed username to its
  // matching Firebase account.
  static const Map<String, String> _loginEmails = {
    'admin@neyyar': 'admin@neyyar.com',
    'staff@neyyar': 'staff@neyyar.com',
  };

  Future<void> _login() async {
    final username = usernameCtrl.text.trim();
    final password = passwordCtrl.text;
    final email = _loginEmails[username];

    if (email == null || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid username and password')),
      );
      return;
    }

    setState(() => _isLoggingIn = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();
      final data = userDoc.data();

      // An account must be explicitly marked active by an administrator.
      if (!userDoc.exists || data?['active'] != true ||
          (data?['role'] != 'admin' && data?['role'] != 'staff')) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This account is not authorised to use the app')),
        );
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {'role': data!['role']},
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'network-request-failed' =>
          'No internet connection. Please check your network and try again.',
        'wrong-password' ||
        'user-not-found' ||
        'invalid-credential' ||
        'invalid-email' ||
        'INVALID_LOGIN_CREDENTIALS' =>
          'Invalid username or password',
        'too-many-requests' =>
          'Too many attempts. Please try again later.',
        'user-disabled' => 'This account has been disabled',
        _ => e.message?.isNotEmpty == true
            ? e.message!
            : 'Unable to sign in. Please try again.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final isNetwork = e.code == 'unavailable' ||
          e.code == 'network-request-failed' ||
          (e.message?.toLowerCase().contains('network') ?? false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNetwork
                ? 'No internet connection. Please check your network and try again.'
                : (e.message ?? 'Unable to sign in. Please try again.'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final text = e.toString().toLowerCase();
      final isNetwork = text.contains('socket') ||
          text.contains('network') ||
          text.contains('failed host lookup') ||
          text.contains('connection');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNetwork
                ? 'No internet connection. Please check your network and try again.'
                : 'Unable to sign in. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Welcome to Neyyar Heritage Inn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// LOGO
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: screenWidth * 0.55,
                    ),
                    child: Image.asset(
                      'assets/images/neyyar_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 40),

                  /// USERNAME FIELD
                  TextField(
                    controller: usernameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'Enter username',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    onSubmitted: (_) => _isLoggingIn ? null : _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoggingIn ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoggingIn
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
