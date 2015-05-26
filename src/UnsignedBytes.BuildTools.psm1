#region Functions
Function Get-PSProjectProperties {
	<#
	.SYNOPSIS
		Gets some useful properties about a powershell project
	.DESCRIPTION
		This function looks in the specified project directory
		for the psproj.json file to create a set of project data that
		describes the project.
	.PARAMETER ProjectRoot
		The root path to the powershell project
	.EXAMPLE
		Get-PSProjectProperties -ProjectRoot ./project/path/
		Gets the PowerShell project property data from the project at ./project/path
	#>
	[CmdletBinding()]
	param (
		[Parameter(
			Mandatory=$True,
			ValueFromPipeline=$True
		)]
		[ValidateScript({ Test-Path "$_/psproj.json" })]
		[string] $ProjectRoot
	)
	PROCESS {

		# Check for psproj.json file first.
		$projFilePath = "$ProjectRoot/psproj.json"
		$projData = (Get-Content $projFilePath) -join "`n" | ConvertFrom-Json
		$src = (Join-Path "$ProjectRoot" $projData.src)
		$dist = (Join-Path "$ProjectRoot" $projData.dist)
		$tests = (Join-Path "$ProjectRoot" $projData.tests)
		$authors = ($projData.authors -join ", ")
		$description = $projData.description
		$dotNetVersion = $projData.dotNetVersion
		$powerShellVersion = $projData.powerShellVersion
		$moduleVersion = $projData.version
		$projectName = $projData.projectName
		$companyName = $projData.companyName
		$uniqueId = $projData.uniqueId
		$rootModule = $projData.rootModule
		$moduleNames = Get-ChildItem $ProjectRoot `
			-Recurse -Filter *.psm1 | ForEach BaseName
		@{
			"UniqueIdentifier" = $uniqueId;
			"DistributionPath" = $dist;
			"SourcePath" = $src;
			"TestsPath" = $tests;
			"Authors" = $authors;
			"CompanyName" = $companyName;
			"ProjectDescription" = $description;
			"DotNetVersion" = $dotNetVersion;
			"PowerShellVersion" = $powerShellVersion;
			"ModuleVersion" = $moduleVersion;
			"ProjectName" = $projectName;
			"ProjectRoot" = $ProjectRoot;
			"ModuleNames" = $moduleNames;
			"RootModule" = $rootModule
		}
	}
}

Function New-DistributionDirectory {
	<#
	.SYNOPSIS
		Create a distribution directory for the project specified
	.DESCRIPTION
		This function will get rid of any existing distribution directory
		for the project and create a new one so no artifacts are left
		hanging around.
	.PARAMETER ProjectData
		A set of PowerShell project data that describes the project
	.EXAMPLE
		New-DistributionDirectory $psProjectData
		Rebuild the distribution directory from a psproj dataset
	.EXAMPLE
		New-DistributionDirectory C:\projects\PowerShellProjectTestA\
		Rebuild the distribution directory for the project at the path specified
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$True)]
		[hashtable] $ProjectData
	)
	if (Test-Path $ProjectData.DistributionPath) {
		# Blow away the distribution directory if it's already there
		Remove-Item $ProjectData.DistributionPath -Force -Recurse
	}
	# Create the distribution directory
	New-Item $ProjectData.DistributionPath -ItemType Directory | Write-Debug
}

Function New-ModuleManifestFromProjectData {
	<#
	.SYNOPSIS
		Create a powershell module manifest for a ps project
	.DESCRIPTION
		This function creates a new Manifest file for the
		project specified in the dataset it will create the file
		at the same location as the module file

		Note: The module name must match the .asm1 file name
	.PARAMETER ProjectData
		A set of PowerShell project data that describes the project
	.EXAMPLE
		New-ModuleManifestFromProjectData -ProjectData
		Create a manifest for the file MyModule.psm1
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$True)]
		[hashtable] $ProjectData
	)

	$ModuleName = $ProjectData.RootModule

	$modulePath = Get-ChildItem $ProjectData.ProjectRoot -Filter "$ModuleName.psm1" -Recurse | Select -ExpandProperty FullName -First 1 | Split-Path
	$searchPath = if ($ProjectData.SourcePath -ne $null) { $ProjectData.SourcePath } else { $manifestOutputPath }
	$version = if ($ProjectData.ModuleVersion -ne $null) { $ProjectData.ModuleVersion } else { "0.0.0" }
	$authors = if ($ProjectData.Authors -ne $null) { $ProjectData.Authors } else { "" }
	$description = if ($ProjectData.ProjectDescription -ne $null) { $ProjectData.ProjectDescription } else { "" }
	$uniqueId = if ($ProjectData.UniqueIdentifier -ne $null) { $ProjectData.UniqueIdentifier } else { [guid]::NewGuid().ToString() }
	$psVersion = if ($ProjectData.PowerShellVersion -ne $null) { $ProjectData.PowerShellVersion } else { "4.0" }
	$dnVersion = if ($ProjectData.DotNetVersion -ne $null) { $ProjectData.DotNetVersion } else { "4.5" }
	$companyName = if ($ProjectData.CompanyName -ne $null) { $ProjectData.CompanyName } else { "" }


	# Get rid of old manifest if it's there
	if (Test-Path(Join-Path $modulePath "$ModuleName.psd1")) {
		Remove-Item (Join-Path $modulePath "$ModuleName.psd1")
	}

	# Create the manifest
	New-ModuleManifest `
		-Path (Join-Path $modulePath "$ModuleName.psd1") `
		-ModuleVersion $version `
		-RootModule "$ModuleName.psm1" `
		-Guid $uniqueId `
		-Author $authors `
		-FileList @() `
		-CompanyName $companyName `
		-Copyright "(c) $((Get-Date).Year) $companyName All rights reserved.' " `
		-Description $description  `
		-PowerShellVersion $psVersion `
		-DotNetFrameworkVersion $dnVersion `
		-NestedModules (Get-ChildItem  $searchPath -Filter *.psm1 -Exclude "$ModuleName.psm1" | ForEach Name )
}

Function Invoke-ScriptCop {
	<#
	.SYNOPSIS
		Run the Static script analysis tool ScriptCop on a loaded module
	.DESCRIPTION
		This function will run a simple analysis over the specified
		module to determine if it follows the best practices outlined
		by the ScriptCop analyzer.

		NOTE: The module must be loaded in order to be analyzed
	.PARAMETER ModuleName
		The name of the Module you would like to analyze
	.EXAMPLE
		Invoke-ScriptCop MyModule
		Analyze MyModule.psm1 which has been already been loaded.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$True)]
		[string] $ModuleName
	)
	if (Get-Command Test-Command -errorAction SilentlyContinue)
	{
		Get-Module -Name $ModuleName | Test-Command | Where {
			$_.Problem -notmatch "does not define any #regions" -and `
			$_.Problem -notmatch "No command is an island\.  Please add at least one \.LINK"
		}
	}
	else
	{
		Write-Error "ScriptCop is not installed; please go to http://scriptcop.start-automating.com/ to get it."
	}
}

