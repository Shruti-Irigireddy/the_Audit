import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:the_audit/navbar.dart';
import 'package:the_audit/theme.dart';
import 'package:the_audit/profile.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavBar(
        onProfileTap: () {
          Navigator.pushNamed(context, '/profile');
        }
      )
    );
  }
}