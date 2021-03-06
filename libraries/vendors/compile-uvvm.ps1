# EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# 
# ==============================================================================
#	Authors:						Patrick Lehmann
# 
#	PowerShell Script:	Script to compile the UVVM library for GHDL on Windows
# 
# Description:
# ------------------------------------
#	This is a PowerShell script (executable) which:
#		- creates a subdirectory in the current working directory
#		- compiles all UVVM packages 
#
# ==============================================================================
#	Copyright (C) 2015-2017 Patrick Lehmann - Dresden, Germany
#	
#	GHDL is free software; you can redistribute it and/or modify it under
#	the terms of the GNU General Public License as published by the Free
#	Software Foundation; either version 2, or (at your option) any later
#	version.
#	
#	GHDL is distributed in the hope that it will be useful, but WITHOUT ANY
#	WARRANTY; without even the implied warranty of MERCHANTABILITY or
#	FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
#	for more details.
#	
#	You should have received a copy of the GNU General Public License
#	along with GHDL; see the file COPYING.  If not, write to the Free
#	Software Foundation, 59 Temple Place - Suite 330, Boston, MA
#	02111-1307, USA.
# ==============================================================================

# .SYNOPSIS
# This CmdLet compiles the UVVM library.
# 
# .DESCRIPTION
# This CmdLet:
#   (1) creates a subdirectory in the current working directory
#   (2) compiles all UVVM packages
#
[CmdletBinding()]
param(
	# Show the embedded help page(s).
	[switch]$Help =								$false,
	
	# Compile all packages.
	[switch]$All =								$true,
	
	# Compile all UVVM packages.
	[switch]$UVVM =								$true,
	# Compile all UVVM Utility packages.
	[switch]$UVVM_Utilities =			$true,
	# Compile all UVVM VCC Framework packages.
	[switch]$UVVM_VCC_Framework =	$true,
	# Compile all UVVM Verification IPs (VIPs).
	[switch]$UVVM_VIP =								$true,
		# Compile VIP: AXI-Lite
		[switch]$UVVM_VIP_AXI_Lite =		$true,
		# Compile VIP: AXI-Stream
		[switch]$UVVM_VIP_AXI_Stream =	$true,
		# Compile VIP: I2C
		[switch]$UVVM_VIP_I2C =					$true,
		# Compile VIP: SBI (Simple Byte Interface)
		[switch]$UVVM_VIP_SBI =					$true,
		# Compile VIP: UART
		[switch]$UVVM_VIP_UART =				$true,
	
	# Clean up directory before analyzing.
	[switch]$Clean =							$false,
	
	#Skip warning messages. (Show errors only.)
	[switch]$SuppressWarnings = 	$false,
	# Halt on errors.
	[switch]$HaltOnError =				$false,
	
	# Set vendor library source directory.
	[string]$Source =							"",
	# Set output directory name.
	[string]$Output =							"",
	# Set GHDL executable.
	[string]$GHDL =								""
)

# ---------------------------------------------
# save working directory
$WorkingDir =		Get-Location

# set default values
$EnableDebug =		[bool]$PSCmdlet.MyInvocation.BoundParameters["Debug"]
$EnableVerbose =	[bool]$PSCmdlet.MyInvocation.BoundParameters["Verbose"] -or $EnableDebug

# load modules from GHDL's 'vendors' library directory
Import-Module $PSScriptRoot\config.psm1 -Verbose:$false -Debug:$false -ArgumentList "UVVM"
Import-Module $PSScriptRoot\shared.psm1 -Verbose:$false -Debug:$false -ArgumentList @("UVVM", "$WorkingDir")

# Display help if no command was selected
if ($Help -or (-not ($All -or $Clean -or
										($UVVM -or			($UVVM_Utilities -or $UVVM_VVC_Framework)) -or
										($UVVM_VIP -or	($UVVM_VIP_AXI_Lite -or $UVVM_VIP_AXI_Stream -or $UVVM_VIP_I2C -or $UVVM_VIP_SBI -or $UVVM_VIP_UART))		)))
{	Get-Help $MYINVOCATION.InvocationName -Detailed
	Exit-CompileScript
}

