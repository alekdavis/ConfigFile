# ConfigFile.psm1
This [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/overview) module allows you to import config file settings directly into the script variables.

## Cmdlet
The `ConfigFile` module exports the following cmdlet:

- Import-ConfigFile

### Import-ConfigFile
Use `Import-ConfigFile` to import settings from the script's config file directly into the parameters and variables with the matching names. You can specify the path to the config file or leave cmdlet pick the default. The config file can have any type of data, including expandable variable, such as environment variables, like `%PATH%` or `$env:Path`. The cmdlet can ignore the parameters explicitly passed via command line.

#### Syntax

```PowerShell
Import-ConfigFile `
  [-ConfigFilePath <string>] `
  [[-Format {Json|Ini}] | [-Json] | [-Ini]] `
  [-DefaultParameters <hashtable>] `
  [<CommonParameters>]
```

#### Arguments

`-ConfigFilePath`

Path to the config file. If the path is specified, the file must exist; otherwise, it is considered optional and, if not found, it will be ignored. The default config file path is named after the calling script with the `.json` extension. For example, if the path of the calling script is `C:\Scripts\MyScript.ps1`, the default config file path will be `C:\Scripts\MyScript.ps1.json`.

`-Format`

Format of the config file: `Json` (default) or `Ini`.

`-Json`

A shortcut for `-Format Json`.

`-Ini`

A shortcut for `-Format Ini`.

`-DefaultParameters`

A hashtable holding the list of parameters that will not be imported from the config file. In most cases, you will want to pass the `$PSBoundParameters` value so that cmdlet ignores the parameters passed via command line. If you pass a custom hashtable, you only need to specify the keys.

`-<CommonParameters>`

Common PowerShell parameters (cmdlet is not using these explicitly).

#### Config file
A config file must be in the JSON or INI format.

##### JSON config file
A JSON config file must comply with the  [JSON](https://www.json.org/) specifications and must be in the format similar to this:

```JavaScript
{
    "_meta": {
        "version": "1.0",
        "strict": false,
        "prefix": "_"
    },
    "SimpleStringParam": {
        "_meta": {
            "comment": "Any literal string (special characters, such as backslashes, must be escaped)."
        },
        "value": "D:\\MyApp\\Data"
    },
    "EmptyStringParam": {
        "_meta": {
            "comment": "Parameter that resolve by PowerShell as false (false, null, empty string) must have the 'hasValue' element set to 'true'."
        },
        "hasValue": true,
        "value": ""
    },
    "NullStringParam": {
        "_meta": {
            "comment": "Same as above."
        },
        "hasValue": true,
        "value": null
    },
    "DefaultValueParam": {
        "_meta": {
            "comment": "To ignore parameter that resolve by PowerShell as true (non-empty strings, etc.) set the 'hasValue' element to 'false'."
        },
        "hasValue": false,
        "value": "This value will be ignored."
    },
    "LiteralStringWithSpecialCharsParam": {
        "_meta": {
            "comment": "Literal strings with characters '%' and '$' must have the 'literal' element set to 'true'."
        },
        "literal": true,
        "value": "100%"
    },
    "EnvironmentVariableParam": {
        "_meta": {
            "comment": "Can hold environment variables."
        },
        "value": "xxx%CommonProgramFiles%xxx"
    },
    "PSVariableParam": {
        "_meta": {
            "comment": "Can hold expandable PowerShell variables (may need to use backtick char '`' to separate parameter from literal."
        },
        "value": "xxx$env:PROCESSOR_IDENTIFIER`xxx"
    },
    "ParamRefParam": {
        "_meta": {
            "comment": "You would expect this one to hold the value of SimpleStringParam, but in most cases, it would not (probably due to a bug in PowerShell), so don't do it."
        },
        "value": "$SimpleStringParam"
    },
    "BoolParam": {
        "value": true
    },
    "IntParam": {
        "value": "1000"
    },
    "StringArrayParam": {
        "value": ["String #1", "String #2", "and so on..."]
    }
}
```

###### \_meta element
The root `_meta` element describes the config file structure. It does not include any configuration settings. The important attributes of the `_meta` element are:

`version`

Can be used to handle future file schema changes.

`strict`

When set to `true`, every config setting that needs to be used must have the `hasValue` attribute set to `true`; if the `strict` element is missing orset to `false`, every config setting that gets validated by the PowerShell's if statement and resolves to `true` will be imported.

`prefix`

Identifies the prefix that indicates that the JSON element should not be processed. The default value is the underscore character.

The non-root `_meta` elements are optional and can be used for improved readability. For example, they may include parameter descriptions, special instructions, default values, supported value sets, and so on. As long as they do not break the parser, feel free to use them at your convinience.

###### Data elements

All elements other than `_meta` are expected to contain data values assigned to the `value` properties. By default, all elements holding non-empty, non-null, non-false data are considered to contain values. If an element's `value` property contains a null, empty, or false value, it will be ignored. To include a null, empty, or false value, set the `hasValue` property to `true`. To exclude an element with a non-empty, non-null, non-false values, set the `hasValue` property to `false`. All other properties are optional and can be ignored. 

##### INI config file

An INI config file is intended for simple configuration settings. The format must follow the standard [INI](https://en.wikipedia.org/wiki/INI_file) file specifications with a few possible adjustments. The following rules apply to the INI config files:

- White spaces in the beginning of the strings will be discarded.
- White spaces before the first equal sign will be discarded.
- White spaces following the first equal sign will not be discarded.
- If the first non-space character in the line is non-alphabetic, the line is treated as a comment.
- Comments cannot be in-line (only the whole line is considered a comment).
- Lines containing `name=value` pairs can contain expandable elements (just like in the JSON config files).
- Names must be alpha-numeric.
- Values may contain equal signs.
- A single backtick or a tilde character immediately preceding the first equal sign  (`` `= ``, ` ~= `) indicates that the value possibly coontaning expansion characters (`%`, `$`) should not be expanded and must be treated as a literal.
- Any non-space, non-alhanumeric character or collection of characters, with the exception of the backtick and tilde characters, immediately preceding the first equal sign (e.g `,=`, `;=`, `###=`, `@@=`, and so on) will be used as a delimeter for the array elements specified in the value (comma is the default delimeter and does not need to be explicitly specified).
- Only primitive data types are supported: strings, expansion strings, numeric, boolean, dates, and string arrays.

