package com.example.pi_iii

import io.flutter.embedding.android.FlutterFragmentActivity

/// [FlutterFragmentActivity] é necessária para o plugin `local_auth` (BiometricPrompt)
/// funcionar em muitos Android — incluindo Samsung com só reconhecimento facial.
class MainActivity : FlutterFragmentActivity()
