#!/usr/bin/env pwsh
# Taken from: https://github.com/ebekker/pwsh-github-action-base/blob/b19583aaecd66696896e9b7dbc9f419e2fca458b/lib/ActionsCore.ps1

## Adapted from:
##    https://github.com/actions/toolkit/blob/c65fe87e339d3dd203274c62d0f36f405d78e8a0/packages/core/src/core.ts

<#
.SYNOPSIS
Sets env variable for this action and future actions in the job.
.PARAMETER Name
The name of the variable to set
.PARAMETER Value
The value of the variable
.PARAMETER SkipLocal
Do not set variable in current action's/step's environment.
#>
function Set-ActionVariable {
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Name,
        [Parameter(Position = 1, Mandatory)]
        [string]$Value,
        [switch]$SkipLocal
    )

    ## To take effect only in the current action/step
    if (-not $SkipLocal) {
        [System.Environment]::SetEnvironmentVariable($Name, $Value)
    }

    ## To take effect for all subsequent actions/steps
    Send-ActionCommand set-env @{
        name = $Name
    } -Message $Value
}

<#
.SYNOPSIS
Registers a secret which will get masked from logs.
.PARAMETER Secret
The value of the secret.
#>
function Add-ActionSecretMask {
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Secret
    )

    Send-ActionCommand add-mask $Secret
}

<#
.SYNOPSIS
Prepends path to the PATH (for this action and future actions).
.PARAMETER Path
The new path to add.
.PARAMETER SkipLocal
Do not prepend path to current action's/step's environment PATH.
#>
function Add-ActionPath {
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Path,
        [switch]$SkipLocal
    )

    ## To take effect only in the current action/step
    if (-not $SkipLocal) {
        $oldPath = [System.Environment]::GetEnvironmentVariable('PATH')
        $newPath = "$Path$([System.IO.Path]::PathSeparator)$oldPath"
        [System.Environment]::SetEnvironmentVariable('PATH', $newPath)
    }

    ## To take effect for all subsequent actions/steps
    Send-ActionCommand add-path $Path
}

## Used to identify inputs from env vars in Action/Workflow context
if (-not (Get-Variable -Scope Script -Name INPUT_PREFIX -ErrorAction SilentlyContinue)) {
    Set-Variable -Scope Script -Option Constant -Name INPUT_PREFIX -Value 'INPUT_'
}

<#
.SYNOPSIS
Gets the value of an input.  The value is also trimmed.
.PARAMETER Name
Name of the input to get
.PARAMETER Required
Whether the input is required. If required and not present, will throw.
#>
function Get-ActionInput {
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Name,
        [switch]$Required
    )
    
    $cleanName = ($Name -replace ' ', '_').ToUpper()
    $inputValue = Get-ChildItem "Env:$($INPUT_PREFIX)$($cleanName)" -ErrorAction SilentlyContinue
    if ($Required -and (-not $inputValue)) {
        throw "Input required and not supplied: $($Name)"
    }

    return "$($inputValue.Value)".Trim()
}

<#
.SYNOPSIS
Returns a map of all the available inputs and their values.
.DESCRIPTION
Lookups in the returned map are case-insensitive, as per the
behavior of individual input lookup.
#>
function Get-ActionInputs {
    ## This makes sure the returned map looks up keys case-insensitively
    $inputsMap = [hashtable]::new([StringComparer]::OrdinalIgnoreCase)

    $envInputs = Get-ChildItem Env: | Where-Object { $_.Name.StartsWith($INPUT_PREFIX) }
    foreach ($ei in $envInputs) {
        $inputsMap[$ei.Name.Substring($INPUT_PREFIX.Length)] = $ei.Value
    }

    return $inputsMap
}

<#
.SYNOPSIS
Sets the value of an output.
.PARAMETER Name
Name of the output to set.
.PARAMETER Value
Value to store.
#>
function Set-ActionOutput {
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Name,
        [Parameter(Position = 1, Mandatory)]
        [string]$Value
    )

    Send-ActionCommand set-output @{
        name = $Name
    } -Message $Value
}

<#
.SYNOPSIS
TODO:  NOT IMPLEMENTED!
#>
function Set-ActionFailed {
    ## Not implemented for now...
    throw "Not Implemented"
}

<#
.SYNOPSIS
Writes debug message to user log.
.PARAMETER Message
Debug message
 #>
