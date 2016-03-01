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
		$dependencies = $projData.dependencies
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
			"RootModule" = $rootModule;
			"Dependencies" = $dependencies
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
	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='Medium')]
	param (
		[Parameter(Mandatory=$True)]
		[hashtable] $ProjectData
	)
	if (Test-Path $ProjectData.DistributionPath) {
		# Blow away the distribution directory if it's already there
		Remove-Item $ProjectData.DistributionPath -Force -Recurse -WhatIf:([bool]$WhatIfPreference.IsPresent)
	}
	# Create the distribution directory
	if ($pscmdlet.ShouldProcess($ProjectData.DistributionPath, "Creating Directory")) {
		New-Item $ProjectData.DistributionPath -ItemType Directory | Write-Debug
	}
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
	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='Medium')]
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
	$dependencies = if ($ProjectData.Dependencies -ne $null) { $ProjectData.Dependencies } else { @() }
	$fileList = Get-ChildItem -Recurse $ProjectData.SourcePath | Select -ExpandProperty Name


	# Get rid of old manifest if it's there
	if (Test-Path(Join-Path $modulePath "$ModuleName.psd1")) {
		Remove-Item (Join-Path $modulePath "$ModuleName.psd1") -WhatIf:([bool]$WhatIfPreference.IsPresent)
	}

	# Create the manifest
	New-ModuleManifest `
		-Path (Join-Path $modulePath "$ModuleName.psd1") `
		-ModuleVersion $version `
		-RootModule "$ModuleName.psm1" `
		-Guid $uniqueId `
		-Author $authors `
		-FileList $fileList `
		-CompanyName $companyName `
		-Copyright "(c) $((Get-Date).Year) $companyName All rights reserved.' " `
		-Description $description  `
		-RequiredModules $dependencies `
		-PowerShellVersion $psVersion `
		-DotNetFrameworkVersion $dnVersion `
		-NestedModules (Get-ChildItem  $searchPath -Filter *.psm1 -Exclude "$ModuleName.psm1" | ForEach Name ) `
		-WhatIf:([bool]$WhatIfPreference.IsPresent)
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
	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='Medium')]
	param (
		[Parameter(Mandatory=$True)]
		[hashtable] $ProjectData,

        [string] $ArtifactSource
	)
    $temp = "$($ProjectData.ProjectRoot)\temp"
    if ((Test-Path $temp) -eq $False) {
		New-Item -Type Directory $temp -WhatIf:([bool]$WhatIfPreference.IsPresent) | Write-Debug
	}
	# Requires .NET 4.5
	[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
	$zipFileName = (Join-Path (Convert-Path $ProjectData.DistributionPath) "$($ProjectData.RootModule)-$($ProjectData.ModuleVersion).zip")

	# Overwrite the ZIP if it already already exists.
	if (Test-Path $zipFileName) {
		Remove-Item $zipFileName -Force -WhatIf:([bool]$WhatIfPreference.IsPresent)
	}
	$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
	$includeBaseDirectory = $false
	if ($pscmdlet.ShouldProcess($zipFileName, "Create archive file from path $temp")) {
		[System.IO.Compression.ZipFile]::CreateFromDirectory((Convert-Path $temp), $zipFileName, $compressionLevel, $includeBaseDirectory)
	}
	if (Test-Path $temp) {
		Remove-Item $temp -Force -Recurse -WhatIf:([bool]$WhatIfPreference.IsPresent)
	}
}

Function Export-ArchiveContents {
	<#
	.SYNOPSIS
		Export the contents of a zip file to the destination folder
	.DESCRIPTION
		This function will unzip the contents of the zip file into the destination
		directory. It will create the destination if it doesn't exist.
	.PARAMETER ArchiveFile
		A zip file
	.PARAMETER DestinationDirectory
		Filepath to unzip the contents into
	.PARAMETER Replace
		Overwrite existing destination folder
	.EXAMPLE
		Export-ArchiveContents -ArchiveFile $zipFile -DestinationDirectory /temp/zipcontents
		Export the contents of the archive to the specified directory
	.EXAMPLE
		Export-ArchiveContents -ArchiveFile $zipFile -DestinationDirectory /temp/zipcontents -Force
		Export the contents of the archive to the specified directory destroying anything that was already
		the destination
	#>
	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='Medium')]
	param (
		[Parameter(Mandatory=$True)]
		[string] $ArchiveFile,

		[Parameter(Mandatory=$True)]
        [string] $DestinationDirectory,

        [switch] $Replace
	)
    if ((Test-Path $DestinationDirectory) -eq $False) {
		New-Item -Type Directory $DestinationDirectory -WhatIf:([bool]$WhatIfPreference.IsPresent) | Write-Debug
	} elseif ($Replace) {
		Remove-Item $DestinationDirectory -Force -Recurse -WhatIf:([bool]$WhatIfPreference.IsPresent)
	}

	# Requires .NET 4.5
	if ($pscmdlet.ShouldProcess($ArchiveFile, "Contents extracted to $DestinationDirectory")) {
		[System.IO.Compression.ZipFile]::ExtractToDirectory($ArchiveFile, $DestinationDirectory)
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
	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='Medium')]
	param (
		[Parameter(Mandatory=$True)]
		[hashtable] $ProjectData
	)
    if ($pscmdlet.ShouldProcess('Running Tests')) {
		Get-ChildItem $ProjectData.SourcePath *.psm1 -Recurse | ForEach {
			Import-Module $_.FullName
		}
	    Get-ChildItem $ProjectData.TestsPath *.Test.ps1 | ForEach {
		    Invoke-Expression $_.FullName
	    }
		Get-ChildItem $ProjectData.SourcePath *.psm1 -Recurse | ForEach {
			$mname = [System.IO.Path]::GetFileNameWithoutExtension($_.FullName)
			if(Get-Module $mname) {
				Remove-Module $mname -WhatIf:([bool]$WhatIfPreference.IsPresent)
			}
		}
    }
}

