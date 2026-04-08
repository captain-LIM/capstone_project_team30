import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// 서버 URL 설정
// ─────────────────────────────────────────────────────────────
// Windows/Web 데스크탑: http://localhost:3000
// Android 에뮬레이터:   http://10.0.2.2:3000
// 실제 Android 기기:    ipconfig로 PC의 IPv4 주소 확인 후 변경
// ─────────────────────────────────────────────────────────────
final String kBaseUrl = (defaultTargetPlatform == TargetPlatform.android)
    ? 'http://10.0.2.2:3000'
    : 'http://localhost:3000';

const Color kPrimary = Color(0xFFFF6B35);
const Color kBackground = Color(0xFFF5F5F5);
