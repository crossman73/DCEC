# 통합 환경 변수 설정 모듈
function Initialize-IntegrationEnvironment {
    param(
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env/Env",
        [string]$LogType
    )
    $workflowEnv = @{
        "WORKFLOW_HOME" = "/mnt/d/Dev/DCEC/Integration"
        "WORKFLOW_LOGS" = "/mnt/d/Dev/DCEC/Integration/logs"
        "WORKFLOW_BACKUP" = "/mnt/d/Dev/DCEC/Integration/backup"
    }
    $backupEnv = @{
        "BACKUP_ROOT" = "/mnt/d/Dev/DCEC/BackupService"
        "BACKUP_SCHEDULE" = "daily"
        "BACKUP_RETENTION" = "30"
    }
    New-EnvFile -Path "$BaseDir/Integration/workflow.env" -EnvVars $workflowEnv -Description "워크플로우 통합 환경 변수" -LogType $LogType
    New-EnvFile -Path "$BaseDir/Integration/backup.env" -EnvVars $backupEnv -Description "백업 통합 환경 변수" -LogType $LogType
}
Export-ModuleMember -Function Initialize-IntegrationEnvironment
