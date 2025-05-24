import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:prototype_2/providers/user_provider.dart';
import 'package:prototype_2/services/rasa_chatbot_service.dart';
import 'screens/login.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  try {
    print("[MAIN] Initializing Firebase");
    // Firebase options with all required parameters
    FirebaseOptions firebaseOptions = const FirebaseOptions(
      apiKey: "AIzaSyCQc1aAveY6fZE2D9avhV-_l5i31duWBRM",
      appId: "1:322229820964:android:435411372aa3ab922042b1",
      messagingSenderId: "322229820964",
      projectId: "jobbot-f483e",
      storageBucket: "jobbot-f483e.firebasestorage.app",
    );
    
    print("[MAIN] Calling Firebase.initializeApp()");
    await Firebase.initializeApp(options: firebaseOptions);
    print("[MAIN] Firebase initialized successfully");
    
    // Check if Firebase Auth is working
    print("[MAIN] Getting current FirebaseAuth user as a test");
    User? currentUser = FirebaseAuth.instance.currentUser;
    print("[MAIN] Current user: ${currentUser?.uid ?? 'No user logged in'}");
    
    
  } catch (e) {
    print("[MAIN] Error initializing Firebase: $e");
    // Continue with app launch, but Firebase functionality will be limited
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        // Add the RasaChatbotService provider here
        ChangeNotifierProvider(create: (context) => RasaChatbotService()),
      ],
      child: MaterialApp(
        title: 'JobBot',
        theme: ThemeData(
          primaryColor: const Color(0xFFAADDEC),
          scaffoldBackgroundColor: const Color(0xFFE7E7E7),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    try {
      // You can directly check Firebase Auth instead of StandaloneAuth
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print("[AUTH] User is logged in: ${currentUser.uid}");
        // Optionally sign out for testing purposes
        await FirebaseAuth.instance.signOut();
        print("[AUTH] Signed out existing user to prevent auto-login issues");
      } else {
        print("[AUTH] No user is logged in");
      }
    } catch (e) {
      print("[AUTH] Error checking/handling current user: $e");
    }
    
    // Short delay to ensure Firebase has time to initialize
    await Future.delayed(Duration(milliseconds: 500));
    
    setState(() {
      _isLoading = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Add your logo here
              Image.asset(
                'assets/logo_word.png',
                height: 100,
                width: 266,
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    
    // Always return the login page
    return const LoginPage();
  }
}