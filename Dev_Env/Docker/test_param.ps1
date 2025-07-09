param(
    [string]$NasIP = "192.168.0.5",
    [string]$NasPort = "22022",
    [string]$NasUser = "crossman",
    [string]$LocalDir = "d:\Dev\DCEC\Dev_Env\Docker",
    [string]$RemoteDir = "/volume1/docker/",
    [string]$Command = "deploy",
    [string]$SshKeyPath = "",
    [switch]$NoPause
)