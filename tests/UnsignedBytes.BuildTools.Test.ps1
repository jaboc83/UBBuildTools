$ErrorActionPreference = "Stop"
$scriptPath = Split-Path -LiteralPath $(if ($PSVersionTable.PSVersion.Major -ge 3) { $PSCommandPath } else { & { $MyInvocation.ScriptName } })
$projRoot = "$scriptPath/../_TestProjectRoot"
$src = "$scriptPath/../src"
$dist = "$projRoot/dist"
$modName = "MyModule"
$modules = "$dist/TempModules"
$modVersion = "1.2.3"
$buildTools = "UnsignedBytes.BuildTools"
$uid = "525222de-a3d1-48ef-8055-510e4c681be4"
$comp = "MyCompany, Inc."
$projName = "Test Project"
$authors = "Jim Bob, Joe Test"
$desc = "Test Project Description"
$dnv = "4.5"
$psv = "4.0"

# Get-PSProjectProperties
Function Test-GetPSProjectProperties {
	## ARRANGE

	## ACT
    $data = Get-PSProjectProperties -ProjectRoot $projRoot

	## ASSERT
    if ($data.ModuleVersion -ne $modVersion) {
		throw "Version not found in project data"
	}
    if ($data.UniqueIdentifier -ne $uid) {
		throw "UniqueIdentifier not found in project data"
	}
	if ($data.CompanyName -ne $comp) {
		throw "CompanyName not found in project data"
	}
    if ($data.ProjectName -ne $projName) {
		throw "ProjectName not found in project data"
	}
    if ((Convert-Path $data.DistributionPath) -ne (Convert-Path $dist)) {
		throw "DistributionPath not found in project data"
	}
    if ((Convert-Path $data.SourcePath) -ne (Convert-Path "$projRoot\src")) {
		throw "SourcePath not found in project data"
	}
    if ((Convert-Path $data.TestsPath) -ne (Convert-Path "$projRoot\tests")) {
		throw "TestsPath not found in project data"
	}
    if ($data.Authors -ne $authors) {
		throw "Authors not found in project data"
	}
    if ($data.ProjectDescription -ne $desc) {
		throw "ProjectDescription not found in project data"
	}
    if ($data.DotNetVersion -ne $dnv) {
		throw "DotNetVersion not found in project data"
	}
    if ($data.PowerShellVersion -ne $psv) {
		throw "PowerShellVersion not found in project data"
	}
    if ($data.ProjectRoot -ne $projRoot) {
		throw "ProjectRoot not found in project data"
	}
	if ($data.ModuleNames -NotContains $modName) {
		throw "Module Name not found in project data"
	}
    if ($data.RootModule -ne $modName) {
		throw "Root Module not found in project data"
	}
    Write-Output "Data retrieved from psproj file."

	# cleanup
}

# New-DistributionDirectory
Function Test-NewDistributionDirectory {
	## ARRANGE
	if(Test-Path $dist) {
		Remove-Item $dist -Recurse -Force
	}

	## ACT
	New-DistributionDirectory -ProjectData (Get-PSProjectProperties $projRoot)

	## ASSERT
	if((Test-Path $dist) -eq $False) {
		throw "Project dist folder not created."
	}
	Write-Output "Distribution Folder Created from Data"

	# cleanup
}

# New-ModuleManifestFromProjectData
Function Test-NewModuleManifestFromProjectData {
	## ARRANGE
	$manifestFile = "$projRoot/src/$modName.psd1"
	if(Test-Path $manifestFile) {
		Remove-Item $manifestFile
	}

	## ACT
	New-ModuleManifestFromProjectData -ProjectData (Get-PSProjectProperties -ProjectRoot $projRoot)

	## ASSERT
	if((Test-Path $manifestFile) -eq $False) {
		throw "Manifest file not created."
	}
	Write-Output "Manifest File Generated."

	# cleanup
	if(Test-Path $manifestFile) {
		Remove-Item $manifestFile
	}
}

# Invoke-ScriptCop
Function Test-InvokeScriptCop {
	## ARRANGE

	## ACT
	Invoke-ScriptCop "$projRoot/src/$modName.psm1"

	## ASSERT
	Write-Output "ScriptCop Ran Successfully"

	# cleanup
}

# Export-Artifacts
Function Test-ExportArtifacts {
	## ARRANGE
	if (Test-Path "$dist/*") {
		Remove-Item "$dist/*"
	}

	## ACT
	Export-Artifacts -ProjectData (Get-PSProjectProperties $projRoot)

	## ASSERT
	if (Test-Path "$dist/$modName-$modVersion.zip") {
		Remove-Item "$dist/$modName-$modVersion.zip"
	}
	Write-Output "Artifacts Exported Successfully."

	# cleanup
	if (Test-Path "$dist/*") {
		Remove-Item "$dist/*"
	}
}

# Export-ArchiveContents
Function Test-ExportArchiveContents {
	## ARRANGE
	Invoke-PSBuild -ProjectRoot $projRoot
	if (-not (Test-Path "$dist/$modName-$modVersion.zip")) {
		Write-Error "Artifacts Not Built. Ending Test."
	}

	## ACT
	Export-ArchiveContents -ArchiveFile "$dist/$modName-$modVersion.zip" -DestinationDirectory "$dist/Unzipped"

	## ASSERT
	if (-not (Test-Path "$dist/Unzipped/$modName/$modName.psm1") -or
		-not (Test-Path "$dist/Unzipped/$modName/$modName.psd1")) {
		Write-Error "Failed to unarchive files to destination"
	} else {
		Write-Output "Archive Contents Exported Successfully."
	}

	# cleanup
	Remove-Item -Recurse -Force "$dist/Unzipped"
}

# Invoke-Tests
Function Test-InvokeTests {
	## ARRANGE
	Import-Module "$src/$buildTools.psm1"

	## ACT
	Write-Output "Running Tests..."
	Invoke-Tests -ProjectData (Get-PSProjectProperties $projRoot)

	## ASSERT
	Write-Output "Tests Completed."
}

# Invoke-PSBuild
Function Test-InvokePSBuild {
	## ARRANGE
	Import-Module "$src/$buildTools.psm1"

	## ACT
	Invoke-PSBuild -ProjectRoot $projRoot

	## ASSERT
	Write-Output "Build Completed."
}

# Invoke-PSBuild
Function Test-InvokePSInstall {
	## ARRANGE
	if (Test-Path "$modules") {
		Remove-Item "$modules" -Recurse -Force
	}
	Invoke-PSBuild -ProjectRoot $projRoot

	## ACT
	Invoke-PSInstall -ProjectRoot $projRoot -ModulesDirectory $modules

	## ASSERT
	Write-Output "Install Complete."

	# cleanup
	if (Test-Path "$modules") {
		Remove-Item "$modules" -Recurse -Force
	}
}

Import-Module "$src/$buildTools.psm1"
# Run Tests
Test-NewDistributionDirectory
Test-GetPSProjectProperties
Test-NewModuleManifestFromProjectData
#Test-InvokeScriptCop
Test-ExportArtifacts
Test-ExportArchiveContents
Test-InvokeTests
Test-InvokePSBuild
Test-InvokePSInstall

Remove-Module $buildTools