function Write-ActionDebug {
    param(
        [string]$Message = ""
    )

    Send-ActionCommand debug $Message
}

<#
.SYNOPSIS
Adds an error issue.
.PARAMETER Message
Error issue message
 #>
function Write-ActionError {
    param(
        [string]$Message = ""
    )

    Send-ActionCommand error $Message
}

<#
.SYNOPSIS
Adds a warning issue.
.PARAMETER Message
Warning issue message
 #>
function Write-ActionWarning {
    param(
        [string]$Message = ""
    )

    Send-ActionCommand warning $Message
}

<#
.SYNOPSIS
Writes info to log with console.log.
.PARAMETER Message
Info message
 #>
function Write-ActionInfo {
    param(
        [string]$Message = ""
    )

    ## Hmm, which one??
    #Write-Host "$($Message)$([System.Environment]::NewLine)"
    Write-Output "$($Message)$([System.Environment]::NewLine)"
}

<#
.SYNOPSIS
Begin an output group.
.DESCRIPTION
Output until the next `groupEnd` will be foldable in this group.
.PARAMETER Name
Name of the output group.
 #>
function Enter-ActionOutputGroup {
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Name
    )

    Send-ActionCommand group $Name
}

<#
.SYNOPSIS
End an output group.
 #>
function Exit-ActionOutputGroup {
    Send-ActionCommand endgroup
}

<#
.SYNOPSIS
Executes the argument script block within and output group.
.PARAMETER Name
Name of the output group.
.PARAMETER ScriptBlock
Script block to execute in between opening and closing output group.
#>
function Invoke-ActionWithinOutputGroup {
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Name,
        [Parameter(Position = 1, Mandatory)]
        [scriptblock]$ScriptBlock
    )

    Enter-ActionOutputGroup -Name $Name
    try {
        return $ScriptBlock.Invoke()
    }
    finally {
        Exit-ActionOutputGroup
    }
}


###########################################################################
## Internal Implementation - Private for Now...
###########################################################################

## Used to signal output that is a command to Action/Workflow context
if (-not (Get-Variable -Scope Script -Name CMD_STRING -ErrorAction SilentlyContinue)) {
    Set-Variable -Scope Script -Option Constant -Name CMD_STRING -Value '::'
}

<#
.SYNOPSIS
Sends a command to the hosting Workflow/Action context.
.DESCRIPTION
Command Format:
  ::name key=value;key=value##message

.EXAMPLE
::warning::This is the user warning message
.EXAMPLE
::set-secret name=mypassword::definitelyNotAPassword!
#>
function Send-ActionCommand {
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$Command,

        [Parameter(ParameterSetName = "WithProps", Position = 1, Mandatory)]
        [hashtable]$Properties,

        [Parameter(ParameterSetName = "WithProps", Position = 2)]
        [Parameter(ParameterSetName = "SkipProps", Position = 1)]
        [string]$Message = ''
    )

    if (-not $Command) {
        $Command = 'missing.command'
    }

    $cmdStr = "$($CMD_STRING)$($Command)"
    if ($Properties.Count -gt 0) {
        $cmdStr += ' '
        foreach ($key in $Properties.Keys) {
            $val = ConvertTo-EscapedValue -Value $Properties[$key]
            $cmdStr += "$($key)=$($val)"
        }
    }
    $cmdStr += $CMD_STRING
    $cmdStr += ConvertTo-EscapedData -Value $Message
    $cmdStr += [System.Environment]::NewLine

    return $cmdStr
}

function ConvertTo-EscapedData {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )
    return $Value.
    Replace("%", '%25').
    Replace("`r", '%0D').
    Replace("`n", '%0A')
}

function ConvertTo-EscapedValue {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )
    return $Value.
    Replace("%", '%25').
    Replace("`r", '%0D').
    Replace("`n", '%0A').
    Replace(':', '%3A').
    Replace(',', '%2C')
}

Export-ModuleMember `
    Add-ActionPath,
Add-ActionSecretMask,
Enter-ActionOutputGroup,
Exit-ActionOutputGroup,
Get-ActionInput,
Get-ActionInputs,
Invoke-ActionWithinOutputGroup,
Send-ActionCommand,
Set-ActionFailed,
Set-ActionOutput,
Set-ActionVariable,
Write-ActionDebug,
Write-ActionError,
Write-ActionInfo,
Write-ActionWarning
