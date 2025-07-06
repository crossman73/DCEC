# Python 환경 설정
# DCEC Python Environment Configuration

# Python 설치 기본 설정
$PythonConfig = @{
    # 기본 Python 버전
    DefaultVersion = "3.12.4"
    
    # 설치 경로
    InstallPath = "$env:LOCALAPPDATA\Programs\Python"
    
    # 백업 설치 경로들
    AlternatePaths = @(
        "$env:ProgramFiles\Python",
        "$env:ProgramFiles(x86)\Python",
        "C:\Python"
    )
    
    # 다운로드 소스
    DownloadSource = "https://www.python.org/ftp/python"
    
    # 필수 패키지 목록
    RequiredPackages = @(
        "pip",
        "setuptools", 
        "wheel",
        "requests",
        "virtualenv",
        "pip-tools"
    )
    
    # 개발 도구 패키지
    DevPackages = @(
        "black",
        "flake8",
        "pytest",
        "mypy",
        "pylint",
        "autopep8"
    )
    
    # AI/CLI 도구 패키지
    AIPackages = @(
        "openai",
        "anthropic-sdk",
        "google-generativeai",
        "click",
        "rich",
        "typer"
    )
    
    # 설치 옵션
    InstallOptions = @{
        AddToPath = $true
        InstallPip = $true
        InstallTcltk = $true
        InstallLauncher = $true
        InstallDocumentation = $false
        InstallDeveloperTools = $false
        InstallForAllUsers = $false
        PrependPath = $true
        AssociateFiles = $true
    }
}

# 환경 변수 설정
$EnvironmentConfig = @{
    # Python 관련 환경 변수
    Variables = @{
        "PYTHONPATH" = ""
        "PYTHONHOME" = ""
        "PYTHON_ENV" = "development"
        "PIP_CONFIG_FILE" = ""
        "PIP_CACHE_DIR" = "$env:LOCALAPPDATA\pip\cache"
    }
    
    # PATH 우선순위
    PathPriority = @(
        "$env:LOCALAPPDATA\Programs\Python\Python312\Scripts",
        "$env:LOCALAPPDATA\Programs\Python\Python312",
        "$env:LOCALAPPDATA\Programs\Python\Launcher"
    )
}

# 로깅 설정
$LoggingConfig = @{
    LogLevel = "INFO"
    LogPath = "$PSScriptRoot\..\logs"
    MaxLogSize = 10MB
    MaxLogFiles = 5
    LogFormat = "[$timestamp] [$level] [$component] $message"
}

# 검증 설정
$ValidationConfig = @{
    # 설치 후 검증할 명령어들
    ValidationCommands = @(
        @{ Command = "python"; Args = @("--version"); ExpectedPattern = "Python \d+\.\d+\.\d+" }
        @{ Command = "pip"; Args = @("--version"); ExpectedPattern = "pip \d+\.\d+\.\d+" }
        @{ Command = "py"; Args = @("--version"); ExpectedPattern = "Python \d+\.\d+\.\d+" }
    )
    
    # 필수 모듈 검증
    RequiredModules = @(
        "sys", "os", "json", "requests", "setuptools", "pip"
    )
    
    # 성능 테스트
    PerformanceTests = @{
        ImportTime = 5.0  # 초
        StartupTime = 2.0  # 초
    }
}

# 문제 해결 설정
$TroubleshootingConfig = @{
    # 일반적인 문제와 해결 방법
    CommonIssues = @{
        "PythonNotFound" = @{
            Description = "Python 명령어를 찾을 수 없음"
            Solutions = @(
                "PATH 환경 변수 확인",
                "Python 재설치",
                "py launcher 사용"
            )
        }
        "PipNotFound" = @{
            Description = "pip 명령어를 찾을 수 없음"
            Solutions = @(
                "python -m ensurepip 실행",
                "pip 재설치",
                "python -m pip 사용"
            )
        }
        "PermissionDenied" = @{
            Description = "권한 부족 오류"
            Solutions = @(
                "관리자 권한으로 실행",
                "사용자별 설치 사용",
                "--user 플래그 사용"
            )
        }
        "SSLError" = @{
            Description = "SSL 인증서 오류"
            Solutions = @(
                "pip --trusted-host 옵션 사용",
                "기업 방화벽 확인",
                "프록시 설정 확인"
            )
        }
    }
    
    # 진단 명령어
    DiagnosticCommands = @(
        "python --version",
        "pip --version", 
        "py --version",
        "where python",
        "where pip",
        "python -m site",
        "pip config list"
    )
}

# 설정 변수들을 전역 스코프로 설정
$Global:PythonConfig = $PythonConfig
$Global:EnvironmentConfig = $EnvironmentConfig  
$Global:LoggingConfig = $LoggingConfig
$Global:ValidationConfig = $ValidationConfig
$Global:TroubleshootingConfig = $TroubleshootingConfig

# 설정 내보내기
Export-ModuleMember -Variable PythonConfig, EnvironmentConfig, LoggingConfig, ValidationConfig, TroubleshootingConfig
