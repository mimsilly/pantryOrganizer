import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import 'package:pantry_organizer/pages/reset_password_screen.dart';

class AuthServices {

  static SupabaseClient client(){

    final supabase = Supabase.instance.client;

    return supabase;
  }



 static void configDeepLink(BuildContext context) {
    final appLinks = AppLinks();


    appLinks.uriLinkStream.listen((uri) {
      if (uri.host == 'password-reset') {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => ResetPasswordScreen(),));
      }
    });
  }

  static Future<void> resetPassword(String newPassword) async {

   await client().auth.updateUser(UserAttributes(password:newPassword));
  }

  static Future<void> requestResetPassword(String resetEmail) async {

    await client().auth.resetPasswordForEmail(resetEmail, redirectTo: 'pantryorg://password-reset');
  }

}