Function Export-Artifacts {
	<#
	.SYNOPSIS
		Export the artifacts of a powershell project to a zip file
	.DESCRIPTION
		This function will grab all the non-test scripts, manifests and help files
		and zip them up dropping them into the dist folder along with the unzipped
		artifacts
	.PARAMETER ProjectData
		A set of PowerShell project data that describes the project
	.EXAMPLE
		Export-Artifacts -ProjectData $projData
		Export the artifacts for the project
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$True)]
		[hashtable] $ProjectData,

        [string] $ArtifactSource
	)
    $temp = "$($ProjectData.ProjectRoot)\temp"
    if ((Test-Path $temp) -eq $False) {
		New-Item -Type Directory $temp | Write-Debug
	}
	# Requires .NET 4.5
	[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
	$zipFileName = (Join-Path (Convert-Path $ProjectData.DistributionPath) "$($ProjectData.RootModule)-$($ProjectData.ModuleVersion).zip")

	# Overwrite the ZIP if it already already exists.
	if (Test-Path $zipFileName) {
		Remove-Item $zipFileName -Force
	}
	$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
	$includeBaseDirectory = $false
	[System.IO.Compression.ZipFile]::CreateFromDirectory((Convert-Path $temp), $zipFileName, $compressionLevel, $includeBaseDirectory)
	if (Test-Path $temp) {
		Remove-Item $temp -Force -Recurse
	}

}

