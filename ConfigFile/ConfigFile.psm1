<#
.SYNOPSIS
PowerShell commandlet loading settings from a config file into the calling
script's command-line parameters and variables.

.LINK
https://github.com/alekdavis/ConfigFile
#>

#Requires -Version 4.0

<#
.SYNOPSIS
Sets script parameters and variables using the values in a config file.

.DESCRIPTION
Use this function to load script settings from a config file.

The function will iterate through elements of the config file and, if the value
is set, it will use it to set the script parameter or variable with the same
name.

For the sample of the config file and the explanation of the file structure,
see online help.

.PARAMETER ConfigFilePath
Path to the config file. If not specified, the config file is considered
optional (if the default config file is not found, no error will be returned).
The default config file is named after the calling script with the appended
extension reflecting the format, e.g. for the script with the name 'MyScript.ps1',
the default JSON config file will be 'MyScript.ps1.json' located in the same
folder.

.PARAMETER Format
Either Json or Ini.

.PARAMETER Json
Shortcut for '-Format Json'.

.PARAMETER Ini
Shortcut for '-Format Ini'.

.PARAMETER DefaultParameters
Holds a hashtable with parameters that will not be imported. To ignore parameters
initialized via command line pass the $PSBoundParameters variable. When passing
a custom hashtable, you only need to specify the keys.

.EXAMPLE
Import-ConfigFile
Checks if the default JSON config file exists, and if so, loads settings from
the file into the script variables.

.EXAMPLE
Import-ConfigFile -Ini
Checks if the default INI config file exists, and if so, loads settings from
the file into the script variables.

.EXAMPLE
Import-ConfigFile -ConfigFilePath "C:\Scripts\MyScript.ps1.DEBUG.json"
Loads settings from the specified JSON config file into the script variables.

.EXAMPLE
Import-ConfigFile -ConfigFilePath "C:\Scripts\MyScript.ps1.DEBUG.ini"
Loads settings from the specified INI config file into the script variables.

.EXAMPLE
Import-ConfigFile -DefaultParameters $PSBoundParameters
Loads settings from the default config file into the script variables
ignoring parameters explicitly passed via command line.

.LINK
https://github.com/alekdavis/ConfigFile
#>

