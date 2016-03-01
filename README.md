# UnsignedBytes BuildTools
## PowerShell Build Tools for managing script projects

The UnsignedBytes BuildTools provides a way to manage your PS Modules
using a consistant structure and allows testing, 
dynamically generated manifest files, and packages your scripts
into a convenient zip file for transport. The entire configuration of the 
project is controlled by a single psproj.json file that guides the tool through
your project allowing the build to remain flexible.

Using the build tools is as simple as running `psbuild` from the module project root. This will result in a nice little `.zip` package that includes your module, any `about_*` documentation as well as an auto-generated manifest file.

*Notice: ScriptCop Integration is currently disabled due to a few issues that were causing the analysis to be flaky.*

### Install Module

In order to use the Build Tools you must install them to the powershell modules directory. Grab the latest UnsignedBytes.BuildTools-x.x.x.zip file from the `dist` folder of the latest release tag and unzip the contents to:
```PowerShell
%HOMEPATH%\Documents\WindowsPowerShell\Modules\
```
Note that the folder inside Modules that contains the artifacts __MUST__ have the same name as the module or it will not load.

### Create a project file and configure your module

Create a new folder for your project, and create folders within it to store your module source, tests, and the distributable zipped artifacts.
```PowerShell
mkdir MyProject
cd MyProject
mkdir src
mkdir dist
mkdir tests
```

Create a new psproj.json file in the new project directory and add the following to the file.  
*Update to use your information*

```json
{
	"projectName": "My Fancy New Project",
	"uniqueId": "9cb01216-d85b-49e7-a501-bb22d3a94046",
	"companyName": "My Company, Inc.",
	"version": "3.1.1",
	"description": "My summary description of the project",
	"authors": [
		"Timmy Developer <timmy@testdeveloper.com>"
	],
	"dotNetVersion": "4.5",
	"powerShellVersion": "4.0",
	"src": "src",
	"dist": "dist",
	"tests": "tests"
}
```
* The `src`, `dist`, and `tests` properties represent the three project directories created earlier
and can be overridden to point to any relative path e.g. `"dist": "Bin"` would indicate that the
Bin directory should be used to hold your distributable artifacts after a build.
* The uniqueId field is a unique identifier that will be used in the psd1 manifest file.

There is a built in project generator to flesh out the project struction that
can be run by using the  `psinit` command. The command will run a wizard to 
setup some of the parameters and generates the project.json, and the src,dist,
and tests folders.

### Add Your Module and about_* files

Add your `.psm1` module file and `about_*` help files into the src directory.

### Add Tests

Add any powershell tests with the format `*.Test.ps1` to the tests directory. See the tests for this project if you'd like an example.

### Build Your Module

Run the `psbuild` or Invoke-PSBuild command to build the zip package for your module. The `.zip` will 
be found in the `dist` directory. See Get-Help Invoke-PSBuild for more details.

### Contributers
Contributions to the project are very welcome, so feel free to send me a pull request. This is a very new project and I have many ideas I'm tossing around for it and I would also like to hear some from anyone else who finds this useful.

**Prerequisites:** ~~ScriptCop (http://scriptcop.start-automating.com/)~~ Currently Disabled

**Setup**
```PowerShell
git clone https://github.com/unsignedbytes/UBBuildTools/
cd ./UBBuildTools/
ipmo ./src/UnsignedBytes.BuildTools.psm1 
Invoke-PSBuild -ProjectRoot ./ -ModuleName UnsignedBytes.BuildTools
```
**Installing**

If you would like to install the module to the default modules directory you can run...
```PowerShell
psinstall
```
or
```PowerShell
Invoke-PSInstall
```
...from the project root. It will overwrite the module if it is already installed.

### Misc

For more information about the module see:
```PowerShell
Get-Help about_UnsignedBytes.BuildTools
```

Each of the build stages are exposed through the modules as well as the main Invoke-PSBuild Cmdlet. 
Use the following to see all available Cmdlets:
```PowerShell
Get-Command -Module UnsignedBytes.BuildTools
```
Use Get-Help to view the help file for any specific Cmdlet.
