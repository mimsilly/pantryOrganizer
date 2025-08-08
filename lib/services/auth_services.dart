import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthServices {

  static SupabaseClient client(){

    final supabase = Supabase.instance.client;

    return supabase;
  }

  static Future<void> logOut() async{
    await Supabase.instance.client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_household_id');
  }

  static Future<void> loginEmailPassword(loginEmail, loginPassword) async {
    await client().auth.signInWithPassword(
    email: loginEmail,
    password: loginPassword);
  }

  static Future<void> resetPassword(String newPassword) async {

   await client().auth.updateUser(UserAttributes(password:newPassword));
  }

  static Future<void> requestResetPassword(String resetEmail) async {

    await client().auth.resetPasswordForEmail(resetEmail, redirectTo: 'pantryorg://password-reset');
  }

}