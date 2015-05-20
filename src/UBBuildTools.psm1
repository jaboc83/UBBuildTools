Function Get-PSProjectProperties {
	<#
	.SYNOPSIS
		Gets some useful properties about a powershell project
	.DESCRIPTION
		This function looks in the specified project directory
		for the psproj.json file to create a set of project data that
		describes the project.

		If a src and dist property are not specified then the default
		src and dist folders will be assumed.
	.PARAMETER ProjectRoot
		The root path to the powershell project
	#>
	[CmdletBinding()]
	param (
		[Parameter( Mandatory=$True, ValueFromPipeline=$True)]
		[string] $ProjectRoot
	)
	PROCESS {

		# Check for psproj.json file first.
		$projFilePath = "$ProjectRoot/psproj.json"
		if (Test-Path $projFilePath) {
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
			$moduleNames = Get-ChildItem $ProjectRoot `
				-Recurse -Filter *.psm1 | ForEach BaseName
		} else {
			# PowerShell project source folder
			$src = (Join-Path $ProjectRoot 'src')
			# PowerShell project distribution (artifacts) folder
			$dist = (Join-Path $ProjectRoot 'dist')
		}

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
			"ModuleNames" = $moduleNames
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
		Rebuild the distribution directory from a psproj dataset
			New-DistributionDirectory $psProjectData
	.EXAMPLE
		Rebuild the distribution directory for the project at the path specified
			New-DistributionDirectory C:\projects\PowerShellProjectTestA\
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
	New-Item $ProjectData.DistributionPath -ItemType Directory | Out-Null
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
	.PARAMETER ModuleName
		The name of the module the manifest is for minus the extension
	.EXAMPLE
		Create a manifest for the file MyModule.psm1
			New-ModuleManifestFromProjectData -ProjectData $projData -ModuleName MyModule
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$True)]
		[hashtable] $ProjectData,
		[Parameter(Mandatory=$True)]
		[string] $ModuleName
	)

	# Deal with file exensions if they are passed on accident
	$ModuleName = $ModuleName.Replace(".psm1", "")

	# Verify the moduleName is valid based on the project info
	if ($ProjectData.ModuleNames -NotContains $ModuleName) {
		throw "Invalid Module Name ($ModuleName) for this project"
	}

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
		-Guid $uniqueId `
		-Author $authors `
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
		Analyze MyModule.psm1 which has been already been loaded.
			Invoke-ScriptCop MyModule
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$True)]
		[string] $ModuleName
	)

	if (Get-Command Test-Command -errorAction SilentlyContinue)
	{
		Get-Module -Name $ModuleName | Test-Command
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
	.PARAMETER ModuleName
		The name of the Module you would like to analyze
	.EXAMPLE
		Export the artifacts for the project
			Export-Artifacts -ProjectData $projData -ModuleName MyModule
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$True)]
		[hashtable] $ProjectData,
		[Parameter(Mandatory=$True)]
		[string] $ModuleName
	)
	$temporaryArtifacts = "./temp"

	# Create the temporary artifacts directory
	if (Test-Path "$temporaryArtifacts") {
		Remove-Item "$temporaryArtifacts" -Force -Recurse
	}
	New-Item "$temporaryArtifacts" -ItemType Directory | Out-Null

	# Copy the distributable files to the dist folder.
	Copy-Item -Path "$($ProjectData.SourcePath)\*" `
			-Destination "$temporaryArtifacts" `
			-Recurse
	$manifestFileName = "$ModuleName.psd1"
	# Requires .NET 4.5
	[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
	$zipFileName = (Join-Path (Convert-Path $ProjectData.DistributionPath) "$([System.IO.Path]::GetFileNameWithoutExtension($manifestFileName))-$($ProjectData.ModuleVersion).zip")

	# Overwrite the ZIP if it already already exists.
	if (Test-Path $zipFileName) {
		Remove-Item $zipFileName -Force
	}
	$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
	$includeBaseDirectory = $false
	[System.IO.Compression.ZipFile]::CreateFromDirectory((Convert-Path $temporaryArtifacts), $zipFileName, $compressionLevel, $includeBaseDirectory)
	if (Test-Path "$temporaryArtifacts") {
		Remove-Item "$temporaryArtifacts" -Force -Recurse
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
		Run all the tests for the project
			Invoke-Tests -ProjectData $projData
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
		Write-Output (Invoke-Expression $_.FullName)
	}
    Get-ChildItem $ProjectData.SourcePath *.psm1 -Recurse | ForEach {
        Remove-Module ([System.IO.Path]::GetFileNameWithoutExtension($_.FullName))
    }
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
	.PARAMETER $ModuleName
		The name of the module to be built from the project
	.EXAMPLE
		Run a full build on MyModule.psm1
			Invoke-PSBuild -ProjectRoot ./MyProject/ -ModuleName MyModule
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$True)]
		[string] $ProjectRoot,
		[Parameter(Mandatory=$True)]
		[string] $ModuleName
	)
	Write-Verbose "Getting Project Data..."
	$projData = Get-PSProjectProperties -ProjectRoot $ProjectRoot
	Write-Verbose "Invoking Project Tests..."
	Invoke-Tests -ProjectData $projData
	$modulePath = Get-ChildItem -Recurse -Filter "$ModuleName.psm1" $projData.ProjectRoot |
		Select -ExpandProperty FullName
	Import-Module $modulePath
	Write-Verbose "Invoking Static Analysis..."
	Invoke-ScriptCop -ModuleName $ModuleName
	Remove-Module $ModuleName
	Write-Verbose "Creating Output Directory..."
	New-DistributionDirectory -ProjectData $projData
	Write-Verbose "Creating Manifest File..."
	New-ModuleManifestFromProjectData -ProjectData $projData -ModuleName $ModuleName
	Write-Verbose "Zipping Up Artifacts..."
	Export-Artifacts -ProjectData $projData -ModuleName $ModuleName
}

# Export Public Functions for the Module
Export-ModuleMember Get-PSProjectProperties
Export-ModuleMember New-DistributionDirectory
Export-ModuleMember New-ModuleManifestFromProjectData
Export-ModuleMember Invoke-ScriptCop
Export-ModuleMember Export-Artifacts
Export-ModuleMember Invoke-Tests
Export-ModuleMember Invoke-PSBuild