function Import-ConfigFile {
    [CmdletBinding(DefaultParameterSetName="Default")]
    param (
        [string]
        $ConfigFilePath = $null,

        [Parameter(ParameterSetName="Format")]
        [ValidateSet("", "Json", "Ini")]
        [string]
        $Format = "",

        [Parameter(ParameterSetName="Json")]
        [switch]
        $Json,

        [Parameter(ParameterSetName="Ini")]
        [switch]
        $Ini,

        [Hashtable]
        $DefaultParameters = $null
    )

    # Allow module to inherit '-Verbose' flag.
    if (($PSCmdlet) -and (-not $PSBoundParameters.ContainsKey('Verbose'))) {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    # Allow module to inherit '-Debug' flag.
    if (($PSCmdlet) -and (-not $PSBoundParameters.ContainsKey('Debug'))) {
        $DebugPreference = $PSCmdlet.GetVariableValue('DebugPreference')
    }

    # If config file was explicitly specified, make sure it exists.
    if ($ConfigFilePath) {
        if (!(Test-Path -Path $ConfigFilePath -PathType Leaf)) {
            throw "Config file '" + $ConfigFilePath + "' is not found."
        }

        # If format is not specified, map it to the file extension.
        if (!$Format -and !$Json -and !$Ini) {
            $ext = [System.IO.Path]::GetExtension($ConfigFilePath)

            if ($ext) {
                $Format = $ext.Replace(".", "")
            }
        }
    }
    # If path is not specified, use the default (script + .json extension).
    else {
        # Default config file is named after running script with .json extension.

        # First try the invoking script.
        $ConfigFilePath = $PSCommandPath

        # If the invoking script is a module, check the caller.
        if ($PSCmdlet) {
            $ConfigFilePath = $MyInvocation.PSCommandPath
        }

        # Set appropriate format.
        if (!$Format) {
            if ($Ini) {
                $Format = "Ini"
            }
            else {
                $Format = "Json"
            }
        }

        $ext = ".$Format".ToLower()

        $ConfigFilePath += $ext

        # Default config file is optional.
        if (!(Test-Path -Path $ConfigFilePath -PathType Leaf)) {

            Write-Verbose "Config file '$ConfigFilePath' is not found."
            return
        }
    }

    $count = 0
    Write-Verbose "Loading config file '$ConfigFilePath'."

    # Process JSON file.
    if ($Format -eq "Json") {
        $jsonString = Get-Content $ConfigFilePath -Raw `
        -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue

        if (!$jsonString) {
            Write-Verbose "Config file is empty."
            return
        }

        Write-Verbose "Converting config file settings into a JSON object."
        $jsonObject = $jsonString | ConvertFrom-Json `
            -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue

        if (!$jsonObject) {
            Write-Verbose "Cannot convert config file settings into a JSON object."
            return
        }

        $strict = ($jsonObject._meta.strict -or $jsonObject.meta.strict)
        $prefix = $jsonObject._meta.prefix
        if (!$prefix) {
            $jsonObject.meta.prefix
        }
        if (!$prefix) {
            $prefix = "_"
        }

        # Process elements twice: first, literals, then the ones that require expansion.
        # Technically, when using the module, one pass would suffice, since the only
        # supported expandable values are environment variables (%%) or PowerShell
        # environment variables ($env:) and these can be resolved in a single pass.
        # But in case this function is copied into and used directly from a script
        # (not from a module), the second pass is needed in case a value references
        # a script variable. Again, keep in mind that script variable expansion is not
        # supported when using the module.
        for ($i=0; $i -lt 2; $i++) {
            $jsonObject.PSObject.Properties | ForEach-Object {

                # Copy properties to variables for readability.
                $hasValue   = $_.Value.hasValue
                $name       = $_.Name
                $value      = $null
                $value      = $_.Value.value

                # In ForEach-Object loops 'return' acts as 'continue' in  loops.
                if ($name.StartsWith($prefix)) {
                    # Skip to next (yes, 'return' is the right statement here).
                    return
                }

                # If 'hasValue' is explicitly set to 'false', ignore element.
                if ($hasValue -eq $false) {
                    return
                }

                # Now, the 'hasValue' is either missing or is set to 'true'.

                # In the strict mode, 'hasValue' must be set to include the element.
                if ($strict -and ($null -eq $hasValue)) {
                    return
                }

                # If 'hasValue' is not set and the value resolves to 'false', ignore it.
                if (($null -eq $hasValue) -and (!$value)) {
                    return
                }

                # Check if parameter is specified on command line.
                if ($DefaultParameters) {
                    if ($DefaultParameters.ContainsKey($name)) {
                        return
                    }
                }

                # Okay, we must use the value.

                # The value must be expanded if it:
                # - is not marked as a literal,
                # - has either '%' or '$' character (not the $ end-of-line special character),
                # - is neither of PowerShell constants that has a '$' character in name
                #   ($true, $false, $null).
                if ((!$_.Value.literal) -and
                    (($value -match "%") -or ($value -match "\$")) -and
                    ($value -ne $true) -and
                    ($value -ne $false) -and
                    ($null -ne $value)) {

                    # Skip on the first iteration in case it depends on the unread variable.
                    if ($i -eq 0) {
                        $name = $null
                    }
                    # Process on second iteration.
                    else {
                        if ($value -match "%") {

                            # Expand environment variable.
                            $value = [System.Environment]::ExpandEnvironmentVariables($value)
                        }
                        else {
                            # Expand PowerShell variable.
                            $value = $ExecutionContext.InvokeCommand.ExpandString($value)
                        }
                    }
                }
                else {
                    # Non-expandable variables have already been processed in the first iteration.
                    if ($i -eq 1) {
                        $name = $null
                    }
                }

                if ($name) {
                    if ($count -eq 0) {
                        Write-Verbose "Setting variable(s):"
                    }

                    Write-Verbose "-$name '$value'"

                    if ($PSCmdlet) {
                        $PSCmdlet.SessionState.PSVariable.Set($name, $value)
                    }
                    else {
                        Set-Variable -Scope Script -Name $name -Value $value -Force -Visibility Private
                    }

                    $count++
                }
            }
        }
    }
    # Process INI file.
    else {
        # Hash table to hold contents of the INI file.
        $iniData = @{}

        # Process all lines in the INI file and save the contents in a hash.
        switch -regex -file $ConfigFilePath
        {
            # If the line starts with a non-alphanumeric character...
            "^\s*[^a-zA-Z\d]" {
                # ...ignore it (it must be a comment or a section)
            }
            # Process name=value pair. The format is like:
            #   name=value
            #   name~=%value% (~ indicates that the string is literal and should not be expanded)
            #   name`=$value (` indicates that the string is literal and should not be expanded)
            #   name;=value1;value2;value3 (; is used as a delimeter for array elements)
            #   name@@@=value1@@@value2@@@value3 (@@@ is used as a delimeter for array elements)
            # and so on.
            # A special character (or a string of special characters) before the equal sign
            # can be used as an indicator that the value should not be expanded (either ` or ~
            # can be used for this) or contain the delimeter for array elements. Notice that
            # white spaces will not be trimmed from the value(s).
            "^\s*([a-zA-Z\d]+)\s*([^\sa-zA-Z\d=]*)=(.*)" {
                $name,$delimeter,$value = $matches[1..3]

                # Check if parameter is specified on command line.
                if ($DefaultParameters) {
                    if ($DefaultParameters.ContainsKey($name)) {
                        continue
                    }
                }

                $iniData[$name] = $value, $delimeter
            }
        }

        # Process in two steps in case we need to expand environment variables.
        for ($i=0; $i -lt 2; $i++) {
            foreach ($name in $iniData.Keys) {
                $value     = $iniData[$name][0]
                $delimeter = $iniData[$name][1]

                # Expandible string contains % or $, does not hold the built-in
                # PowerShell boolean or null values, and does not have a delimeter
                # indicator characters (` or ~) in front of the equal sign.
                if ((($value -match "%") -or ($value -match "\$")) -and
                    ($value -ne $true) -and
                    ($value -ne $false) -and
                    ($null -ne $value) -and
                    ($delimeter -notin '`', '~')) {

                    # Skip on the first iteration in case it depends on the unread variable.
                    if ($i -eq 0) {
                        $name = $null
                    }
                    # Process on second iteration.
                    else {
                        if ($value -match "%") {
                            # Expand environment variable.
                            $value = [System.Environment]::ExpandEnvironmentVariables($value)
                        }
                        else {
                            # Expand PowerShell variable.
                            $value = $ExecutionContext.InvokeCommand.ExpandString($value)
                        }
                    }
                }
                else {
                    # Non-expandable variables have already been processed in the first iteration.
                    if ($i -eq 1) {
                        $name = $null
                    }
                }

                if ($name) {
                    $var = $null

                    if ($PSCmdlet) {
                        $var =  $PSCmdlet.SessionState.PSVariable.Get($name)
                    }
                    else {
                        #$var =  Get-Variable -Scope Script -Name $name -Visibility Public
                        $var =  Get-Variable -Scope Script -Name $name
                    }

                    if ($var) {
                        if ($count -eq 0) {
                            Write-Verbose "Setting variable(s):"
                        }

                        Write-Verbose "-$name '$value'"

                        # Process an array variable.
                        if ($var.Value -is [Array]) {
                            # If there is no delimeter specified, use comma.
                            if (!$delimeter) {
                                $delimeter = ','
                            }
                            $var.Value = $value -split $delimeter
                        }
                        # Process a boolean or a switch variable.
                        elseif (($var.Value -is [Boolean]) -or ($var.Value -is [Switch])) {
                            $var.Value = $value -notin 'false', '$false', '0', ''
                        }
                        # Process any other data type.
                        else {
                            $var.Value = [System.Management.Automation.LanguagePrimitives]::ConvertTo($value, $var.Value.GetType())
                        }

                        # Count the number of processed variables.
                        $count++
                    }
                }
            }
        }
    }

    if ($count -gt 0) {
        Write-Verbose "Done setting $count variable(s) from the config file."
    }
}

Export-ModuleMember -Function *
