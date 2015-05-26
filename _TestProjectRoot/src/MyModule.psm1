Function Get-Nothing {
		<#
		.SYNOPSIS
			A Test
		.DESCRIPTION
			A TEST that does nothing at all
		.EXAMPLE
			Get-Nothing
			A test that does nothing
		#>
		[OutputType([string])]
		param (
		)
		$text = "I Didn't do anything."
		Write-Verbose $text
		Write-Out $text
}

Export-ModuleMember Get-Nothing