if ($All)
{	$UVVM =									$true
	$UVVM_VIP =							$true
}
if ($UVVM)
{	$UVVM_Utilities =				$true
	$UVVM_VCC_Framework =		$true
}
if ($UVVM_VIP)
{	$UVVM_VIP_AXI_Lite =		$true
	$UVVM_VIP_AXI_Stream =	$true
	$UVVM_VIP_I2C =					$true
	$UVVM_VIP_SBI =					$true
	$UVVM_VIP_UART =				$true
}


$SourceDirectory =			Get-SourceDirectory $Source ""
$DestinationDirectory =	Get-DestinationDirectory $Output
$GHDLBinary =						Get-GHDLBinary $GHDL

# create "Altera" directory and change to it
New-DestinationDirectory $DestinationDirectory
cd $DestinationDirectory


$VHDLVersion,$VHDLStandard,$VHDLFlavor = Get-VHDLVariables

# define global GHDL Options
$GHDLOptions = @("-a", "-fexplicit", "-frelaxed-rules", "--mb-comments", "--warn-binding", "--ieee=$VHDLFlavor", "--no-vital-checks", "--std=$VHDLStandard", "-P$DestinationDirectory")

# extract data from configuration
# $SourceDir =			$InstallationDirectory["AlteraQuartus"] + "\quartus\eda\sim_lib"

$ErrorCount =			0

# Cleanup directories
# ==============================================================================
if ($Clean)
{	Write-Host "[ERROR]: '-Clean' is not implemented!" -ForegroundColor Red
	Exit-CompileScript -1
	
	Write-Host "Cleaning up vendor directory ..." -ForegroundColor Yellow
	rm *.cf
}

$UVVM_Util_Files = @(
	"uvvm_util\src\types_pkg.vhd",
	"uvvm_util\src\adaptations_pkg.vhd",
	"uvvm_util\src\string_methods_pkg.vhd",
	"uvvm_util\src\protected_types_pkg.vhd",
	"uvvm_util\src\hierarchy_linked_list_pkg.vhd",
	"uvvm_util\src\alert_hierarchy_pkg.vhd",
	"uvvm_util\src\license_pkg.vhd",
	"uvvm_util\src\methods_pkg.vhd",
	"uvvm_util\src\bfm_common_pkg.vhd",
	"uvvm_util\src\uvvm_util_context.vhd"
)
$UVVM_VVC_Files = @(
	"uvvm_vvc_framework\src\ti_vvc_framework_support_pkg.vhd",
	"uvvm_vvc_framework\src\ti_generic_queue_pkg.vhd",
	"uvvm_vvc_framework\src\ti_data_queue_pkg.vhd",
	"uvvm_vvc_framework\src\ti_data_fifo_pkg.vhd",
	"uvvm_vvc_framework\src\ti_data_stack_pkg.vhd"
	"uvvm_vvc_framework\src\ti_uvvm_engine.vhd"
)
$VIP_Files = @{
	"AXILite" = @{
		"Variable" =	"UVVM_VIP_AXI_Lite";
		"Library" =		"bitvis_vip_axilite";
		"Files" =			@(
			"bitvis_vip_axilite\src\axilite_bfm_pkg.vhd",
			"bitvis_vip_axilite\src\vvc_cmd_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_target_support_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_vvc_framework_common_methods_pkg.vhd",
			"bitvis_vip_axilite\src\vvc_methods_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_queue_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_vvc_entity_support_pkg.vhd",
			"bitvis_vip_axilite\src\axilite_vvc.vhd"
		)
	};
	"AXIStream" = @{
		"Variable" =	"UVVM_VIP_AXI_Stream";
		"Library" =		"bitvis_vip_axistream";
		"Files" =			@(
			"bitvis_vip_axistream\src\axistream_bfm_pkg.vhd",
			"bitvis_vip_axistream\src\vvc_cmd_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_target_support_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_vvc_framework_common_methods_pkg.vhd",
			"bitvis_vip_axistream\src\vvc_methods_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_queue_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_vvc_entity_support_pkg.vhd",
			"bitvis_vip_axistream\src\axistream_vvc.vhd"
		)
	};
	"I2C" = @{
		"Variable" =	"UVVM_VIP_I2C";
		"Library" =		"bitvis_vip_i2c";
		"Files" =			@(
			"bitvis_vip_i2c\src\i2c_bfm_pkg.vhd",
			"bitvis_vip_i2c\src\vvc_cmd_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_target_support_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_vvc_framework_common_methods_pkg.vhd",
			"bitvis_vip_i2c\src\vvc_methods_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_queue_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_vvc_entity_support_pkg.vhd",
			"bitvis_vip_i2c\src\i2c_vvc.vhd"
		)
	};
	"SBI" = @{
		"Variable" =	"UVVM_VIP_SBI";
		"Library" =		"bitvis_vip_sbi";
		"Files" =			@(
			"bitvis_vip_sbi/src/sbi_bfm_pkg.vhd",
			"bitvis_vip_sbi/src/vvc_cmd_pkg.vhd",
			"uvvm_vvc_framework/src_target_dependent/td_target_support_pkg.vhd",
			"uvvm_vvc_framework/src_target_dependent/td_vvc_framework_common_methods_pkg.vhd",
			"bitvis_vip_sbi/src/vvc_methods_pkg.vhd",
			"uvvm_vvc_framework/src_target_dependent/td_queue_pkg.vhd",
			"uvvm_vvc_framework/src_target_dependent/td_vvc_entity_support_pkg.vhd",
			"bitvis_vip_sbi/src/sbi_vvc.vhd"
		)
	};
	"UART" = @{
		"Variable" =	"UVVM_VIP_UART";
		"Library" =		"bitvis_vip_uart";
		"Files" =			@(
			"bitvis_vip_uart\src\uart_bfm_pkg.vhd",
			"bitvis_vip_uart\src\vvc_cmd_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_target_support_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_vvc_framework_common_methods_pkg.vhd",
			"bitvis_vip_uart\src\vvc_methods_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_queue_pkg.vhd",
			"uvvm_vvc_framework\src_target_dependent\td_vvc_entity_support_pkg.vhd",
			"bitvis_vip_uart\src\uart_rx_vvc.vhd",
			"bitvis_vip_uart\src\uart_tx_vvc.vhd",
			"bitvis_vip_uart\src\uart_vvc.vhd"
		)
	}
}

