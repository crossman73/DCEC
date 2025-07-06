# DCEC Python 환경 관리

DCEC 개발 환경에서 Python 설치, 검증, 관리를 위한 통합 도구입니다.

## 📁 디렉토리 구조

```
Python/
├── Scripts/                 # 실행 스크립트
│   ├── Manage-Python.ps1   # 통합 관리 스크립트 (메인)
│   ├── Install-Python.ps1  # Python 설치 스크립트
│   └── Test-PythonEnvironment.ps1  # 환경 검증 스크립트
├── config/                 # 설정 파일
│   └── PythonConfig.psm1   # Python 환경 설정
├── docs/                   # 문서 및 보고서
├── logs/                   # 로그 파일
├── lib/                    # 라이브러리 (향후 확장)
└── bin/                    # 바이너리 (향후 확장)
```

## 🚀 빠른 시작

### 1. Python 환경 상태 확인
```powershell
.\Scripts\Manage-Python.ps1 -Action Status
```

### 2. Python 설치
```powershell
# 기본 설치 (Python 3.12.4)
.\Scripts\Manage-Python.ps1 -Action Install

# 특정 버전 설치
.\Scripts\Manage-Python.ps1 -Action Install -PythonVersion "3.11.9"

# 강제 재설치
.\Scripts\Manage-Python.ps1 -Action Install -Force
```

### 3. 환경 검증
```powershell
# 기본 검증
.\Scripts\Manage-Python.ps1 -Action Validate

# 상세 검증 + 자동 수정
.\Scripts\Manage-Python.ps1 -Action Validate -Detailed -AutoFix
```

### 4. 문제 자동 수정
```powershell
.\Scripts\Manage-Python.ps1 -Action Repair
```

### 5. 패키지 업데이트
```powershell
.\Scripts\Manage-Python.ps1 -Action Update
```

### 6. 종합 보고서
```powershell
.\Scripts\Manage-Python.ps1 -Action Report
```

## 📋 주요 기능

### ✅ Python 설치
- 최신 Python 자동 다운로드 및 설치
- 사용자별 설치 (관리자 권한 불필요)
- PATH 자동 설정
- pip, Python Launcher 포함 설치
- 설치 전/후 검증

### 🔍 환경 검증
- Python/pip 명령어 실행 테스트
- 필수 모듈 import 테스트
- 성능 벤치마크 (시작 시간, import 시간)
- 환경 변수 및 PATH 확인
- 자동 문제 감지

### 🔧 자동 수정
- PATH 환경 변수 수정
- 누락된 패키지 자동 설치
- pip 업그레이드
- 환경 변수 복구

### 📊 보고서 생성
- JSON 형식 상세 보고서
- HTML 형식 환경 보고서
- 설치/검증 로그
- 성능 벤치마크 결과

## 🛠️ 고급 사용법

### 직접 스크립트 실행

#### Python 설치 스크립트
```powershell
.\Scripts\Install-Python.ps1 -PythonVersion "3.12.4" -Force -IncludePip -AddToPath
```

#### 환경 검증 스크립트
```powershell
.\Scripts\Test-PythonEnvironment.ps1 -Detailed -FixIssues -GenerateReport
```

### 설정 커스터마이징

`config\PythonConfig.psm1` 파일을 수정하여 다음을 조정할 수 있습니다:

- 기본 Python 버전
- 설치 경로
- 필수 패키지 목록
- 환경 변수 설정
- 검증 기준

## 📝 로그 및 보고서

### 로그 파일
- 위치: `logs/`
- 형식: `python_*.log`
- 자동 로테이션 (최대 5개 파일, 10MB)

### 보고서 파일
- 환경 보고서: `docs/python_environment_report.json`
- 검증 보고서: `docs/python_validation_report.json`
- HTML 보고서: `docs/python_environment_report.html`

## 🔧 문제 해결

### 일반적인 문제

#### "Python을 찾을 수 없습니다"
```powershell
# 해결 방법 1: PATH 확인
$env:PATH

# 해결 방법 2: Python Launcher 사용
py --version

# 해결 방법 3: 재설치
.\Scripts\Manage-Python.ps1 -Action Install -Force
```

#### "pip을 찾을 수 없습니다"
```powershell
# 해결 방법 1: python -m pip 사용
python -m pip --version

# 해결 방법 2: ensurepip 실행
python -m ensurepip --upgrade

# 해결 방법 3: 환경 수정
.\Scripts\Manage-Python.ps1 -Action Repair
```

#### "SSL 인증서 오류"
```powershell
# 해결 방법: trusted-host 옵션 사용
pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org <패키지명>
```

### 진단 명령어

```powershell
# 전체 환경 진단
.\Scripts\Manage-Python.ps1 -Action Validate -Detailed

# Python 경로 확인
where python
where pip
where py

# 환경 변수 확인
$env:PATH -split ';' | Where-Object { $_ -like "*python*" }

# 설치된 패키지 확인
pip list
```

## 📚 참고 자료

### Python 공식 문서
- [Python 설치 가이드](https://docs.python.org/3/using/windows.html)
- [pip 사용법](https://pip.pypa.io/en/stable/)
- [가상 환경](https://docs.python.org/3/tutorial/venv.html)

### DCEC 관련 문서
- [DCEC 개발 환경 가이드](../IDE/VScode/README.md)
- [CLI 도구 통합 가이드](../CLI/README.md)
- [PowerShell 모듈 가이드](../Powershell/README.md)

## 🤝 기여하기

이 Python 환경 관리 도구는 DCEC 프로젝트의 일부입니다. 

### 개발 환경 설정
1. PowerShell 7.0 이상 필요
2. 관리자 권한 권장 (설치 시)
3. 인터넷 연결 필요 (다운로드)

### 코드 기여
1. 함수명에는 `DCEC` 네임스페이스 접두사 사용
2. 모든 함수에 comment-based help 추가
3. 오류 처리 및 로깅 포함
4. PSScriptAnalyzer 규칙 준수

## 📋 할 일 목록

- [ ] 가상 환경 관리 기능 추가
- [ ] Python 버전 관리 (pyenv 스타일)
- [ ] 패키지 요구사항 파일 관리
- [ ] Docker 통합
- [ ] CI/CD 파이프라인 연동
- [ ] 자동 업데이트 확인
- [ ] GUI 관리 도구

## 📄 라이선스

이 프로젝트는 DCEC 개발 환경의 일부로 내부 사용을 위해 개발되었습니다.

---

**DCEC Python 환경 관리 v1.0**  
생성일: 2025-07-06  
업데이트: 2025-07-06
