import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:photo_album/screens/dashboard.dart';

class Home extends StatelessWidget {
  final LocalAuthentication localAuth = LocalAuthentication();

  @override
  Widget build(BuildContext context) {
    //ThemeChanger _themeChanger = Provider.of<ThemeChanger>(context);
    
    return Scaffold(
      body: GestureDetector(
        onTap: () async {
          bool weCanCheckBiometrics = await localAuth.canCheckBiometrics;

           if (weCanCheckBiometrics) {
            bool authenticated = await localAuth.authenticate(
              localizedReason: "Authenticate to see your bank statement.",
            );

            if (authenticated) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Dashboard(),
                ),
              );
            }
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(
              Icons.fingerprint,
              size: 124.0,
            ),
            Text(
              "Touch to Unlock",
              style: GoogleFonts.passionOne(
                fontSize: 64.0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

