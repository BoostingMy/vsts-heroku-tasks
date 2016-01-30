[CmdletBinding(DefaultParameterSetName = 'None')]
param(
    [String][Parameter(Mandatory = $true)] 
    $ApiKey,
    [String][Parameter(Mandatory = $true)] 
    $AppName,
    [String][Parameter(Mandatory = $true)] 
    $PushRoot,
    [String][Parameter(Mandatory = $false)] 
    $GitIgnore,
    [String][Parameter(Mandatory = $false)] 
    $CommitMessage,
    [String][Parameter(Mandatory = $false)] 
    $ForceOnPushing
)

# Code snippet from Server Fault by Nathan Chere
# http://serverfault.com/questions/565875/executing-a-git-command-using-remote-powershell-results-in-a-nativecommmanderror
# http://serverfault.com/users/60818/nathan-chere
function Invoke-GitCommand
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [String][Parameter(Mandatory = $true)] 
        $GitCommand,
        [bool][Parameter(Mandatory = $false)] 
        $OnlyDebug
    )

    $debugMode = ($Env:SYSTEM_DEBUG -eq "true")

    if($OnlyDebug -and -not($debugMode)){
        return $null;
    }

    $result  = Invoke-Expression "& $GitCommand 2>&1"

    $output = "$GitCommand"
    foreach($line in $result) {
        $val = "[git] "
        if($line.GetType().Name -eq "ErrorRecord") {
            if($line -match ".*error:.*" -or $line -match ".*fatal:.*"){
                throw ("$output`r`n[git] $line")
            }
            $val += $line.Exception.Message
        }else{
            $val += $line
        }
        
        $output = "$output`r`n$val"
    }
    
    return $output
}


$DebugMode = ($Env:SYSTEM_DEBUG -eq "true")
$debugInfo = @();

if(-not($GitIgnore) -or -not($GitIgnore -like "*node_modules*")){
    $GitIgnore = "node_modules"
}

if(-not($CommitMessage)){
    $ReleaseReleasename = $Env:RELEASE_RELEASENAME;
    $ReleaseReleasedescription = $Env:RELEASE_RELEASEDESCRIPTION;
    $CommitMessage = "Pushed from $ReleaseReleasename - $ReleaseReleasedescription."
}

$RequestedFor = $Env:RELEASE_REQUESTEDFOR;
$RequestedForEmail = "vsts@$AppName.git.heroku.com";

$ReleaseDirectory = $Env:AGENT_RELEASEDIRECTORY;
$GitDirectory = Join-Path -Path $ReleaseDirectory -ChildPath 'heroku'

$HerokuUrl = "https://vsts:$ApiKey@git.heroku.com:443/$AppName.git"

Write-Verbose "Entering script PushToHeroku.ps1" 
    Write-Verbose "Parameter Values"
    Write-Verbose "DebugMode = $DebugMode"
    Write-Verbose "ApiKey = $ApiKey" 
    Write-Verbose "AppName = $AppName" 
    Write-Verbose "PushRoot = $PushRoot"
    Write-Verbose "GitIgnore:"
    $GitIgnore -split '\r\n?|\n\r?' | %{ Write-Verbose "> $_" }
    Write-Verbose "CommitMessage = $CommitMessage"
    Write-Verbose "ForceOnPushing = $ForceOnPushing"
    Write-Verbose "RequestedFor = $RequestedFor"
    Write-Verbose "RequestedForEmail = $RequestedForEmail";
    Write-Verbose "HerokuUrl = $HerokuUrl"
    Write-Verbose "ReleaseDirectory = $ReleaseDirectory"
    Write-Verbose "GitDirectory = $GitDirectory"


Write-Host "Setting working directory to '$GitDirectory'"
    New-Item -Path $GitDirectory -ItemType Directory
    Set-Location $GitDirectory


Write-Host "Cloning heroku repository"
    Invoke-GitCommand -GitCommand "git clone $HerokuUrl"
    Write-Verbose "Files cloned: "
    Get-ChildItem -Recurse -Force | %{ Write-Verbose $_.FullName }
    $GitDirectory = Join-Path -Path $GitDirectory -ChildPath $AppName    
Write-Host "Heroku cloned"


Write-Host "Setting working directory to '$GitDirectory'"
    Set-Location $GitDirectory


Write-Host "Cleaning up files"
    Get-ChildItem -Recurse -Force  | `
        ?{ $_.FullName -notlike "*.git*" } | `
            Remove-Item -Force
            
    Write-Verbose "Files after cleaning up: "
    Get-ChildItem -Recurse -Force | %{ Write-Verbose $_.FullName }
Write-Host "Files cleaned"
    

Write-Host "Copying files from '$PushRoot'"
    Write-Verbose "Files to copy from '$PushRoot'"
    Get-ChildItem -Path $PushRoot -Recurse -Force | %{ Write-Verbose $_.FullName }

    $copyPath = Join-Path -Path $PushRoot -ChildPath '*'
    Write-Verbose "copyPath = $copyPath"
    
    Copy-Item $copyPath -Recurse -Force
    
    Write-Verbose "Files after copy: "
    Get-ChildItem -Recurse -Force | %{ Write-Verbose $_.FullName }
Write-Host "Files copied"
    

Write-Host "Writing .gitignore file"
    $GitIgnorePath = Join-Path -Path $PushRoot -ChildPath '.gitignore'
    $GitIgnore | Set-Content $GitIgnorePath
Write-Host ".gitignore written"


Write-Host "Initializing git config"
    Invoke-GitCommand -GitCommand "git config --local user.name `"$RequestedFor`""
    Invoke-GitCommand -GitCommand "git config --local user.email `"$RequestedForEmail`""
Write-Host "Git config initialized"


Write-Host "Adding files"
    Invoke-GitCommand -GitCommand "git add ."
Write-Host "Files added"


Write-Host "Committing changes"
    Invoke-GitCommand -GitCommand "git commit -m `"$CommitMessage`""
    Invoke-GitCommand -GitCommand "git status" -OnlyDebug $true
Write-Host "Changes committed"


Write-Host "Starting to push changes"
    if($ForceOnPushing -eq "true"){
        Invoke-GitCommand -GitCommand "git push -f origin master"
    } else {
        Invoke-GitCommand -GitCommand "git push origin master"
    }
Write-Host "Push finished."


Write-Verbose "Leaving script PushToHeroku.ps1"