# 워크플로우 관리 모듈
using namespace System.Collections.Generic
[CmdletBinding()]
param()
# 워크플로우 상태 저장
$script:WorkflowState = @{
    Services = [Dictionary[string, hashtable]]::new()
    Dependencies = [Dictionary[string, string[]]]::new()
    Status = [Dictionary[string, string]]::new()
}
function Initialize-WorkflowManager {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]${ConfigPath}
    )
    try {
        if (Test-Path -Path ${ConfigPath}) {
            $config = Get-Content -Path ${ConfigPath} | ConvertFrom-Json
            # 서비스 구성 로드
            foreach ($service in $config.Services) {
                $WorkflowState.Services[$service.Name] = @{
                    Path = $service.Path
                    Dependencies = $service.Dependencies
                    Status = 'Inactive'
                }
                if ($service.Dependencies) {
                    $WorkflowState.Dependencies[$service.Name] = $service.Dependencies
                }
            }
            Write-Log -Type 'WORKFLOW' -Message '워크플로우 관리자 초기화 완료' -Level 'SUCCESS'
            return $true
        }
        Write-Log -Type 'WORKFLOW' -Message '구성 파일을 찾을 수 없음' -Level 'ERROR'
        return $false
    }
    catch {
        Write-Log -Type 'WORKFLOW' -Message "워크플로우 초기화 실패: $_" -Level 'ERROR'
        return $false
    }
}
function Get-ServiceDependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]${ServiceName}
    )
    function Invoke-NodeTraversal {
        param([string]${Node})
        if ($visited.Contains(${Node})) {
            if ($processing.Contains(${Node})) {
                throw "순환 종속성 발견: $Node"
            }
            return
        }
        $visited.Add(${Node})
        $processing.Add(${Node})
        if ($WorkflowState.Dependencies.ContainsKey(${Node})) {
            foreach ($dep in $WorkflowState.Dependencies[${Node}]) {
                Invoke-NodeTraversal -Node $dep
                if (-not $order.Contains($dep)) {
                    $order.Add($dep)
                }
            }
        }
        $processing.Remove(${Node})
        if (-not $order.Contains(${Node})) {
            $order.Add(${Node})
        }
    }
    try {
        $visited = [HashSet[string]]::new()
        $processing = [HashSet[string]]::new()
        $order = [List[string]]::new()
        Invoke-NodeTraversal -Node ${ServiceName}
        return @{
            DependencyOrder = $order.ToArray()
            HasCycle = $false
        }
    }
    catch {
        Write-Log -Type 'WORKFLOW' -Message "종속성 분석 실패: $_" -Level 'ERROR'
        return @{
            DependencyOrder = @()
            HasCycle = $true
            Error = $_.Exception.Message
        }
    }
}
function Start-ServiceWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]${ServiceName}
    )
    try {
        $dependencies = Get-ServiceDependencies -ServiceName ${ServiceName}
        if ($dependencies.HasCycle) {
            throw "순환 종속성으로 인해 워크플로우를 시작할 수 없습니다."
        }
        foreach ($service in $dependencies.DependencyOrder) {
            if ($WorkflowState.Status[$service] -ne 'Active') {
                $serviceConfig = $WorkflowState.Services[$service]
                # 서비스 시작 로직
                Write-Log -Type 'WORKFLOW' -Message "서비스 시작 중: $service" -Level 'INFO'
                # 서비스별 초기화 함수 호출
                $initFunction = Get-Command -Name "Initialize-${service}Service" -ErrorAction SilentlyContinue
                if ($initFunction) {
                    & $initFunction -Path $serviceConfig.Path
                    $WorkflowState.Status[$service] = 'Active'
                    Write-Log -Type 'WORKFLOW' -Message "서비스 시작됨: $service" -Level 'SUCCESS'
                }
                else {
                    Write-Log -Type 'WORKFLOW' -Message "서비스 초기화 함수를 찾을 수 없음: $service" -Level 'ERROR'
                    return $false
                }
            }
        }
        return $true
    }
    catch {
        Write-Log -Type 'WORKFLOW' -Message "워크플로우 시작 실패: $_" -Level 'ERROR'
        return $false
    }
}
function Stop-ServiceWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]${ServiceName}
    )
    try {
        $dependencies = Get-ServiceDependencies -ServiceName ${ServiceName}
        [array]::Reverse($dependencies.DependencyOrder)
        foreach ($service in $dependencies.DependencyOrder) {
            if ($WorkflowState.Status[$service] -eq 'Active') {
                Write-Log -Type 'WORKFLOW' -Message "서비스 중지 중: $service" -Level 'INFO'
                # 서비스별 종료 함수 호출
                $stopFunction = Get-Command -Name "Stop-${service}Service" -ErrorAction SilentlyContinue
                if ($stopFunction) {
                    & $stopFunction
                    $WorkflowState.Status[$service] = 'Inactive'
                    Write-Log -Type 'WORKFLOW' -Message "서비스 중지됨: $service" -Level 'SUCCESS'
                }
                else {
                    Write-Log -Type 'WORKFLOW' -Message "서비스 종료 함수를 찾을 수 없음: $service" -Level 'WARNING'
                }
            }
        }
        return $true
    }
    catch {
        Write-Log -Type 'WORKFLOW' -Message "워크플로우 중지 실패: $_" -Level 'ERROR'
        return $false
    }
}
function Get-WorkflowStatus {
    [CmdletBinding()]
    param()
    return @{
        ActiveServices = @($WorkflowState.Status.Keys | Where-Object { $WorkflowState.Status[$_] -eq 'Active' })
        InactiveServices = @($WorkflowState.Status.Keys | Where-Object { $WorkflowState.Status[$_] -eq 'Inactive' })
    }
}
Export-ModuleMember -Function @(
    'Initialize-WorkflowManager',
    'Start-ServiceWorkflow',
    'Stop-ServiceWorkflow',
    'Get-WorkflowStatus'
)
