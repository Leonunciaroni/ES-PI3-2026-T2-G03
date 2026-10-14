// Principal: Miguel Fernandes Costacurta - 25003110
// RA: 25003110
//
// ┌──────────────────────────────────────────────────────────────────────────┐
// │ O QUE É ESTE ARQUIVO? (não é tela Flutter — é Cloud Function)           │
// │                                                                          │
// │ Este arquivo roda no SERVIDOR do Firebase. O app Flutter chama ele       │
// │ via TwoFactorService (two_factor_service.dart).                          │
// │                                                                          │
// │ FLUXO COMPLETO:                                                          │
// │   login_screen → TwoFactorService.sendCode()                             │
// │       → twoFactor (action: "send") → gera OTP → salva → manda e-mail     │
// │   two_factor_verification_screen → TwoFactorService.verifyCode()         │
// │       → twoFactor (action: "verify") → confere OTP → ok ou erro          │
// │                                                                          │
// │ Quem faz o quê:                                                          │
// │   twoFactor.ts (este arquivo) → gerente: gera código, manda e-mail       │
// │   twoFactorRepository.ts      → cofre: salva/valida no Firestore         │
// │   two_factor_service.dart     → ponte do app até aqui                    │
// └──────────────────────────────────────────────────────────────────────────┘

// HttpsError → erro padronizado que o app Flutter consegue ler e mostrar na UI.
// onCall → cria uma "Callable Function" (o app chama com httpsCallable('twoFactor')).
import {HttpsError, onCall} from "firebase-functions/https";

// logger → registra mensagens no console do Firebase (útil para debug em produção).
import * as logger from "firebase-functions/logger";

// Garante que quem chamou a function está logado no Firebase Auth.
// Se não estiver → lança erro "unauthenticated".
import {requireAuthenticatedUser} from "../shared/auth.js";

// Limpa strings (trim, remove lixo) antes de usar.
import {normalizeString} from "../shared/validation.js";

// Envia o e-mail com o código OTP (usa SMTP configurado no servidor).
import {sendVerificationEmail} from "../shared/sendVerificationEmail.js";

// saveCode → grava hash do OTP no Firestore.
// verifyCode → confere se o código digitado bate com o salvo.
import {saveCode, verifyCode} from "../repositories/twoFactorRepository.js";

// Tipo TypeScript com dados do usuário autenticado (uid, email, etc.).
import {AuthenticatedUser} from "../types/index.js";

// ─────────────────────────────────────────────────────────────────────────────
// ENTRADA PRINCIPAL: export const twoFactor
// O app chama: httpsCallable('twoFactor').call({ action: 'send' | 'verify' })
// ─────────────────────────────────────────────────────────────────────────────
export const twoFactor = onCall({region: "us-central1"}, async (request) => {
  // request vem do app Flutter. Exige usuário logado (senha já validada no login).
  const user = requireAuthenticatedUser(request);

  // Lê qual ação o app pediu: "send" (enviar código) ou "verify" (validar código).
  const action = normalizeString(request.data?.action)?.toLowerCase();

  // ── AÇÃO: ENVIAR CÓDIGO ──
  // Chamado por login_screen → TwoFactorService.sendCode()
  if (action === "send") {
    return handleSend(user);
  }

  // ── AÇÃO: VALIDAR CÓDIGO ──
  // Chamado por two_factor_verification_screen → TwoFactorService.verifyCode()
  if (action === "verify") {
    const code = normalizeString(request.data?.code);
    return handleVerify(user.uid, code);
  }

  // Se action não for "send" nem "verify", rejeita a requisição.
  throw new HttpsError(
    "invalid-argument",
    "Informe action: send ou verify."
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// handleSend — gera OTP, salva no Firestore e manda e-mail
// ─────────────────────────────────────────────────────────────────────────────
async function handleSend(user: AuthenticatedUser): Promise<{sent: boolean}> {
  // 2FA por e-mail exige que a conta tenha e-mail no Firebase Auth.
  if (!user.email) {
    throw new HttpsError(
      "failed-precondition",
      "Conta sem e-mail associado não pode usar 2FA por e-mail."
    );
  }

  // Gera número aleatório de 6 dígitos (ex.: "482910").
  const code = generateCode();

  // Salva hash do código em two_factor_codes/{uid} (via repository).
  await saveCode(user.uid, code);

  // Envia e-mail com o código em texto claro (só o usuário vê no e-mail).
  await sendVerificationEmail(user.email, code, "two_factor");

  // Log no servidor para auditoria/debug.
  logger.info("Código 2FA enviado.", {uid: user.uid});

  // Resposta que o app recebe: { sent: true }.
  return {sent: true};
}

// ─────────────────────────────────────────────────────────────────────────────
// handleVerify — confere o código digitado pelo usuário
// ─────────────────────────────────────────────────────────────────────────────
async function handleVerify(
  uid: string,
  code: string | undefined
): Promise<{verified: boolean}> {
  // Validação básica: tem que ser exatamente 6 dígitos numéricos.
  if (!code || code.length !== 6 || !/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Informe um código de 6 dígitos.");
  }

  // Delega a verificação real ao repository (Firestore + hash + expiração).
  const result = await verifyCode(uid, code);

  // Código correto → sucesso. O repository já apagou o doc (uso único).
  if (result.ok) {
    logger.info("2FA verificado com sucesso.", {uid});
    return {verified: true};
  }

  // Código errado/expirado → converte motivo técnico em mensagem para o app.
  logger.warn("Falha na verificação 2FA.", {uid, reason: result.reason});

  switch (result.reason) {
    case "not_found":
    case "expired":
      // Nunca pediu código ou passou dos 5 minutos.
      throw new HttpsError(
        "not-found",
        "Código expirado ou inexistente. Solicite um novo código."
      );
    case "max_attempts":
      // Errou 5 vezes seguidas.
      throw new HttpsError(
        "resource-exhausted",
        "Número máximo de tentativas atingido. Solicite um novo código."
      );
    case "invalid":
      // Código existe mas não bate com o digitado.
      throw new HttpsError("invalid-argument", "Código incorreto.");
    default:
      throw new HttpsError("internal", "Falha inesperada na verificação.");
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// generateCode — cria OTP aleatório de 6 dígitos
// ─────────────────────────────────────────────────────────────────────────────
function generateCode(): string {
  // Número entre 0 e 999999.
  const n = Math.floor(Math.random() * 1_000_000);
  // padStart(6, "0") garante 6 caracteres: "42" vira "000042".
  return n.toString().padStart(6, "0");
}