Function Invoke-Tests {
	<#
	.SYNOPSIS
		Load the powershell tests associated with the given project
	.DESCRIPTION
		This function will load all the modules of the specified
		project and then it will run all the test files in the tests
		directory for the project
	.PARAMETER ProjectData
		A set of PowerShell project data that describes the project
	.EXAMPLE
		Invoke-Tests -ProjectData $projData
		Run all the tests for the project
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$True)]
		[hashtable] $ProjectData
	)
    Get-ChildItem $ProjectData.SourcePath *.psm1 -Recurse | ForEach {
        Import-Module $_.FullName
    }
	Get-ChildItem $ProjectData.TestsPath *.Test.ps1 | ForEach {
		Invoke-Expression $_.FullName
	}
    Get-ChildItem $ProjectData.SourcePath *.psm1 -Recurse | ForEach {
        $mname = [System.IO.Path]::GetFileNameWithoutExtension($_.FullName)
        if(Get-Module $mname) {
            Remove-Module $mname
        }
    }
}

Function Copy-Artifacts {
	<#
	.SYNOPSIS
		Copy the project artifacts to the specified directory
	.DESCRIPTION
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$True)]
		[hashtable] $ProjectData
	)
    $temp = "$($ProjectData.ProjectRoot)\temp"
	if ((Test-Path $temp) -eq $False) {
		New-Item -Type Directory $temp | Write-Debug
	}
    $modPath = "$temp\$($ProjectData.RootModule)"
    if ((Test-Path $modPath) -eq $False) {
		New-Item -Type Directory $modPath | Write-Debug
	}

	Copy-Item `
		-Include *.psm1,*psd1,*ps1,*.help.txt `
		-Path "$($ProjectData.SourcePath)\*" `
		-Destination "$temp\$($ProjectData.RootModule)" `
		-Recurse
}

Function Invoke-PSBuild {
	<#
	.SYNOPSIS
		Run a build on a PowerShell Project
	.DESCRIPTION
		This function will run the tests and static analysis on
		the code and then it will build the manifest and zip up the
		artifacts dropping them in the distributable directory
	.PARAMETER $ProjectRoot
		The path to the root of the PowerShell project where the psproj.json lives
	.EXAMPLE
		Invoke-PSBuild -ProjectRoot ./MyProject/
		Run a full build on MyModule.psm1
	#>
	[CmdletBinding()]
	param (
		[string] $ProjectRoot = "./"
	)

	Write-Verbose "Getting Project Data..."
	$projData = Get-PSProjectProperties -ProjectRoot $ProjectRoot
	Write-Verbose "Invoking Project Tests..."
	Invoke-Tests -ProjectData $projData
	$modulePath = Get-ChildItem -Recurse -Filter "$($projData.RootModule).psm1" $projData.ProjectRoot |
		Select -ExpandProperty FullName
    if((Get-Module $projData.RootModule) -eq $null) {
        Import-Module $modulePath
    }
	Write-Verbose "Creating Output Directory..."
	New-DistributionDirectory -ProjectData $projData
	Write-Verbose "Creating Manifest File..."
	New-ModuleManifestFromProjectData -ProjectData $projData
	Write-Verbose "Copying Artifacts to temp folder..."
	Copy-Artifacts -ProjectData $projData
#	Write-Verbose "Invoking Static Analysis..."
	# Add the temp directory to the module path temporarily for the script cop
#	$env:PSModulePath = "$($env:PSModulePath);$(Resolve-Path "$ProjectRoot\temp")"
#	Invoke-ScriptCop -ModuleName $projData.RootModule
	Write-Verbose "Zipping Up Artifacts..."
	Export-Artifacts -ProjectData $projData
}
#endregion

#region Aliases
Set-Alias psbuild Invoke-PSBuild
#endregion

#region Export Public Functions for the Module
Export-ModuleMember -Function Get-PSProjectProperties
Export-ModuleMember -Function Copy-Artifacts
Export-ModuleMember -Function Export-Artifacts
Export-ModuleMember -Function New-DistributionDirectory
Export-ModuleMember -Function New-ModuleManifestFromProjectData
Export-ModuleMember -Function Invoke-ScriptCop
Export-ModuleMember -Function Invoke-Tests
Export-ModuleMember -Function Invoke-PSBuild
#endregion

#region Export Aliases
Export-ModuleMember -Alias psbuild
#endregion
