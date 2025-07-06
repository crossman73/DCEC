# DCEC 프로젝트 구조 가이드

## 1. 디렉토리 구조 개요

### 1.1 서비스 디렉토리
- **ClaudeCodeService/**
  - src/ : 소스 코드
  - tests/ : 테스트 코드
  - docs/ : 서비스별 문서
  - config/ : 설정 파일
- **UtilsService/**
  - src/ : 소스 코드
  - tests/ : 테스트 코드
  - docs/ : 서비스별 문서
  - config/ : 설정 파일
- **GeminiService/**
  - src/ : 소스 코드
  - tests/ : 테스트 코드
  - docs/ : 서비스별 문서
  - config/ : 설정 파일
- **BackupService/**
  - src/ : 소스 코드
  - tests/ : 테스트 코드
  - docs/ : 서비스별 문서
  - config/ : 설정 파일

### 1.2 공통 디렉토리
- **lib/**: 공통 라이브러리 및 모듈
- **bin/**: 실행 파일 및 스크립트
- **docs/**: 프로젝트 문서
- **config/**: 전역 설정 파일

## 2. 주요 디렉토리 설명

### 2.1 서비스 디렉토리
각 서비스는 독립적인 기능 단위로 구성되며, 다음과 같은 구조를 가집니다:

- **ClaudeCodeService/**: Claude AI 관련 코드 서비스
- **UtilsService/**: 공통 유틸리티 서비스
- **GeminiService/**: Gemini AI 관련 코드 서비스
- **BackupService/**: 백업 관리 서비스

### 2.2 공통 디렉토리
- **lib/**: 공통 라이브러리 및 모듈
- **bin/**: 실행 파일 및 스크립트
- **docs/**: 프로젝트 문서
- **config/**: 전역 설정 파일

## 3. 명명 규칙
- 서비스 디렉토리: PascalCase (예: ClaudeCodeService)
- 소스 파일: snake_case (예: utility_functions.ps1)
- 설정 파일: lowercase (예: config.json)

## 4. 버전 관리
- 모든 코드는 Git을 통해 버전 관리
- 각 서비스별 독립적인 버전 관리
- 공통 모듈은 중앙에서 버전 관리
