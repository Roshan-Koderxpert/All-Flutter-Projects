import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/login_controller.dart';
import '../../core/assets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthController authController = Get.find<AuthController>();

  final _selectedProtocol = 'https://'.obs;
  final _urlError = ''.obs;
  final _usernameError = ''.obs;
  final _passwordError = ''.obs;
  final _obscurePassword = true.obs;
  final _isFetchingDB = false.obs;

  final _showLoginForm = false.obs;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchDatabases() async {
    String urlInput = _urlController.text.trim();

    if (urlInput.isEmpty) {
      _urlError.value = 'Please enter server URL';
      return;
    }

    setState(() {
      _isFetchingDB.value = true;
      _urlError.value = '';
    });

    try {
      // Auto-extract protocol and clean URL
      String cleanUrl = urlInput;
      String protocol = _selectedProtocol.value;

      // Extract protocol if exists in URL
      if (cleanUrl.startsWith('https://')) {
        protocol = 'https://';
        cleanUrl = cleanUrl.substring(8);
      } else if (cleanUrl.startsWith('http://')) {
        protocol = 'http://';
        cleanUrl = cleanUrl.substring(7);
      }

      // Remove trailing /odoo, /web, or any path
      cleanUrl = cleanUrl.split('/').first;

      // Update protocol dropdown
      _selectedProtocol.value = protocol;

      // Update text field with clean URL
      _urlController.text = cleanUrl;

      final fullUrl = protocol + cleanUrl;

      // Clear previous databases and selected database before fetching
      authController.databases.clear();
      authController.selectedDatabase.value = '';

      await authController.fetchDatabases(fullUrl);

      // Remove duplicates immediately after fetch
      authController.databases.value = authController.databases.toSet().toList();

      if (authController.databases.isEmpty) {
        _urlError.value = 'No databases found on this server';
      } else {
        _urlError.value = ''; // Clear any previous errors
      }
    } catch (e) {
      _urlError.value = 'Invalid server URL format. Please check and try again.';
      // Clear databases on error
      authController.databases.clear();
      authController.selectedDatabase.value = '';
    } finally {
      setState(() {
        _isFetchingDB.value = false;
      });
    }
  }


  Future<void> _handleLogin() async {
    // Clear previous errors
    _urlError.value = '';
    _usernameError.value = '';
    _passwordError.value = '';

    bool hasError = false;

    // Validate URL
    if (_urlController.text
        .trim()
        .isEmpty) {
      _urlError.value = 'Server URL is required';
      hasError = true;
    }

    // Validate Database
    if (authController.databases.isEmpty) {
      _urlError.value = 'Please fetch databases first';
      hasError = true;
    }

    // Validate Username
    if (_usernameController.text
        .trim()
        .isEmpty) {
      _usernameError.value = 'Username is required';
      hasError = true;
    }

    // Validate Password
    if (_passwordController.text
        .trim()
        .isEmpty) {
      _passwordError.value = 'Password is required';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    // Attempt login
    try {
      final fullUrl = _selectedProtocol.value + _urlController.text.trim();

      authController.isLoading.value = true;

      await authController.login(
        fullUrl,
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      // Check if login was successful
      if (!authController.isLoggedIn.value) {
        _usernameError.value = 'Invalid username or password';
        _passwordError.value = 'Please check your credentials';
        setState(() {});
      }
    } catch (e) {
      _usernameError.value = 'Login failed';
      _passwordError.value = 'Invalid credentials or server error';
      setState(() {});
    } finally {
      authController.isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AppImage.login_screen_bg),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // 🔙 Back Button
                    if (_showLoginForm.value)
                      Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 12, left: 12),
                          child: GestureDetector(
                            onTap: () {
                              _showLoginForm.value = false;
                            },
                            child: Container(
                              width: 25,
                              height: 25,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                AppIcon.back,
                                height: 25,
                                width: 25,
                                color: Color(0xff6B3E60),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // 🔹 Logo
                    SizedBox(height: _showLoginForm.value ? 40 : 106),
                    Center(
                      child: Image.asset(
                        AppImage.logo,
                        width: 237.34,
                        height: 98,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // 🔹 Sign In Card
                    SizedBox(height: 65),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: 342,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: _buildLoginCardContent(),
                      ),
                    ),

                    Spacer(),

                    // 🔹 Footer (hides when keyboard is open)
                    AnimatedOpacity(
                      opacity: MediaQuery.of(context).viewInsets.bottom > 0 ? 0.0 : 1.0,
                      duration: Duration(milliseconds: 200),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          "Powered by Koderxpert Technologies LLP",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.nunitoSans,
                            fontSize: 12,
                            color: Colors.black,
                            fontWeight: FontWeight.normal,
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
      ),
    ));
  }


  Widget _buildLoginCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Sign In",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.nunitoSans,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Obx(() => Text(
          _showLoginForm.value
              ? "Enter Your Credential to access the app"
              : "Configure Your Server Connection",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.nunitoSans,
            fontSize: 14,
            color: Color(0xFF999999),
          ),
        )),
        SizedBox(height: 24),
        Obx(() =>
        _showLoginForm.value
            ? _buildLoginForm()
            : _buildServerConfig()),
      ],
    );
  }


  Widget _buildServerConfig() {
    return Column(
      children: [
        // Server URL with protocol dropdown
        Container(
          width: 308,
          height: 48,
          decoration: BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFFCCCCCC),
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(AppIcon.url, width: 18, height: 18),
                  SizedBox(width: 8),
                  Obx(() => DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      itemHeight: 50,
                      value: _selectedProtocol.value,
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: Colors.white,
                      icon: Image.asset(
                        AppIcon.arrow_down,
                        color: Color(0xff999999),
                        width: 18,
                        height: 18,
                      ),
                      underline: SizedBox(),
                      isDense: true,
                      items: ['http://', 'https://']
                          .map((protocol) =>
                          DropdownMenuItem(
                            value: protocol,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  protocol,
                                  style: TextStyle(
                                    fontFamily: AppFonts.nunitoSans,
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(width: 6),
                              ],
                            ),
                          ),


                      )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) _selectedProtocol.value = value;
                      },
                    ),
                  )),

                ],
              ),
              SizedBox(width: 8),

              Container(
                height: 24,
                width: 1,
                color: Color(0xFFDDDDDD),
              ),

              SizedBox(width: 8),

              // URL TextField
              Expanded(
                child: TextField(
                  controller: _urlController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _fetchDatabases();
                    }
                  },
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: "Enter Server Address",
                    hintStyle: TextStyle(
                      fontFamily: AppFonts.nunitoSans,
                      fontSize: 14,
                      fontStyle: FontStyle.normal,
                      color: Color(0xFFCCCCCC),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(bottom: 2),
                    isDense: true,
                  ),

                ),
              ),
              // Arrow or Loading indicator
              Obx(() => _isFetchingDB.value
                  ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : SizedBox(width: 18)), // Empty space when not loading
            ],
          ),
        ),

        Obx(() =>
        _urlError.value.isNotEmpty
            ? Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            _urlError.value,
            style: TextStyle(
              fontFamily: AppFonts.nunitoSans,
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        )
            : SizedBox()),

        SizedBox(height: 20),

        // Database Dropdown
        Obx(() => Container(
          width: 308,
          height: 48,
          decoration: BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFFCCCCCC),
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Colors.white,
              menuMaxHeight: 200,
              hint: Row(
                children: [
                  Image.asset(AppIcon.database, width: 18, height: 18),
                  SizedBox(width: 8),
                  Text(
                    "Select Database",
                    style: TextStyle(
                      fontFamily: AppFonts.nunitoSans,
                      fontSize: 14,
                      color: Color(0xFFCCCCCC),
                    ),
                  ),
                ],
              ),
              value: authController.selectedDatabase.value.isEmpty
                  ? null
                  : authController.selectedDatabase.value,
              icon: Image.asset(AppIcon.arrow_down, width: 18, height: 18),
              isExpanded: true,
              items: authController.databases
                  .map((db) => DropdownMenuItem(
                value: db,
                child: Text(
                  db,
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  authController.selectedDatabase.value = value;
                }
              },
            ),
          ),
        )),
        SizedBox(height: 20),

        // Next Button
        SizedBox(
          width: 308,
          height: 48,
          child: Obx(() => ElevatedButton(
            onPressed: authController.selectedDatabase.value.isEmpty
                ? null
                : () {
              _showLoginForm.value = true;
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: authController.selectedDatabase.value.isEmpty
                  ? Color(0xFF6B3E60)
                  : Color(0xFF6B3E60), // Change to your primary color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              "Next",
              style: TextStyle(
                fontFamily: AppFonts.nunitoSans,
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ),
        )
      ],

    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        // Username Field
        // Username Field
        Container(
          width: 308,
          height: 48,
          decoration: BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFFCCCCCC),
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Image.asset(AppIcon.username, height: 18, width: 18, color: Colors.grey[600]),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: "Enter Username",
                    hintStyle: TextStyle(
                      fontFamily: AppFonts.nunitoSans,
                      fontSize: 13,
                      color: Color(0xFFCCCCCC),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),

        Obx(() =>
        _usernameError.value.isNotEmpty
            ? Align(
          alignment: Alignment.centerLeft,

          child: Text(
            _usernameError.value,
            style: TextStyle(
              fontFamily: AppFonts.nunitoSans,
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        )
            : SizedBox()),

        SizedBox(height: 20),

        // Password Field
        Container(
          width: 308,
          height: 48,
          decoration: BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(0xFFCCCCCC),
              width: 1,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Image.asset(AppIcon.password, height: 18,width: 18, color: Colors.grey[600]),
              SizedBox(width: 8),
              Expanded(
                child: Obx(() =>
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword.value,
                      style: TextStyle(
                        fontFamily: AppFonts.nunitoSans,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: "Enter Password",
                        hintStyle: TextStyle(
                          fontFamily: AppFonts.nunitoSans,
                          fontSize: 13,
                          color: Color(0xFFCCCCCC),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    )),
              ),
              Obx(() =>
                  GestureDetector(
                    onTap: () =>
                    _obscurePassword.value = !_obscurePassword.value,
                    child: Icon(
                      _obscurePassword.value
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                  )),
            ],
          ),
        ),

        Obx(() =>
        _passwordError.value.isNotEmpty
            ? Align(
          alignment: Alignment.centerLeft,

          child: Text(
            _passwordError.value,
            style: TextStyle(
              fontFamily: AppFonts.nunitoSans,
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        )
            : SizedBox()),

        SizedBox(height: 20),




        // Login Button
        SizedBox(
          width: 308,
          height: 48,
          child: Obx(() =>
              ElevatedButton(
                onPressed: authController.isLoading.value ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6B3E60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: authController.isLoading.value
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  "Login",
                  style: TextStyle(
                    fontFamily: AppFonts.nunitoSans,
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )),
        ),
      ],
    );
  }


}