Function Copy-Artifacts {
	<#
	.SYNOPSIS
		Copy the project artifacts to the specified directory
	.DESCRIPTION
	#>
	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='Medium')]
	param (
		[Parameter(Mandatory=$True)]
		[hashtable] $ProjectData
	)
    $temp = "$($ProjectData.ProjectRoot)\temp"
	if ((Test-Path $temp) -eq $False) {
		New-Item -Type Directory $temp -WhatIf:([bool]$WhatIfPreference.IsPresent) | Write-Debug
	}
    $modPath = "$temp\$($ProjectData.RootModule)"
    if ((Test-Path $modPath) -eq $False) {
		New-Item -Type Directory $modPath -WhatIf:([bool]$WhatIfPreference.IsPresent) | Write-Debug
	}

	Copy-Item `
		-Include *.psm1,*psd1,*ps1,*.help.txt `
		-Path "$($ProjectData.SourcePath)\*" `
		-Destination "$temp\$($ProjectData.RootModule)" `
		-Recurse `
		-WhatIf:([bool]$WhatIfPreference.IsPresent)
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
	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='Medium')]
	param (
		[string] $ProjectRoot = "./"
	)

	Write-Verbose "Getting Project Data..."
	$projData = Get-PSProjectProperties -ProjectRoot $ProjectRoot
	Write-Verbose "Creating Output Directory..."
	New-DistributionDirectory -ProjectData $projData  -WhatIf:([bool]$WhatIfPreference.IsPresent)
	Write-Verbose "Invoking Project Tests..."
	Invoke-Tests -ProjectData $projData
	$modulePath = Get-ChildItem -Recurse -Filter "$($projData.RootModule).psm1" $projData.ProjectRoot |
		Select -ExpandProperty FullName
    if((Get-Module $projData.RootModule) -eq $null) {
        Import-Module $modulePath
    }
	Write-Verbose "Creating Manifest File..."
	New-ModuleManifestFromProjectData -ProjectData $projData -WhatIf:([bool]$WhatIfPreference.IsPresent)
	Write-Verbose "Copying Artifacts to temp folder..."
	Copy-Artifacts -ProjectData $projData -WhatIf:([bool]$WhatIfPreference.IsPresent)
#	Write-Verbose "Invoking Static Analysis..."
	# Add the temp directory to the module path temporarily for the script cop
#	$env:PSModulePath = "$($env:PSModulePath);$(Resolve-Path "$ProjectRoot\temp")"
#	Invoke-ScriptCop -ModuleName $projData.RootModule
	Write-Verbose "Zipping Up Artifacts..."
	Export-Artifacts -ProjectData $projData -WhatIf:([bool]$WhatIfPreference.IsPresent)
}

Function Invoke-PSInstall {
	<#
	.SYNOPSIS
		Install module output of a PowerShell Project
	.DESCRIPTION
		This function will take the artifacts of the last project
		build and install them in the user's manifest directory.
	.PARAMETER $ProjectRoot
		The path to the root of the PowerShell project where the psproj.json lives
	.PARAMETER $ModulesDirectory
		The path to where powershell modules should be installed
	.EXAMPLE
		Invoke-PSInstall -ProjectRoot ./MyProject/
		Install MyModule.psm1
	.EXAMPLE
		Invoke-PSInstall -ProjectRoot ./MyProject/ -ModulesDirectory E:/PSModules
		Install MyModule.psm1 to the custom module path E:/PSModules
	#>
	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='Medium')]
	param (
		[string] $ProjectRoot = "./",
		[string] $ModulesDirectory = "~/Documents/WindowsPowerShell/Modules"
	)

	$projData = Get-PSProjectProperties -ProjectRoot $ProjectRoot
	$dist = $projData.DistributionPath
	Write-Host $projData.RootModule
	$mName = $projData.RootModule

	# Requires .NET 4.5
	[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null

	# Make sure we have something to deploy
	if((Get-ChildItem "$dist\*.zip").Count -eq 0) {
		Write-Error "No module found; did you build the module yet?"
		Return
	}
	# Resolve the path even if it doesn't exist yet. (unlike Convert-Path)
	$modules = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ModulesDirectory)
	# Get rid of module if it exists already
	If (Test-Path "$modules\$($projData.RootModule)") {
		Remove-Item "$modules\$($projData.RootModule)" -Recurse -Force -WhatIf:([bool]$WhatIfPreference.IsPresent)
	}
	# Unzip
	Export-ArchiveContents `
		-ArchiveFile (Get-ChildItem "$dist\$($projData.RootModule)*.zip")[0] `
		-DestinationDirectory "$modules" `
		-WhatIf:([bool]$WhatIfPreference.IsPresent)

	Write-Output "Module Installed to $modules"

	#Unload module if already installed
	if (((Get-Module -ListAvailable -Name $mName).Count -gt 0) `
		-and ((Get-Module -Name $mName).Count -gt 0)) {
		Remove-Module $mName
	}
}

Function Invoke-PSInit {
	<#
	.SYNOPSIS
		Create a new PowerShell Project
	.DESCRIPTION
		This function will create a new PowerShell project in the directory
		specified.
	.PARAMETER $ProjectFolder
		The path to the root of the PowerShell project where the psproj.json
		will live
	.EXAMPLE
		Invoke-PSInit -ProjectFolder ./newProj/
		Initialize a new PS Project in the folder newProj
	.EXAMPLE
		Invoke-PSInit
		Initialize a new PS Project in the current folder
	#>
	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='Medium')]
	param (
		[ValidateScript({ Test-Path "$_" })]
		[Parameter(Mandatory=$False)]
		[string] $ProjectFolder = "./"
	)


	if ($ProjectFolder -eq "./") {
		(Resolve-Path "./").Path -match "\\([^\\\s]+)\\?$" | Out-Null
	} else {
		$ProjectFolder -match "\\([^\\\s]+)\\?$" | Out-Null
	}
	$projName = $Matches[1]

	$temp = Read-Host "ProjectName ($projName):"
	if ($temp -ne "") {
		$projName = $temp
	}

	$uniqueId = [guid]::NewGuid()

	$companyName = ""
	$temp = Read-Host "Company Name:"
	if ($temp -ne "") {
		$companyName = $temp
	}

	$version = "1.0.0"
	$temp = Read-Host "Version (1.0.0):"
	if ($temp -ne "") {
		$version = $temp
	}

	$description = ""
	$temp = Read-Host "Description:"
	if ($temp -ne "") {
		$description = $temp
	}

	$src = "src"
	$temp = Read-Host "Source Folder(src):"
	if ($temp -ne "") {
		$src = $temp
	}

	$dist = "dist"
	$temp = Read-Host "Output Folder(dist):"
	if ($temp -ne "") {
		$dist = $temp
	}

	$tests = "tests"
	$temp = Read-Host "Tests Folder(tests):"
	if ($temp -ne "") {
		$tests = $temp
	}

	@"
	{
		`"projectName`": `"$projName`",
		`"uniqueId`": `"$uniqueId`",
		`"companyName`": `"$companyName`",
		`"version`": `"$version`",
		`"description`": `"$description`",
		`"authors`": [],
		`"dotNetVersion`": `"4.6`",
		`"powerShellVersion`": `"5.0`",
		`"src`": `"$src`",
		`"dist`": `"$dist`",
		`"tests`": `"$tests`"
	}
"@ | Out-File -filepath "$ProjectFolder\psproj.json"
	New-Item -ItemType directory -Path $src
	New-Item -ItemType directory -Path $dist
	New-Item -ItemType directory -Path $tests
}
#endregion

#region Aliases
Set-Alias psbuild Invoke-PSBuild
Set-Alias psinstall Invoke-PSInstall
Set-Alias psinit Invoke-PSInit
#endregion

#region Export Public Functions for the Module
Export-ModuleMember -Function Get-PSProjectProperties
Export-ModuleMember -Function Copy-Artifacts
Export-ModuleMember -Function Export-Artifacts
Export-ModuleMember -Function Export-ArchiveContents
Export-ModuleMember -Function New-DistributionDirectory
Export-ModuleMember -Function New-ModuleManifestFromProjectData
Export-ModuleMember -Function Invoke-ScriptCop
Export-ModuleMember -Function Invoke-Tests
Export-ModuleMember -Function Invoke-PSBuild
Export-ModuleMember -Function Invoke-PSInstall
Export-ModuleMember -Function Invoke-PSInit
#endregion

#region Export Aliases
Export-ModuleMember -Alias psbuild
Export-ModuleMember -Alias psinstall
Export-ModuleMember -Alias psinit
#endregion
