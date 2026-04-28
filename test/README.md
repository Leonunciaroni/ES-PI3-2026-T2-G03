# Testes (`flutter test`)

## Widget tests e Firebase Auth

- **`widget_test.dart`** e testes que só montam **UI** sem chamar `signIn` / `createAccount` **não precisam** de `Firebase.initializeApp` enquanto o `build` não tocar em `FirebaseAuth.instance`.
- Testes que **percorrem login ou cadastro até à rede** precisam de **uma** destas abordagens:
  1. **`TestWidgetsFlutterBinding.ensureInitialized()`** e **`Firebase.initializeApp`** (opções de teste ou projeto de integração), ou
  2. Injetar **`AuthService(auth: ...)`** com um **`FirebaseAuth` falso** (p.ex. pacote `firebase_auth_mocks` ou double manual), evitando rede e consola.
- Erros mapeados por **`AuthService.messageForError`** podem ser cobertos de forma **unitária** sem app Firebase — ver **`auth_service_test.dart`**.
