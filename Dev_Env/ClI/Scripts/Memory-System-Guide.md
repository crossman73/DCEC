# DCEC Memory System 사용 가이드

## 🧠 개요
DCEC Memory System은 IDE 재시작에도 대화 맥락과 작업 상태를 유지하는 시스템입니다.

## 📁 저장소 구조
```
D:\Dev\DCEC\
├── chat\                           # 전역 대화 (통합, 프로젝트 간 연계)
├── Dev_Env\ClI\chat\              # Dev_Env 전용 대화 (CLI, 개발도구)
├── Infra_Architecture\chat\        # Infrastructure 관련 대화
└── Governance\chat\               # 정책, 문서화 관련 대화
```

## 🚀 빠른 시작

### 1. Memory System 초기화
```powershell
# Dev_Env 스코프로 시작 (현재 CLI 작업용)
.\Start-MemorySystem.ps1 -ProjectScope Dev_Env -ProjectName "CLI_Quality_Management" -WorkContext "PowerShell_Development"

# 전역 스코프로 시작 (통합 작업용)
.\Start-MemorySystem.ps1 -ProjectScope Global -ProjectName "DCEC_Integration" -WorkContext "Cross_Project_Work"
```

### 2. 주요 명령어
```powershell
# 메모리 상태 확인
Show-MemorySummary

# 중요한 메모리 포인트 추가
Add-MemoryPoint -Topic "VSCode 오류 해결" -Description "문제탭 19개 오류 수정 완료" -Type "Solution"

# 대화 기록 검색
Search-ConversationHistory -SearchTerm "PowerShell 코딩 가이드" -SearchScope "Current"

# 프로젝트 스코프 전환
Switch-ProjectScope -NewScope "Global" -ProjectName "통합작업"

# 이전 대화 맥락 복원
Resume-ConversationContext -LastSessions 3
```

## 📝 작업 범위별 사용법

### Dev_Env 스코프 (현재 CLI 작업)
- **용도**: PowerShell 개발, CLI 도구, VSCode 설정, 코드 품질 관리
- **채팅 위치**: `D:\Dev\DCEC\Dev_Env\ClI\chat\`
- **시작**: `.\Start-MemorySystem.ps1 -ProjectScope Dev_Env`

### Global 스코프 (통합 작업)
- **용도**: 프로젝트 간 연계, 전체 아키텍처 논의, 통합 계획
- **채팅 위치**: `D:\Dev\DCEC\chat\`
- **시작**: `.\Start-MemorySystem.ps1 -ProjectScope Global`

### Infra_Architecture 스코프
- **용도**: 네트워크, 하드웨어, 모니터링, 인프라 관리
- **채팅 위치**: `D:\Dev\DCEC\Infra_Architecture\chat\`
- **시작**: `.\Start-MemorySystem.ps1 -ProjectScope Infra_Architecture`

### Governance 스코프
- **용도**: 정책, 문서화, 거버넌스, 표준화
- **채팅 위치**: `D:\Dev\DCEC\Governance\chat\`
- **시작**: `.\Start-MemorySystem.ps1 -ProjectScope Governance`

## 🔄 연속성 보장
1. **IDE 재시작 전**: 중요한 메모리 포인트를 추가해두세요
2. **IDE 재시작 후**: 해당 스코프로 메모리 시스템을 다시 초기화
3. **이전 맥락 복원**: `Resume-ConversationContext` 실행

## 💾 백업 및 내보내기
```powershell
# 메모리 스냅샷 내보내기 (최근 30일)
Export-MemorySnapshot -Days 30

# 특정 기간 검색
Search-ConversationHistory -SearchTerm "특정주제" -Days 7 -SearchScope "All"
```

## 🛠️ 현재 상태 (2025-07-06)
- ✅ 기본 메모리 시스템 구축 완료
- ✅ 프로젝트별 스코프 분리 완료  
- ✅ 채팅 로그 저장 및 검색 기능
- ⏳ 일부 고급 기능 개선 중 (Add-MemoryPoint 등)
- ⏳ DCECCore 모듈과의 완전한 통합

## 📞 사용 예시
```powershell
# 1. Dev_Env 스코프로 시작
.\Start-MemorySystem.ps1 -ProjectScope Dev_Env -ProjectName "CLI_QualityFix" -WorkContext "PowerShell_Debugging"

# 2. 작업 진행사항 기록
Add-MemoryPoint -Topic "create_project_dirs.ps1 수정" -Description "chat 디렉토리 구조 변경 완료" -Type "Solution"

# 3. 나중에 연속성을 위해 이전 작업 확인
Resume-ConversationContext
Search-ConversationHistory -SearchTerm "create_project_dirs" -Days 1
```

이제 DCEC Memory System이 CLI 환경의 연속성을 보장하며, IDE 재시작에도 대화 맥락을 유지할 수 있습니다! 🎯
