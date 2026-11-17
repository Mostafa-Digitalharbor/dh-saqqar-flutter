import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/storage/secure_token_store.dart';
import 'package:saqqar_app/features/auth/data/auth_api.dart';
import 'package:saqqar_app/features/auth/data/social_auth_service.dart';
import 'package:saqqar_app/features/auth/view/auth_flow_screen.dart';
import 'package:saqqar_app/features/auth/view_model/auth_cubit.dart';
import 'package:saqqar_app/features/auth/view_model/auth_flow_cubit.dart';

import 'shot_harness.dart';

Widget _wrap(Widget child) {
  final api = AuthApi(Dio());
  final auth = AuthCubit(api: api, tokenStore: SecureTokenStore());
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AuthApi>.value(value: api),
      RepositoryProvider<AuthCubit>.value(value: auth),
      RepositoryProvider<SocialAuthService>.value(value: SocialAuthService()),
    ],
    child: child,
  );
}

void main() {
  for (final e in {
    'signin': AuthFlowStep.signInEmail,
    'signup': AuthFlowStep.signUpEmail,
    'otp': AuthFlowStep.signUpOtp,
    'reset': AuthFlowStep.resetEmail,
    'newpass': AuthFlowStep.resetNewPassword,
  }.entries) {
    testWidgets('auth ${e.key}', (t) async {
      await shot(t, 'auth_${e.key}', _wrap(AuthFlowScreen(initial: e.value)));
    });
  }
}
