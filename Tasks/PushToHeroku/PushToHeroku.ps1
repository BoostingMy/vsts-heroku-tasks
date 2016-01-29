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
        $val = ""
        if($line.GetType().Name -eq "ErrorRecord") {
            if($line -match ".*error:.*"){
                throw ($line)
            }
            $val = $line.Exception.Message
        }else{
            $val = $line
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

Write-Host "Setting working directory to '$PushRoot'"
    Set-Location $PushRoot


Write-Host "Writing .gitignore file"
    $GitIgnorePath = Join-Path -Path $PushRoot -ChildPath '.gitignore'
    $GitIgnore | Set-Content $GitIgnorePath


Write-Host "Initializing git"
    Invoke-GitCommand -GitCommand "git init"
    Invoke-GitCommand -GitCommand "git config --local user.name `"$RequestedFor`""
    Invoke-GitCommand -GitCommand "git config --local user.email `"$RequestedForEmail`""

Write-Host "Adding Heroku remote"
    Invoke-GitCommand -GitCommand "git remote add heroku $HerokuUrl"
    Invoke-GitCommand -GitCommand "git remote -v" -OnlyDebug $true


Write-Host "Adding files"
    Invoke-GitCommand -GitCommand "git add ."


Write-Host "Committing changes"
    Invoke-GitCommand -GitCommand "git commit -m `"$CommitMessage`""
    Invoke-GitCommand -GitCommand "git status" -OnlyDebug $true
    
    
Write-Host "Starting to push changes"
    if($ForceOnPushing -eq "true"){
        Invoke-GitCommand -GitCommand "git push -f heroku master"    
    } else {
        Invoke-GitCommand -GitCommand "git push heroku master"
    }
    
    Write-Host "Push finished."


Write-Verbose "Leaving script PushToHeroku.ps1"

throw ("Fake error")