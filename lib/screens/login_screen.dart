import 'package:flutter/material.dart';

import '../config.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/legal_links.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final app = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await app.signIn(_email.text, _password.text);
    if (!mounted) return;
    // On success the app state swaps screens itself; email is kept on error.
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  InputDecoration _decoration(String label, {Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: Stpg.label(size: 12, spacing: 1.8),
      floatingLabelStyle: Stpg.label(size: 13, color: Stpg.orange, spacing: 1.8),
      filled: true,
      fillColor: Stpg.deepPanel,
      suffixIcon: suffix,
      enabledBorder: border(Stpg.border),
      focusedBorder: border(Stpg.orange, 2),
      border: border(Stpg.border),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldStyle = TextStyle(color: Stpg.text, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.6);
    return Scaffold(
      backgroundColor: Stpg.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Stpg.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Stpg.border, width: 1.5),
                ),
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'STPG',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Stpg.orange, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RAPTOR COMMAND CENTER',
                        textAlign: TextAlign.center,
                        style: Stpg.title(size: 18, spacing: 2.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'DRIVER AUTHENTICATION // SOUTH TEXAS PROVING GROUNDS',
                        textAlign: TextAlign.center,
                        style: Stpg.label(size: 11, spacing: 1.6),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _email,
                        enabled: !_busy,
                        style: fieldStyle,
                        cursorColor: Stpg.orange,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: _decoration('DRIVER EMAIL'),
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        enabled: !_busy,
                        style: fieldStyle,
                        cursorColor: Stpg.orange,
                        obscureText: _obscure,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: _decoration(
                          'PASSWORD',
                          suffix: IconButton(
                            tooltip: _obscure ? 'SHOW PASSWORD' : 'HIDE PASSWORD',
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Stpg.gray),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Stpg.red, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: Stpg.orange,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Stpg.orange.withValues(alpha: 0.45),
                            disabledForegroundColor: Colors.black54,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            _busy ? 'AUTHENTICATING...' : 'LOGIN // COMMAND CENTER',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (StpgConfig.isDevBackend)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Stpg.orange.withValues(alpha: 0.12),
                            border: Border.all(color: Stpg.orange),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'TEST VERSION // SIGN IN WITH THE DEMO LOGIN YOU WERE GIVEN.\nDO NOT ENTER YOUR REAL STPG PASSWORD HERE.',
                            textAlign: TextAlign.center,
                            style: Stpg.label(size: 10.5, color: Stpg.orange, spacing: 1.2),
                          ),
                        )
                      else
                        Text(
                          'USE THE SAME EMAIL + PASSWORD AS YOUR STPG DRIVER PORTAL',
                          textAlign: TextAlign.center,
                          style: Stpg.label(size: 10.5, spacing: 1.4),
                        ),
                      const SizedBox(height: 8),
                      const LegalLinks(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
