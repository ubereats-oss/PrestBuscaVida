import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/auth_repository.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _authRepository = AuthRepository();
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Busca Vida Serviços'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'E-mail'),
            Tab(text: 'Telefone'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _EmailTab(authRepository: _authRepository),
          _PhoneTab(authRepository: _authRepository),
        ],
      ),
    );
  }
}

// ── ABA E-MAIL ────────────────────────────────────────────────────────────────
class _EmailTab extends StatefulWidget {
  final AuthRepository authRepository;
  const _EmailTab({required this.authRepository});
  @override
  State<_EmailTab> createState() => _EmailTabState();
}

class _EmailTabState extends State<_EmailTab> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_isRegisterMode && name.isEmpty) {
      setState(() => _errorMessage = 'Informe seu nome.');
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Preencha todos os campos.');
      return;
    }
    if (password.length < 6) {
      setState(
        () => _errorMessage = 'A senha deve ter no mínimo 6 caracteres.',
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_isRegisterMode) {
        await widget.authRepository.registerWithEmail(
          email: email,
          password: password,
          displayName: name,
        );
      } else {
        await widget.authRepository.signInWithEmail(
          email: email,
          password: password,
        );
      }
      // O StreamBuilder em app.dart redireciona automaticamente após login.
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'E-mail ou senha incorretos.';
    }
    if (raw.contains('email-already-in-use')) {
      return 'Este e-mail já está cadastrado. Tente entrar com sua senha.';
    }
    if (raw.contains('invalid-email')) {
      return 'E-mail inválido.';
    }
    if (raw.contains('network-request-failed')) {
      return 'Sem conexão com a internet.';
    }
    if (raw.contains('permission-denied')) {
      return 'Erro de permissão no servidor. Contate o suporte.';
    }
    return 'Ocorreu um erro. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            _isRegisterMode ? 'Criar conta' : 'Entrar',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          if (_isRegisterMode) ...[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Senha',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isRegisterMode ? 'Criar conta' : 'Entrar'),
          ),

          const SizedBox(height: 16),

          SignInWithAppleButton(
            onPressed: () async {
              try {
                await widget.authRepository.signInWithApple();
              } on SignInWithAppleAuthorizationException catch (e) {
                if (e.code == AuthorizationErrorCode.canceled) return;
                if (mounted) {
                  setState(() => _errorMessage =
                      'Não foi possível entrar com Apple. Tente novamente.');
                }
              } catch (_) {
                if (mounted) {
                  setState(() => _errorMessage =
                      'Não foi possível entrar com Apple. Tente novamente.');
                }
              }
            },
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () {
              setState(() {
                _isRegisterMode = !_isRegisterMode;
                _errorMessage = null;
              });
            },
            child: Text(
              _isRegisterMode
                  ? 'Já tenho conta — Entrar'
                  : 'Não tenho conta — Criar conta',
            ),
          ),
        ],
      ),
    );
  }
}

// ── ABA TELEFONE ──────────────────────────────────────────────────────────────
class _PhoneTab extends StatefulWidget {
  final AuthRepository authRepository;
  const _PhoneTab({required this.authRepository});
  @override
  State<_PhoneTab> createState() => _PhoneTabState();
}

class _PhoneTabState extends State<_PhoneTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _isLoading = false;
  String? _errorMessage;
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Informe seu nome.');
      return;
    }
    if (phone.length < 10) {
      setState(
        () => _errorMessage = 'Informe um número de telefone válido com DDD.',
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await widget.authRepository.startPhoneVerification(
      phoneNumber: '+55$phone',
      displayName: name,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
            _isLoading = false;
          });
        }
      },
      onAutoVerified: (_) {
        // O StreamBuilder em app.dart redireciona automaticamente.
      },
    );
  }

  Future<void> _confirmCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'O código deve ter 6 dígitos.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.authRepository.signInWithPhoneCode(
        verificationId: _verificationId!,
        smsCode: code,
        displayName: _nameController.text.trim(),
      );
      // O StreamBuilder em app.dart redireciona automaticamente.
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Código inválido. Verifique e tente novamente.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            _verificationId == null
                ? 'Entrar com telefone'
                : 'Confirmar código',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          if (_verificationId == null) ...[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Telefone com DDD (somente números)',
                border: OutlineInputBorder(),
                prefixText: '+55 ',
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ] else ...[
            Text(
              'Código enviado para +55 ${_phoneController.text}',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Código SMS (6 dígitos)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading
                ? null
                : (_verificationId == null ? _sendCode : _confirmCode),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_verificationId == null ? 'Enviar código' : 'Confirmar'),
          ),
          if (_verificationId != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                      _verificationId = null;
                      _codeController.clear();
                      _errorMessage = null;
                    }),
              child: const Text('Corrigir número de telefone'),
            ),
          ],
        ],
      ),
    );
  }
}
