//Miguel Fernandes Costacurta - 25003110
// Refatoração feita por do layout - Pedro Henrique Contardi Soler - 25005592
// Importa File para guardar temporariamente a imagem escolhida pelo usuário.
import 'dart:io';

// Permite descobrir o usuário recém-criado antes de salvar a foto no Storage.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Abre câmera ou galeria na última etapa do cadastro.
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// Reaproveita o serviço já existente que envia foto de perfil ao Firebase Storage.
import '../../perfil/services/profile_photo_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/mescla_brand_logo.dart';
import '../services/auth_service.dart';
import '../services/user_firestore_service.dart';
import 'login_screen.dart';
import 'signup_verification_flow_screen.dart';

/// Tela de cadastro integrada ao Firebase Auth e Firestore (Material 3).
///
/// O layout segue o protótipo do PI; o fluxo cria o utilizador no Auth e o
/// documento de perfil em `users/{uid}`.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  // Guarda o nome completo digitado na etapa 1.
  final _nameController = TextEditingController();
  // Guarda o e-mail digitado na etapa 2.
  final _emailController = TextEditingController();
  // Guarda o telefone digitado na etapa 3.
  final _phoneController = TextEditingController();
  // Guarda o CPF digitado na etapa 5.
  final _cpfController = TextEditingController();
  // Guarda a senha digitada na etapa 6.
  final _passwordController = TextEditingController();
  // Guarda a confirmação de senha digitada na etapa 7.
  final _confirmPasswordController = TextEditingController();
  // Centraliza a abertura de câmera/galeria para a etapa final de foto.
  final _imagePicker = ImagePicker();

  final _phoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );

  final _cpfFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  // Controla se o campo de senha principal aparece oculto.
  bool _obscurePassword = true;
  // Controla se o campo de confirmação de senha aparece oculto.
  bool _obscureConfirmPassword = true;
  // Marca se o usuário aceitou termos e privacidade.
  bool _acceptedTerms = false;
  // Bloqueia ações repetidas enquanto a câmera/galeria está aberta.
  bool _isPickingPhoto = false;
  // Bloqueia o botão principal enquanto o cadastro está sendo enviado.
  bool _isSubmitting = false;
  // Mantém a foto selecionada localmente até a conta existir no Firebase Auth.
  File? _profilePhotoFile;
  // Indica qual etapa do cadastro está visível no momento.
  int _currentStep = 0;

  // Total de telas do fluxo: cada dado fica em uma etapa separada.
  static const int _totalSteps = 9;

  /// `false` = MFA por e-mail; `true` = MFA por SMS (Firebase Phone).
  bool _mfaSmsPreferred = false;

  // Verifica a regra visual de senha com no mínimo 8 caracteres.
  bool get _passwordHasMin8 {
    final value = _passwordController.text;
    return value.length >= 8;
  }

  // Verifica se a senha contém pelo menos uma letra maiúscula.
  bool get _passwordHasUppercase {
    final value = _passwordController.text;
    return RegExp(r'[A-Z]').hasMatch(value);
  }

  // Verifica se a senha contém pelo menos um número.
  bool get _passwordHasNumber {
    final value = _passwordController.text;
    return RegExp(r'[0-9]').hasMatch(value);
  }

  // Verifica se a senha contém pelo menos um caractere especial.
  bool get _passwordHasSpecialChar {
    final value = _passwordController.text;
    return RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }

  // Confere se a senha principal é igual à confirmação.
  bool get _passwordMatchesConfirmation {
    return _passwordController.text == _confirmPasswordController.text;
  }

  // Facilita saber quando o botão principal deve criar a conta em vez de avançar.
  bool get _isLastStep => _currentStep == _totalSteps - 1;

  // Normaliza espaços duplicados para usar um nome limpo no perfil e nas iniciais.
  String get _fullName {
    return _nameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  void dispose() {
    // Boas praticas: libera listeners internos dos controllers.
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  OutlineInputBorder _stadiumBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: color),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required BuildContext context,
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final stroke = theme.brightness == Brightness.light
        ? const Color(0xFFE8E2F6)
        : colorScheme.outline;
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(
        icon,
        color: colorScheme.primary.withValues(alpha: 0.72),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: theme.brightness == Brightness.light
          ? const Color(0xFFFCFAFF)
          : colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      enabledBorder: _stadiumBorder(stroke),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      border: _stadiumBorder(stroke),
    );
  }

  void _showFeatureMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Extrai a primeira letra de uma parte do nome para montar o avatar padrão.
  String _initialFrom(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.substring(0, 1).toUpperCase();
  }

  // Gera as iniciais do avatar padrão concatenando nome e sobrenome.
  String _profileInitials() {
    // Divide o nome normalizado em partes, ignorando espaços vazios.
    final parts = _fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    // Fallback da marca quando ainda não existe nome digitado.
    if (parts.isEmpty) return 'MI';
    // Se houver só um nome, usa apenas a primeira letra dele.
    if (parts.length == 1) return _initialFrom(parts.first);
    // Com nome e sobrenome, concatena a primeira letra do primeiro e do último.
    return '${_initialFrom(parts.first)}${_initialFrom(parts.last)}';
  }

  bool _isEmailPlausible(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }

  /// Celular BR: 11 dígitos (DDD + 9 + 8), com 9 após o DDD (padrão atual).
  bool _isValidBrazilMobilePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 11) return false;
    if (digits[2] != '9') return false;
    return true;
  }

  bool _isValidCPF(String value) {
    final cpf = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (cpf.isEmpty) return false;
    if (cpf.length != 11) return false;

    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(cpf[i]) * (10 - i);
    }

    int firstDigit = (sum * 10) % 11;
    if (firstDigit == 10) firstDigit = 0;

    if (firstDigit != int.parse(cpf[9])) return false;

    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(cpf[i]) * (11 - i);
    }

    int secondDigit = (sum * 10) % 11;
    if (secondDigit == 10) secondDigit = 0;

    if (secondDigit != int.parse(cpf[10])) return false;

    return true;
  }

  String? _validationMessageForStep(int step) {
    // Usa a etapa atual para validar apenas a informação visível naquele momento.
    switch (step) {
      case 0:
        // A primeira etapa exige um nome preenchido.
        if (_fullName.isEmpty) {
          return 'Informe seu nome completo.';
        }
        // Separa nome e sobrenome para garantir que o avatar padrão tenha duas bases.
        final parts = _fullName
            .split(RegExp(r'\s+'))
            .where((part) => part.trim().isNotEmpty)
            .toList(growable: false);
        // Exige pelo menos duas partes porque o requisito pede nome + sobrenome.
        if (parts.length < 2) {
          return 'Informe nome e sobrenome para continuar.';
        }
        // Null significa que a etapa está válida.
        return null;
      case 1:
        // A segunda etapa valida o formato básico do e-mail.
        if (!_isEmailPlausible(_emailController.text)) {
          return 'Informe um e-mail válido.';
        }
        // Permite avançar quando o e-mail parece válido.
        return null;
      case 2:
        // A terceira etapa valida celular brasileiro com DDD e nono dígito.
        if (!_isValidBrazilMobilePhone(_phoneController.text)) {
          return 'Telefone celular inválido. Informe DDD + 9 dígitos, no formato '
              '(XX) 9XXXX-XXXX.';
        }
        // Permite avançar quando o telefone atende à regra.
        return null;
      case 3:
        // O método de 2FA já tem uma opção padrão selecionada, então não bloqueia.
        return null;
      case 4:
        // A quinta etapa valida CPF com dígitos verificadores.
        if (!_isValidCPF(_cpfController.text)) {
          return 'CPF inválido. Verifique e tente novamente.';
        }
        // Permite avançar quando o CPF é válido.
        return null;
      case 5:
        // Reúne todas as regras da checklist de senha.
        final hasAllRules =
            _passwordHasMin8 &&
            _passwordHasUppercase &&
            _passwordHasNumber &&
            _passwordHasSpecialChar;
        // Bloqueia avanço se qualquer critério da senha segura faltar.
        if (!hasAllRules) {
          return 'Sua senha não atende a todos os critérios de senha segura.';
        }
        // Permite avançar quando a senha cumpre todos os critérios.
        return null;
      case 6:
        // A confirmação não pode ficar vazia.
        if (_confirmPasswordController.text.isEmpty) {
          return 'Confirme sua senha para continuar.';
        }
        // A confirmação deve ser idêntica à senha principal.
        if (!_passwordMatchesConfirmation) {
          return 'As senhas não conferem. Verifique o campo de confirmação.';
        }
        // Permite avançar quando as senhas conferem.
        return null;
      case 7:
        // A etapa de termos exige aceite antes de permitir ir para a foto.
        if (!_acceptedTerms) {
          return 'Aceite os Termos de Uso e a Política de Privacidade para continuar.';
        }
        // Permite avançar quando os termos foram aceitos.
        return null;
      case 8:
        // A foto é opcional, pois o usuário pode seguir com avatar padrão.
        return null;
    }
    // Fallback defensivo para qualquer índice inesperado.
    return null;
  }

  bool _validateStep(int step, {bool moveToStep = false}) {
    // Busca a mensagem de erro específica da etapa informada.
    final message = _validationMessageForStep(step);
    // Sem mensagem, a etapa está válida.
    if (message == null) return true;
    // Se a validação global encontrar erro em etapa anterior, volta para ela.
    if (moveToStep && _currentStep != step) {
      setState(() => _currentStep = step);
    }
    // Mostra a mensagem no Snackbar usando o padrão já existente da tela.
    _showFeatureMessage(message);
    // Retorna false para impedir avanço ou envio do cadastro.
    return false;
  }

  void _goToNextStep() {
    // Evita múltiplos toques enquanto há envio ou seleção de foto em andamento.
    if (_isSubmitting || _isPickingPhoto) return;
    // Valida a tela atual antes de permitir avanço.
    if (!_validateStep(_currentStep)) return;
    // Na última etapa, o botão deixa de avançar e passa a criar a conta.
    if (_isLastStep) {
      _onCreateAccount();
      return;
    }
    // Avança uma etapa mantendo todos os dados já digitados nos controllers.
    setState(() => _currentStep += 1);
  }

  void _goToPreviousStep() {
    // Também bloqueia voltar durante envio ou seleção de imagem.
    if (_isSubmitting || _isPickingPhoto) return;
    // Na primeira etapa, a seta volta para a tela anterior do app.
    if (_currentStep == 0) {
      Navigator.of(context).pop();
      return;
    }
    // Nas demais etapas, volta apenas uma tela do cadastro.
    setState(() => _currentStep -= 1);
  }

  Future<void> _pickProfilePhoto(ImageSource source) async {
    // Evita abrir câmera/galeria mais de uma vez ao mesmo tempo.
    if (_isPickingPhoto || _isSubmitting) return;
    // Liga o estado de carregamento usado para desabilitar botões.
    setState(() => _isPickingPhoto = true);
    try {
      // Abre câmera ou galeria conforme a opção clicada na etapa final.
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
      // Se a tela foi fechada durante a escolha, não tenta atualizar estado.
      if (!mounted) return;
      setState(() {
        // Se o usuário cancelar, mantém a foto anterior; se escolher, salva o File.
        _profilePhotoFile = image == null
            ? _profilePhotoFile
            : File(image.path);
      });
    } catch (_) {
      // Se o plugin falhar, mostra uma mensagem simples sem quebrar o cadastro.
      if (!mounted) return;
      _showFeatureMessage('Não foi possível selecionar a foto agora.');
    } finally {
      // Desliga o estado de carregamento quando a operação termina.
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  Future<void> _uploadSelectedProfilePhotoIfNeeded() async {
    // Lê a foto local selecionada na última etapa.
    final photoFile = _profilePhotoFile;
    // Se o usuário escolheu avatar padrão, não há upload para fazer.
    if (photoFile == null) return;

    // Depois de criar a conta, o Firebase Auth já deve ter o uid do usuário.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // Se por algum motivo não houver uid, não bloqueia a conta já criada.
    if (uid == null) return;

    try {
      // Envia o arquivo para o Storage usando o serviço já existente do perfil.
      final url = await ProfilePhotoStorageService.enviarFoto(
        arquivoLocal: photoFile,
        uid: uid,
      );
      // Salva a URL pública da foto no documento users/{uid}.
      await UserFirestoreService.setProfilePhotoUrl(url);
    } catch (_) {
      // Falha de foto não deve impedir que a conta criada continue existindo.
      if (!mounted) return;
      _showFeatureMessage(
        'Conta criada, mas não foi possível salvar a foto agora.',
      );
    }
  }

  Future<void> _onCreateAccount() async {
    // Impede duplo clique no botão de criar conta.
    if (_isSubmitting) return;

    // Antes de enviar, revalida todas as etapas obrigatórias anteriores à foto.
    for (int step = 0; step < _totalSteps - 1; step++) {
      // Se alguma etapa falhar, volta para ela e interrompe o envio.
      if (!_validateStep(step, moveToStep: true)) return;
    }

    // Usa o nome normalizado para persistir no perfil.
    final name = _fullName;
    // Remove espaços extras do e-mail antes de enviar.
    final email = _emailController.text.trim();
    // Mantém o telefone formatado para validação e depois limpa para persistir.
    final phone = _phoneController.text.trim();
    // Mantém o CPF formatado para validação e depois limpa para persistir.
    final cpf = _cpfController.text.trim();
    // Usa a senha exatamente como digitada, pois espaços podem fazer parte dela.
    final password = _passwordController.text;

    // Persiste telefone só com números no Firestore.
    final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // Persiste CPF só com números no Firestore.
    final cpfDigits = cpf.replaceAll(RegExp(r'[^0-9]'), '');

    // Mostra loading e desabilita ações durante criação da conta.
    setState(() => _isSubmitting = true);
    try {
      // Normaliza e-mail para navegação pós-cadastro e verificação.
      final normalizedEmail = email.trim().toLowerCase();
      // Cria o usuário no Firebase Auth e o perfil no Firestore.
      await UserFirestoreService.createUserWithEmailAndPassword(
        name: name,
        email: email,
        phone: phoneDigits,
        cpf: cpfDigits,
        password: password,
        mfaDeliveryMethod: _mfaSmsPreferred
            ? UserFirestoreService.mfaDeliverySms
            : UserFirestoreService.mfaDeliveryEmail,
      );
      // Se o usuário escolheu foto, faz upload depois que o uid já existe.
      await _uploadSelectedProfilePhotoIfNeeded();

      // Evita navegação se a tela saiu da árvore durante a operação assíncrona.
      if (!mounted) return;
      // Encaminha para o fluxo de verificação inicial do cadastro.
      await Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              SignupVerificationFlowScreen(userEmail: normalizedEmail),
        ),
        // Remove telas anteriores para impedir voltar para cadastro já concluído.
        (route) => false,
      );
    } catch (error) {
      // Traduz erros de Auth/Firestore para mensagens amigáveis do app.
      if (!mounted) return;
      _showFeatureMessage(AuthService.messageForError(error));
    } finally {
      // Remove loading quando o envio termina ou falha.
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _stepTitle() {
    // Define o título exibido no card principal conforme a etapa atual.
    switch (_currentStep) {
      case 0:
        // Etapa de nome completo.
        return 'Qual é o seu nome completo?';
      case 1:
        // Etapa de e-mail.
        return 'Qual é o seu e-mail?';
      case 2:
        // Etapa de telefone.
        return 'Informe seu telefone celular';
      case 3:
        // Etapa de preferência de segundo fator.
        return 'Como deseja receber códigos?';
      case 4:
        // Etapa de CPF.
        return 'Informe seu CPF';
      case 5:
        // Etapa da senha principal.
        return 'Crie uma senha segura';
      case 6:
        // Etapa de confirmação de senha.
        return 'Confirme sua senha';
      case 7:
        // Etapa de aceite de documentos legais.
        return 'Termos e privacidade';
      case 8:
        // Etapa final opcional de foto.
        return 'Escolha sua foto de perfil';
    }
    // Fallback caso algum índice inesperado seja usado.
    return 'Criar Conta';
  }

  String _stepDescription() {
    // Define o texto auxiliar abaixo do título da etapa.
    switch (_currentStep) {
      case 0:
        // Explica por que nome e sobrenome são solicitados juntos.
        return 'Usaremos nome e sobrenome para montar seu perfil e o avatar padrão.';
      case 1:
        // Explica o uso do e-mail no login e nas verificações.
        return 'Esse e-mail será usado para acessar a conta e receber verificações.';
      case 2:
        // Explica a regra esperada para o celular.
        return 'Digite um celular brasileiro com DDD para validações de segurança.';
      case 3:
        // Explica a escolha de canal do segundo fator.
        return 'Escolha o canal preferido para o segundo fator de autenticação.';
      case 4:
        // Explica o motivo do CPF dentro do cadastro.
        return 'O CPF ajuda na identificação segura da sua conta.';
      case 5:
        // Orienta o usuário a cumprir a checklist de senha.
        return 'A senha precisa atender todos os critérios abaixo.';
      case 6:
        // Explica que a confirmação evita erro de digitação.
        return 'Digite a mesma senha novamente para evitar erros.';
      case 7:
        // Mantém o ponto de integração para uma tela futura de termos.
        return 'A tela completa de termos poderá ser conectada aqui posteriormente.';
      case 8:
        // Explica que a foto é opcional e pode usar avatar padrão.
        return 'Você pode tirar uma foto, fazer upload ou seguir com o avatar padrão.';
    }
    // Fallback vazio para índices inesperados.
    return '';
  }

  IconData _stepIcon() {
    // Retorna o ícone visual que acompanha a etapa atual.
    switch (_currentStep) {
      case 0:
        // Ícone de pessoa para nome.
        return Icons.person_outline_rounded;
      case 1:
        // Ícone de e-mail para endereço eletrônico.
        return Icons.mail_outline_rounded;
      case 2:
        // Ícone de telefone para celular.
        return Icons.phone_outlined;
      case 3:
        // Ícone de segurança para segundo fator.
        return Icons.verified_user_outlined;
      case 4:
        // Ícone de documento para CPF.
        return Icons.badge_outlined;
      case 5:
      case 6:
        // Ícone de cadeado para senha e confirmação.
        return Icons.lock_outline_rounded;
      case 7:
        // Ícone de política para termos e privacidade.
        return Icons.policy_outlined;
      case 8:
        // Ícone de câmera para foto de perfil.
        return Icons.photo_camera_outlined;
    }
    // Fallback para manter um ícone válido.
    return Icons.person_add_alt_1_rounded;
  }

  Widget _buildPasswordChecklist(BuildContext context) {
    // Captura o tema atual para reaproveitar tipografia e cores.
    final theme = Theme.of(context);
    // Captura o ColorScheme para colorir itens concluídos com a cor principal.
    final colorScheme = theme.colorScheme;
    // Define o estilo base de cada linha da checklist de senha.
    final criteriaTextStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary.withValues(alpha: 0.85),
      letterSpacing: 0.5,
      height: 1.35,
    );

    // Agrupa todas as regras visuais da senha abaixo do campo.
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mostra se a senha já atingiu o tamanho mínimo.
          _PasswordChecklistRow(
            text: 'DEVE CONTER 8 CARACTERES',
            satisfied: _passwordHasMin8,
            colorScheme: colorScheme,
            baseStyle: criteriaTextStyle,
          ),
          // Mostra se a senha já tem letra maiúscula.
          _PasswordChecklistRow(
            text: 'PELO MENOS UMA LETRA MAIÚSCULA',
            satisfied: _passwordHasUppercase,
            colorScheme: colorScheme,
            baseStyle: criteriaTextStyle,
          ),
          // Mostra se a senha já tem número.
          _PasswordChecklistRow(
            text: 'DEVE CONTER NÚMEROS',
            satisfied: _passwordHasNumber,
            colorScheme: colorScheme,
            baseStyle: criteriaTextStyle,
          ),
          // Mostra se a senha já tem caractere especial.
          _PasswordChecklistRow(
            text: 'PELO MENOS UM CARACTERE ESPECIAL',
            satisfied: _passwordHasSpecialChar,
            colorScheme: colorScheme,
            baseStyle: criteriaTextStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    // Usa o tema atual para textos auxiliares e mensagens de feedback.
    final theme = Theme.of(context);
    // Usa o esquema de cores para estados positivos e erros.
    final colorScheme = theme.colorScheme;

    // Renderiza apenas o conteúdo da etapa atual, deixando o formulário mais leve.
    switch (_currentStep) {
      case 0:
        // Primeira etapa: nome completo em uma tela dedicada.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rótulo superior do campo.
            _buildLabel(context, 'NOME COMPLETO *'),
            // Espaço entre rótulo e campo.
            const SizedBox(height: 8),
            // Campo que coleta nome e sobrenome.
            TextField(
              // Liga o campo ao controller persistente da tela.
              controller: _nameController,
              // Ao apertar "próximo" no teclado, o usuário avança.
              textInputAction: TextInputAction.next,
              // Capitaliza cada palavra para nomes próprios.
              textCapitalization: TextCapitalization.words,
              // Submissão pelo teclado usa a mesma validação do botão.
              onSubmitted: (_) => _goToNextStep(),
              // Aplica a decoração premium centralizada.
              decoration: _fieldDecoration(
                context: context,
                hintText: 'Ex: Maria Silva',
                icon: Icons.person_outline_rounded,
              ),
            ),
          ],
        );
      case 1:
        // Segunda etapa: e-mail em uma tela dedicada.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rótulo do campo de e-mail.
            _buildLabel(context, 'E-MAIL PESSOAL *'),
            const SizedBox(height: 8),
            // Campo que coleta o e-mail de login.
            TextField(
              controller: _emailController,
              // Mostra teclado otimizado para e-mail no celular.
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _goToNextStep(),
              decoration: _fieldDecoration(
                context: context,
                hintText: 'seu@email.com.br',
                icon: Icons.mail_outline_rounded,
              ),
            ),
          ],
        );
      case 2:
        // Terceira etapa: telefone celular em uma tela dedicada.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLabel(context, 'TELEFONE CELULAR *'),
            const SizedBox(height: 8),
            // Campo que coleta o celular com máscara brasileira.
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              // Aplica a máscara (XX) 9XXXX-XXXX enquanto o usuário digita.
              inputFormatters: [_phoneFormatter],
              onSubmitted: (_) => _goToNextStep(),
              decoration: _fieldDecoration(
                context: context,
                hintText: 'Ex: (19) 99999-9999',
                icon: Icons.phone_outlined,
              ),
            ),
          ],
        );
      case 3:
        // Quarta etapa: escolha do canal de 2FA.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLabel(context, 'CÓDIGO NO LOGIN (2º FATOR) *'),
            const SizedBox(height: 10),
            // SegmentedButton deixa claro que só uma opção pode ser escolhida.
            SegmentedButton<bool>(
              // false representa e-mail; true representa SMS.
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text('E-mail'),
                  icon: Icon(Icons.mail_outline_rounded),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('SMS'),
                  icon: Icon(Icons.sms_outlined),
                ),
              ],
              // Mantém selecionada a opção salva no estado.
              selected: <bool>{_mfaSmsPreferred},
              // Atualiza a preferência quando o usuário troca o canal.
              onSelectionChanged: (Set<bool> next) {
                setState(() => _mfaSmsPreferred = next.first);
              },
            ),
            // Texto abaixo explica o efeito prático da escolha.
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 4),
              child: Text(
                _mfaSmsPreferred
                    ? 'No login: SMS após associar este número ao Firebase Auth.'
                    : 'No login: código de 6 dígitos enviado ao seu e-mail.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        );
      case 4:
        // Quinta etapa: CPF em uma tela dedicada.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLabel(context, 'CPF *'),
            const SizedBox(height: 8),
            // Campo numérico com máscara de CPF.
            TextField(
              controller: _cpfController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              // Aplica a máscara 000.000.000-00 durante a digitação.
              inputFormatters: [_cpfFormatter],
              onSubmitted: (_) => _goToNextStep(),
              decoration: _fieldDecoration(
                context: context,
                hintText: '000.000.000-00',
                icon: Icons.badge_outlined,
              ),
            ),
          ],
        );
      case 5:
        // Sexta etapa: senha principal separada da confirmação.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLabel(context, 'SENHA SEGURA *'),
            const SizedBox(height: 8),
            // Campo de senha com opção de mostrar/ocultar.
            TextField(
              controller: _passwordController,
              // Oculta a senha por padrão por segurança visual.
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              // Atualiza a checklist em tempo real.
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _goToNextStep(),
              decoration: _fieldDecoration(
                context: context,
                hintText: '********',
                icon: Icons.lock_outline_rounded,
                // Botão à direita alterna visibilidade da senha.
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            // Checklist mostra cada regra de senha separadamente.
            _buildPasswordChecklist(context),
          ],
        );
      case 6:
        // Sétima etapa: confirmação de senha em tela própria.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLabel(context, 'INSERIR NOVAMENTE *'),
            const SizedBox(height: 8),
            // Campo que deve repetir exatamente a senha anterior.
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              // Atualiza a mensagem de conferência em tempo real.
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _goToNextStep(),
              decoration: _fieldDecoration(
                context: context,
                hintText: '********',
                icon: Icons.lock_outline_rounded,
                // Botão à direita alterna visibilidade da confirmação.
                suffixIcon: IconButton(
                  tooltip: _obscureConfirmPassword
                      ? 'Mostrar senha'
                      : 'Ocultar senha',
                  onPressed: () {
                    setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
                  },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            // Só mostra feedback quando o usuário já digitou algo na confirmação.
            if (_confirmPasswordController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 4),
                child: Text(
                  // Texto positivo ou negativo conforme a comparação das senhas.
                  _passwordMatchesConfirmation
                      ? 'As senhas conferem.'
                      : 'As senhas ainda não conferem.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _passwordMatchesConfirmation
                        ? colorScheme.primary
                        : colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
      case 7:
        // Oitava etapa: aceite de termos e política antes de finalizar.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox mantém o aceite salvo em _acceptedTerms.
            Checkbox(
              value: _acceptedTerms,
              onChanged: (value) {
                setState(() => _acceptedTerms = value ?? false);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Texto legal ocupa o espaço restante ao lado do checkbox.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 11),
                // Text.rich permite destacar os nomes dos documentos.
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                    children: [
                      const TextSpan(text: 'Li e aceito os '),
                      TextSpan(
                        text: 'Termos de Uso',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' e a '),
                      TextSpan(
                        text: 'Política de Privacidade',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text:
                            '. A próxima versão pode abrir o documento completo nesta etapa.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      case 8:
        // Nona etapa: foto opcional, depois cria a conta.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview central mostra foto escolhida ou iniciais do avatar padrão.
            Center(
              child: _ProfilePhotoPreview(
                file: _profilePhotoFile,
                initials: _profileInitials(),
                isLoading: _isPickingPhoto,
              ),
            ),
            const SizedBox(height: 22),
            // Abre a câmera para tirar uma nova foto.
            OutlinedButton.icon(
              onPressed: _isPickingPhoto || _isSubmitting
                  ? null
                  : () => _pickProfilePhoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Tirar foto'),
            ),
            const SizedBox(height: 10),
            // Abre a galeria para selecionar uma imagem existente.
            OutlinedButton.icon(
              onPressed: _isPickingPhoto || _isSubmitting
                  ? null
                  : () => _pickProfilePhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Fazer upload'),
            ),
            const SizedBox(height: 10),
            // Remove qualquer foto selecionada e mantém o avatar padrão.
            TextButton.icon(
              onPressed: _isPickingPhoto || _isSubmitting
                  ? null
                  : () => setState(() => _profilePhotoFile = null),
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('Usar avatar padrão'),
            ),
          ],
        );
    }

    // Fallback visual vazio para evitar retorno nulo se surgir etapa inesperada.
    return const SizedBox.shrink();
  }

  Widget _buildStepIcon(BuildContext context) {
    // Lê as cores do tema para o ícone acompanhar claro/escuro.
    final colorScheme = Theme.of(context).colorScheme;
    // Container circular cria o destaque visual premium da etapa.
    return Container(
      // Define largura fixa para manter proporção em todas as etapas.
      width: 50,
      // Define altura fixa para formar um círculo perfeito.
      height: 50,
      // Decoração concentra forma, gradiente e sombra.
      decoration: BoxDecoration(
        // Garante que o container seja circular.
        shape: BoxShape.circle,
        // Gradiente dá profundidade sem precisar de imagem.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // Cor principal da marca no início do gradiente.
            colorScheme.primary,
            // Variação mais suave da cor principal no fim do gradiente.
            colorScheme.primary.withValues(alpha: 0.72),
          ],
        ),
        // Sombra cria destaque do ícone sobre o card.
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      // Ícone interno muda conforme a etapa atual.
      child: Icon(_stepIcon(), color: colorScheme.onPrimary, size: 25),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Captura o tema para aplicar tipografia e cores do app.
    final theme = Theme.of(context);
    // Captura o esquema de cores do Material 3.
    final colorScheme = theme.colorScheme;
    // Usa o gradiente padrão das telas de autenticação.
    final gradientStops = AppColors.shellGradientColors(theme.brightness);
    // Calcula a porcentagem preenchida da barra de progresso.
    final progress = (_currentStep + 1) / _totalSteps;
    // Usa a superfície correta para tema claro ou escuro.
    final cardColor = AppColors.themeCardSurface(theme);

    // Ajusta status/navigation bar para combinar com o fundo da tela.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.shellOverlayStyle(theme.brightness),
      child: Scaffold(
        // O corpo inteiro recebe o gradiente de autenticação.
        body: Container(
          width: double.infinity,
          height: double.infinity,
          // Fundo visual da tela.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientStops,
            ),
          ),
          // SafeArea evita colisão com notch, status bar e navegação do sistema.
          child: SafeArea(
            // Scroll evita overflow em celulares pequenos ou com teclado aberto.
            child: SingleChildScrollView(
              // Scroll evita overflow quando teclado abre em ecras menores.
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              // Coluna principal organiza cabeçalho, progresso, card e botões.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Voltar para a tela anterior (geralmente login).
                  Align(
                    alignment: Alignment.centerLeft,
                    // Mesmo padrão simples usado na tela de recuperar senha.
                    child: IconButton(
                      onPressed: _goToPreviousStep,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: AppColors.textSecondary,
                      tooltip: 'Voltar',
                    ),
                  ),
                  const SizedBox(height: 0),
                  // Logo oficial do Mescla nas telas de autenticação.
                  const MesclaAuthHeaderLogo(),
                  const SizedBox(height: 14),
                  // Selo curto para transmitir segurança sem ocupar muito espaço.
                  Text(
                    'CADASTRO SEGURO',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Título principal da tela.
                  Text(
                    'Criar Conta',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Subtítulo compacto para manter o formulário mais alto na tela.
                  Text(
                    'Inicie sua jornada no mercado de venture capital em poucos minutos.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Linha com barra de progresso e chip numérico.
                  Row(
                    children: [
                      // Barra ocupa todo o espaço horizontal restante.
                      Expanded(
                        child: ClipRRect(
                          // Arredonda as pontas da barra.
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            // Valor entre 0 e 1 conforme etapa atual.
                            value: progress,
                            minHeight: 9,
                            color: colorScheme.primary,
                            backgroundColor: AppColors.progressTrack(theme),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Chip mostra etapa atual/total de forma rápida.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          // Fundo suave para não competir com o botão principal.
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          // Exemplo: 1/9, 2/9, 3/9...
                          '${_currentStep + 1}/$_totalSteps',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Texto secundário mantém acessibilidade da progressão.
                  Text(
                    'Etapa ${_currentStep + 1} de $_totalSteps',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Card principal contém apenas o conteúdo da etapa atual.
                  Container(
                    // Decoração premium do card.
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(32),
                      // Borda sutil separa o card do fundo claro.
                      border: Border.all(
                        color: theme.brightness == Brightness.light
                            ? Colors.white.withValues(alpha: 0.82)
                            : colorScheme.outlineVariant,
                      ),
                      // Sombras leves dão profundidade sem pesar a tela.
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.05),
                          blurRadius: 36,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    // Padding interno mantém respiro entre borda e conteúdo.
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Ícone da etapa fica alinhado à esquerda como ponto focal.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _buildStepIcon(context),
                          ),
                          const SizedBox(height: 14),
                          // Título muda a cada etapa.
                          Text(
                            _stepTitle(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Descrição muda a cada etapa para orientar o usuário.
                          Text(
                            _stepDescription(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Troca animada entre campos reduz sensação de tela estática.
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            // Chave força o Flutter a animar quando a etapa muda.
                            child: KeyedSubtree(
                              key: ValueKey<int>(_currentStep),
                              child: _buildCurrentStep(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Botão secundário aparece só depois da primeira etapa.
                  if (_currentStep > 0) ...[
                    OutlinedButton.icon(
                      onPressed: _isSubmitting || _isPickingPhoto
                          ? null
                          : _goToPreviousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: const StadiumBorder(),
                        side: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Voltar'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Botão principal avança etapas ou cria a conta na última etapa.
                  FilledButton(
                    onPressed: _isSubmitting || _isPickingPhoto
                        ? null
                        : _goToNextStep,
                    style: FilledButton.styleFrom(
                      elevation: 3,
                      shadowColor: AppColors.primaryShadow(colorScheme),
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: const StadiumBorder(),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: _isSubmitting
                        // Loading aparece durante criação da conta.
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        // Texto muda na última etapa para deixar claro que vai enviar.
                        : Text(
                            _isLastStep ? 'Criar Conta →' : 'Continuar',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.1,
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),
                  // Link para voltar ao login se o usuário já tiver conta.
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          const TextSpan(text: 'Já possui uma conta? '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              // Troca a tela atual pelo login.
                              onTap: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Fazer Login',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilePhotoPreview extends StatelessWidget {
  // Widget isolado para manter a etapa de foto legível no build principal.
  const _ProfilePhotoPreview({
    // Arquivo local selecionado na câmera ou galeria.
    required this.file,
    // Iniciais usadas quando não existe foto selecionada.
    required this.initials,
    // Indica se a câmera/galeria está em processamento.
    required this.isLoading,
  });

  // Foto local escolhida antes do upload.
  final File? file;
  // Texto exibido no avatar padrão.
  final String initials;
  // Controla a sobreposição com CircularProgressIndicator.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Usa o tema para fonte e cor principal.
    final theme = Theme.of(context);
    // Cor principal vira o fundo do avatar padrão.
    final primary = theme.colorScheme.primary;

    // Child muda entre imagem real e iniciais.
    Widget child;
    // Se existe foto local, mostra preview da imagem.
    if (file != null) {
      child = ClipOval(
        // ClipOval garante que a imagem fique circular.
        child: Image.file(file!, width: 118, height: 118, fit: BoxFit.cover),
      );
    } else {
      // Sem foto, mostra as iniciais concatenadas do nome e sobrenome.
      child = Text(
        initials,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // Stack permite sobrepor loading em cima do avatar.
    return Stack(
      alignment: Alignment.center,
      children: [
        // Círculo base do avatar.
        Container(
          width: 118,
          height: 118,
          alignment: Alignment.center,
          // Fundo roxo e formato circular para o avatar padrão.
          decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
          // Conteúdo é a foto ou as iniciais.
          child: child,
        ),
        // Quando está carregando, escurece e mostra spinner.
        if (isLoading)
          Container(
            width: 118,
            height: 118,
            // Overlay escuro deixa o loading visível sobre foto ou iniciais.
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: const Padding(
              // Padding centraliza o spinner sem ocupar todo o círculo.
              padding: EdgeInsets.all(38),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _PasswordChecklistRow extends StatelessWidget {
  const _PasswordChecklistRow({
    required this.text,
    required this.satisfied,
    required this.colorScheme,
    required this.baseStyle,
  });

  final String text;
  final bool satisfied;
  final ColorScheme colorScheme;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            satisfied
                ? Icons.check_circle_outline_rounded
                : Icons.circle_outlined,
            size: 16,
            color: satisfied ? colorScheme.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: (baseStyle ?? const TextStyle()).copyWith(
                color: satisfied ? colorScheme.primary : baseStyle?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
