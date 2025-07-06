$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
& "$scriptDir\00_env_generate.ps1"
& "$scriptDir\01_structure_setup.ps1"
& "$scriptDir\02_git_init.ps1"
& "$scriptDir\03_dependency_init.ps1"
