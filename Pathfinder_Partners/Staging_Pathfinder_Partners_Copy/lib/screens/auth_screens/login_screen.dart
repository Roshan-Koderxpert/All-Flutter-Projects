import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/providers/auth_provider/login_provider.dart';
import 'package:retail_gpt/utils/app_colors.dart';
import 'package:retail_gpt/widgets/background_widget.dart';
import 'package:retail_gpt/widgets/loading_widget.dart';

import 'forget_password.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = "/login-screen";

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscure = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailKey = GlobalKey<FormFieldState>();
  final _passwordController = TextEditingController();
  final _passwordKey = GlobalKey<FormFieldState>();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BackgroundWidget(
          headerWidget: Container(),
          bottomSheetWidget: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 120, // Slightly bigger to act as border
                      width: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // gradient: LinearGradient(
                        //   colors: [Colors.pink, Colors.orange, Colors.blue],
                        //   begin: Alignment.topLeft,
                        //   end: Alignment.bottomRight,
                        // ),
                      ),
                    ),
                    Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white, // Background color inside the border
                      ),
                      alignment: Alignment.center,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.cover,
                          height: 120,
                          width: 120,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 0),
                Text(
                  "RetailGPT",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold
                  ),
                ),
                /// tag line
                //Column(
                //   children: [
                //     Text(
                //       'RetailGPT',
                //       style: TextStyle(
                //         fontSize: 22,
                //         fontWeight: FontWeight.bold,
                //       ),
                //     ),
                //     SizedBox(height: 4),
                //     Text(
                //       'Smarter Shopping Starts Here',
                //       style: TextStyle(
                //         fontSize: 14,
                //         fontWeight: FontWeight.w400,
                //         color: Colors.grey,
                //       ),
                //     ),
                //   ],
                // ),

                /// Gradient color
                // ShaderMask(
                //   shaderCallback: (bounds) => LinearGradient(
                //     colors: [Colors.pink, Colors.orange, Colors.green, Colors.purple],
                //   ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                //   child: Text(
                //     'RetailGPT',
                //     style: TextStyle(
                //       fontSize: 22,
                //       fontWeight: FontWeight.bold,
                //       color: Colors.white, // Required for ShaderMask
                //     ),
                //   ),
                // ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 25),
                    Text(
                      "Login to your account",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 25),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Email Address",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                ),
                              ),
                              TextFormField(
                                key: _emailKey,
                                controller: _emailController,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9@._+-]'),
                                  ),
                                ],
                                autofillHints: [AutofillHints.email],
                                keyboardAppearance: Brightness.dark,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: "Email address",
                                  prefixIcon: Icon(
                                    Icons.email,
                                    color: Colors.grey,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                onChanged: (value) {
                                  _emailKey.currentState!.validate();
                                },
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return "Email is required";
                                  }
                                  // String pattern =
                                  //     r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
                                  // RegExp regExp = RegExp(pattern);
                                  // if (!regExp.hasMatch(value)) {
                                  //   return "Invalid email address";
                                  // }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Password",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                ),
                              ),
                              TextFormField(
                                key: _passwordKey,
                                controller: _passwordController,
                                obscureText: _isObscure,
                                textInputAction: TextInputAction.done,
                                autofillHints: [AutofillHints.password],
                                keyboardType: TextInputType.visiblePassword,
                                keyboardAppearance: Brightness.dark,
                                decoration: InputDecoration(
                                  hintText: "Password",
                                  // helperText:
                                  //     "Password must be at least 6 characters with one uppercase letter, one number and one special character",
                                  prefixIcon: Icon(
                                    Icons.lock,
                                    color: Colors.grey,
                                  ),
                                  suffixIcon: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isObscure = !_isObscure;
                                      });
                                    },
                                    child: Icon(
                                      _isObscure
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  errorMaxLines: 3,
                                  helperMaxLines: 3,
                                ),
                                onChanged: (value) {
                                  _passwordKey.currentState!.validate();
                                },
                                onFieldSubmitted: (value) {
                                  if (_formKey.currentState!.validate()) {
                                    Provider.of<LoginProvider>(
                                      context,
                                      listen: false,
                                    ).login(
                                      _emailController.text,
                                      _passwordController.text,
                                    );
                                  }
                                },
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return "Password is required";
                                  }
                                  // if (value.length < 6) {
                                  //   return "Password must be at least 6 characters";
                                  // }
                                  // // password must contain at least one uppercase letter and one number and one special character
                                  // String pattern =
                                  //     r'^(?=.*?[A-Z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{6,}$';
                                  // RegExp regExp = RegExp(pattern);
                                  // if (!regExp.hasMatch(value)) {
                                  //   return "Password must contain at least one uppercase letter, one special character and one number";
                                  // }
                                  return null;
                                },
                              ),
                            ],
                          ),

                          Container(
                            width: double.infinity,
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: () {
                                Get.toNamed(ForgetPasswordScreen.routeName);
                                },
                              child: Text(
                                "Forget Password?",
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      fontWeight: FontWeight.normal,
                                      color: Colors.lightBlue,
                                    ),
                              ),
                            ),
                          ),
                          SizedBox(height: 25),
                          ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                // Perform login operation
                                Provider.of<LoginProvider>(
                                  context,
                                  listen: false,
                                ).login(
                                  _emailController.text,
                                  _passwordController.text,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: AppColors.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: Size(double.infinity, 56),
                            ),
                            child: Text(
                              "Login",
                              style: Theme.of(context).textTheme.titleMedium!
                                  .copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                          SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Consumer<LoginProvider>(
          builder: (context, loginProvider, child) {
            if (loginProvider.isLoading) {
              return LoadingWidget();
            }
            return Container();
          },
        ),
      ],
    );
  }
}
