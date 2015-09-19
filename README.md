# UnsignedBytes BuildTools
## PowerShell Build Tools for managing script projects

The UnsignedBytes BuildTools provides a way to manage your PS Modules
using a consistant structure and allows testing, 
dynamically generated manifest files, and packages your scripts
into a convenient zip file for transport. The entire configuration of the 
project is controlled by a single psproj.json file that guides the tool through
your project allowing the build to remain flexible.

*Notice: ScriptCop Integration is currently Disabled due to a slew of issues that were causing the analysis to be flaky.*

**To Build:**

Building this project is not required to use it. You can just download the
zip file for the version you would like from the dist directory of the release of your choice 
on the releases tab in github.

Prerequisites: ScriptCop (http://scriptcop.start-automating.com/) (NOTE: Currently disabled)

```PowerShell
git clone https://github.com/unsignedbytes/UBBuildTools/
cd ./UBBuildTools/
ipmo ./src/UnsignedBytes.BuildTools.psm1 
Invoke-PSBuild -ProjectRoot ./ -ModuleName UnsignedBytes.BuildTools
```

**To Install:**

Grab the latest UnsignedBytes.BuildTools-x.x.x.zip file to get all the required
artifacts and unzip the contents to:
```PowerShell
%UserProfile%\Documents\WindowsPowerShell\Modules\UnsignedBytes.BuildTools\
```

**Create a Project File:**

Create a new folder for your project
```PowerShell
mkdir MyProject
cd MyProject
mkdir src
mkdir dist
mkdir tests
```

Create a new psproj.json file in the new project directory and add the following to the file.
*Update to use your information*.

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
* The src, dist, and tests properties represent the three project directories created earlier
and can be overridden to point to any relative path e.g. "dist": "Bin" would indicate that the
Bin directory should be used to hold your distributable artifacts after a build.

* The uniqueId field is a unique identifier that will be used in the psd1 manifest file.

**Add Your Module and about_* files:**

Add your .psm1 files and about_* help files into the src directory.

**Add Tests:**

Add any powershell tests with the format *.Test.ps1 to the tests directory

**Build:**

Run the Invoke-PSBuild command to build the zip package for your module. See Get-Help Invoke-PSBuild for more details.

**Misc:**

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
