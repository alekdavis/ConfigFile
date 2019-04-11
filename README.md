# ConfigFile.psm1
This [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/overview) module allows you to import config file settings directly into the script variables.

## Cmdlet
The `ConfigFile` module exports the following cmdlet:

- Import-ConfigFile

### Import-ConfigFile
Use `Import-ConfigFile` to import settings from the script's config file directly into the corresponding parameters and variables. You can specify the path to the config file or leave cmdlet pick the default. The config file can have any type of data, including expandable variable, such as environment variables, like `%PATH%` or `$env:Path`. The cmdlet can ignore the parameters explicitly passed via command line.

#### Syntax

```PowerShell
Import-ConfigFile `
  [-ConfigFilePath <string>] `
  [[-Format {Json}] | [-Json]] `
  [-DefaultParameters <hashtable>] `
  [<CommonParameters>]
```

#### Arguments

`-ConfigFilePath`

Path to the config file. If the path is specified, the file must exist; otherwise, it is considered optional and, if not found, it will be ignored. The default config file path is named after the calling script with the `.json` extension. For example, if the path of the calling script is `C:\Scripts\MyScript.ps1`, the default config file path will be `C:\Scripts\MyScript.ps1`.

`-Format`

Format of the config file. At this time, only `Json` format is supported.

`-Json`

A shortcut for `-Format Json`.

`-DefaultParameters`

A hashtable holding the list of parameters that will not be imported from the config file. In most cases, you will want to pass the `$PSBoundParameters` value so that cmdlet ignores the parameters passed via command line. If you pass a custom hashtable, you only need to specify the keys.

`-<CommonParameters>`

Common PowerShell parameters (cmdlet is not using these explicitly).

#### Config file
A config file must be in the [JSON](https://www.json.org/) format, such as:

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
            "default": "Can hold expandable PowerShell variables (may need to use backtick char '`' to separate parameter from literal."
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
The `_meta` element describes the config file structure. It does not include any configuration settings. The important attributes of the `_meta` element are:

`version`

Can be used to handle future file schema changes.

`strict`

When set to `true`, every config setting that needs to be used must have the `hasValue` attribute set to `true`; if the `strict` element is missing orset to `false`, every config setting that gets validated by the PowerShell's if statement and resolves to `true` will be imported.

`prefix`

Identifies the prefix that indicates that the JSON element should not be processed. The default value is the underscore character.

The `_meta` elements are optional and can be used for improved readability. For example, they may include parameter descriptions, special instructions, default values, supported value sets, and so on. As long as they do not break the parser, feel free to use them at your convinience.

##### Limitations

While you can combine literals and expandable variables, do not combine environment variable notation and PowerShell expandable variables, such as `xxx%PATH%xxx$env:PROCESSOR_IDENTIFIER`xxx`, in the same parameter value.

Do not cross-reference other parameters (as illustrated in the example above). There seems to be a bug in PowerShell that would not expand variables under certain conditions (e.g. the expansion works fine when it is called from a script, or when running a script invoking the module in Visual Studio Code, but it fails when the module us invoked from a script running in the PowerShell command prompt).

#### Examples

##### Example 1 
```PowerShell
Import-ConfigFile -DefaultParameters $PSBoundParameters
```
Loads settings from the default config file into the script variables ignoring parameters explicitly passed via command line.

#### Example 2
```PowerShell
Import-ConfigFile
```
Checks if the default JSON config file exists, and if so, loads settings from the file into the script variables.

#### Example 3
```PowerShell
Import-ConfigFile -ConfigFilePath "C:\Scripts\MyScript.ps1.DEBUG.json" -DefaultParameters $PSBoundParameters
```
Loads settings from the specified config file into the script variables ignoring parameters explicitly passed via command line.