The following is an example of an INI file with the settings matching the [JSON config sample](#json-config-file) above:

```TXT
; SAMPLE INI FILE

TestString=StringFreeForm_Config_INI
TestStringSet=StringFromSet_Config_INI
TestStringEmpty=$null
TestLiteralPSVariable`=$env:PROCESSOR_IDENTIFIER|$env:PROCESSOR_LEVEL
TestLiteralEnvironmentVariable~=%CommonProgramFiles%|%ProgramFiles%
TestStringDefault=StringDefault_Config_INI
TestEnvironmentVariable=%CommonProgramFiles%|%ProgramFiles%
TestPSVariable=$env:PROCESSOR_IDENTIFIER|$env:PROCESSOR_LEVEL
TestPSVariableEx=XXX$env:CommonProgramFiles`XXX
TestParamString1=$TestString
TestParamString2=XXX$TestStringXXXZZZ$TestStringSetZZZ
TestParamString3=XXX$TestString`XXXZZZ$TestStringSet`ZZZ
TestParamString4=XXX`$TestString`XXXZZZ`$TestStringSet`ZZZ
TestTrueOrFalse=true
TestNumber=1000
TestArray=StringArray_Config_1_INI,StringArray_Config_2_INI
TestDate=2017-12-31 13:24:32.198
```

#### Limitations

While you can combine literals and expandable variables, do not combine environment variable notation and PowerShell expandable variables, such as `%PATH%|$env:PROCESSOR_IDENTIFIER`, in the same parameter value.

Do not cross-reference other parameters (as illustrated in the example above). There seems to be a bug in PowerShell that causes variables to not expand under certain conditions (e.g. the expansion works fine when it is called from a script, or when running a script invoking the module in Visual Studio Code, but it fails when the module us invoked from a script running in the PowerShell command prompt). There is a chance that this is a bug in PowerShell that will be fixed, so use your own judgement and test, test, test.

#### Usage

You can download a copy of the module from this Github repository or install it from the [PowerShell Gallery](https://www.powershellgallery.com/packages/ConfigFile) (see [Examples](#Examples)).

#### Examples

##### Example 1
```PowerShell
function LoadModule {
    param(
        [string]
        $ModuleName
    )

    if (!(Get-Module -Name $ModuleName)) {

        if (!(Get-Module -Listavailable -Name $ModuleName)) {
            Install-Module -Name $ModuleName -Force -Scope CurrentUser -ErrorAction Stop
        }

        Import-Module $ModuleName -ErrorAction Stop -Force
    }
}

$modules = @("ConfigFile")
foreach ($module in $modules) {
    try {
        LoadModule -ModuleName $module
    }
    catch {
        throw (New-Object System.Exception "Cannot load module $module.", $_.Exception)
    }
}
```
Downloads the `ConfigFile` module from the [PowerShell Gallery](https://www.powershellgallery.com/packages/ConfigFile) into the PowerShell modules folder for the current user and imports it into the running script.

##### Example 2
```PowerShell
$modulePath = Join-Path (Split-Path -Path $PSCommandPath -Parent) 'ConfigFile.psm1'
Import-Module $modulePath -ErrorAction Stop -Force
```
Imports the `ConfigFile` module from the same directory as the running script.

##### Example 3
```PowerShell
Import-ConfigFile
```
Checks if the default JSON config file exists, and if so, loads settings from the file into the script variables.

##### Example 4
```PowerShell
Import-ConfigFile -Ini
```
Checks if the default INI config file exists, and if so, loads settings from the file into the script variables.

##### Example 5
```PowerShell
Import-ConfigFile -DefaultParameters $PSBoundParameters
```
Checks if the default JSON config file exists, and if so, loads settings from the file into the script variables ignoring parameters explicitly passed via command line.

##### Example 6
```PowerShell
Import-ConfigFile -ConfigFilePath "C:\Scripts\MyScript.ps1.DEBUG.json" -DefaultParameters $PSBoundParameters
```
Loads settings from the specified config file into the script variables ignoring parameters explicitly passed via command line.