# UVVM packages
# ==============================================================================
# compile uvvm_util library
if ((-not $StopCompiling) -and $UVVM_Utilities)
{	$Library = "uvvm_util"
	$SourceFiles = $UVVM_Util_Files | % { "$SourceDirectory\$_" }
	
	$ErrorCount += 0
	Start-PackageCompilation $GHDLBinary $GHDLOptions $DestinationDirectory $Library $VHDLVersion $SourceFiles $SuppressWarnings $HaltOnError -Verbose:$EnableVerbose -Debug:$EnableDebug
	$StopCompiling = $HaltOnError -and ($ErrorCount -ne 0)
}

# compile uvvm_vvc_framework library
if ((-not $StopCompiling) -and $UVVM_VCC_Framework)
{	$Library = "uvvm_vvc_framework"
	$SourceFiles = $UVVM_VVC_Files | % { "$SourceDirectory\$_" }
	
	$ErrorCount += 0
	Start-PackageCompilation $GHDLBinary $GHDLOptions $DestinationDirectory $Library $VHDLVersion $SourceFiles $SuppressWarnings $HaltOnError -Verbose:$EnableVerbose -Debug:$EnableDebug
	$StopCompiling = $HaltOnError -and ($ErrorCount -ne 0)
}


foreach ($vip in $VIP_Files.Keys)
{	if ((-not $StopCompiling) -and (Get-Variable $VIP_Files[$vip]["Variable"] -ValueOnly))
	{	$Library =			$VIP_Files[$vip]["Library"]
		$SourceFiles =	$VIP_Files[$vip]["Files"] | % { "$SourceDirectory\$_" }

		$ErrorCount += 0
		Start-PackageCompilation $GHDLBinary $GHDLOptions $DestinationDirectory $Library $VHDLVersion $SourceFiles $SuppressWarnings $HaltOnError -Verbose:$EnableVerbose -Debug:$EnableDebug
		$StopCompiling = $HaltOnError -and ($ErrorCount -ne 0)
	}
}

Write-Host "--------------------------------------------------------------------------------"
Write-Host "Compiling UVVM packages " -NoNewline
if ($ErrorCount -gt 0)
{	Write-Host "[FAILED]" -ForegroundColor Red				}
else
{	Write-Host "[SUCCESSFUL]" -ForegroundColor Green	}

Exit-CompileScript
