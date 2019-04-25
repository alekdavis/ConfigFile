<#
.SYNOPSIS
Example of a script using the ConfigFile module to import settings from a config file.

.NOTES
Version    : 1.1.0
Author     : Alek Davis
Created on : 2019-04-25
License    : MIT License
LicenseLink: https://github.com/alekdavis/ConfigFile/blob/master/LICENSE
Copyright  : (c) 2019 Alek Davis

.LINK
https://github.com/alekdavis/ConfigFile
#>

[CmdletBinding()]
param (
    # Will hold a non-empty string value from the config file.
    [string]
    $TestString = "StringFreeForm_Default",

    # Will hold a restricted string values from the config file.
    [ValidateSet("StringFromSet_Default","StringFromSet_Config","StringFromSet_Config_INI")]
    [string]
    $TestStringSet = "StringFromSet_Default",

    # Will hold the empty string value from the config file.
    [string]
    $TestStringEmpty = "StringEmpty_Default",

    # Will be treated as a literal string (without expansion).
    [string]
    $TestLiteralPSVariable = "$env:PROCESSOR_IDENTIFIER",

    # Will be treated as a literal string (without expansion).
    [string]
    $TestLiteralEnvironmentVariable = "%LOCALAPPDATA%",

    # Will hold the default string value (the config file value will be ignored).
    [string]
    $TestStringDefault = "StringDefault_Default",

    # Will hold the expanded environment variables from the config file.
    [string]
    $TestEnvironmentVariable = "%CommonProgramFiles%",

    # Will hold the expanded PowerShell variables from the config file.
    [string]
    $TestPSVariable = "$env:PROCESSOR_IDENTIFIER",

    # Will hold the expanded PowerShell variables from the config file with appended text.
    [string]
    $TestPSVariableEx = "$env:CommonProgramFiles",

    # This gets expanded correctly when script is launched from VS Code, but not from PowerShell.
    [string]
    $TestParamString1 = $null,

    # This gets expanded correctly when script is launched from VS Code, but not from PowerShell.
    [string]
    $TestParamString2 = $null,

    # This gets expanded correctly when script is launched from VS Code, but not from PowerShell.
    [string]
    $TestParamString3 = $null,

    # This gets expanded correctly when script is launched from VS Code, but not from PowerShell.
    [string]
    $TestParamString4 = $null,

    # Will hold the boolean value from the config file.
    [switch]
    $TestTrueOrFalse,

    # Will hold a positive integer from the config file.
    [ValidateRange(1,[int]::MaxValue)]
    [int]
    $TestNumber = 0
)

# Will hold a string array from the config file.
$TestArray = @(
    "StringArray_Default_1",
    "StringArray_Default_2"
)

$TestDate = (Get-Date)

"LOADING MODULE..."
$modulePath = Join-Path (Join-Path (Split-Path -Path $PSCommandPath -Parent) 'ConfigFile') 'ConfigFile.psm1'
Import-Module $modulePath -ErrorAction Stop -Force

"`nIMPORTING JSON CONFIG FILE..."
Import-ConfigFile -Json -DefaultParameters $PSBoundParameters

# Add a new element to the array.
$TestArray += "StringArray_Runtime_1_JSON"

# Display all script variables that start with 'Test'.
"`nJSON CONFIG APPLIED:"
Get-Variable -Scope Script | Where -Property Name -Match "^Test"

"`nIMPORTING INI CONFIG FILE..."
Import-ConfigFile -Ini -DefaultParameters $PSBoundParameters

# Add a new element to the array.
$TestArray += "StringArray_Runtime_1_INI"

# Display all script variables that start with 'Test'.
"`nINI CONFIG APPLIED:`n"
Get-Variable -Scope Script | Where -Property Name -Match "^Test"
