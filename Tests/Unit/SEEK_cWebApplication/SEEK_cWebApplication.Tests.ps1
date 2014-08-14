$module = Join-Path $PSScriptRoot "..\..\..\Modules\Seek - Modules\cWebAdministration\DSCResources\SEEK_cWebApplication\SEEK_cWebApplication.psm1"
$code = Get-Content $module | Out-String
Invoke-Expression $code

Mock Find-UniqueWebApplication {return $null}
Mock Remove-WebApplication
Mock Test-AuthenticationEnabled { return $false }


$MockWebApplication = New-Object PSObject
$MockWebApplication | Add-Member PhysicalPath "C:\App"
$MockWebApplication | Add-Member ApplicationPool "MyAppPool"

Describe "Get-TargetResource" {
    Context "when the web application is present" {
        Mock Find-UniqueWebApplication { return $MockWebApplication }
        Mock Test-AuthenticationEnabled { return $true } `
            -ParameterFilter { ($Type -eq "Anonymous") }
        Mock Test-AuthenticationEnabled { return $true } `
            -ParameterFilter { ($Type -eq "Windows") }

        It "returns the web application state as a hashtable" {
            $WebApplication = Get-TargetResource -Website "MySite" -Name "MyApp"
            $WebApplication.WebSite | Should Be "MySite"
            $WebApplication.Name | Should Be "MyApp"
            $WebApplication.Ensure | Should Be "Present"
            $WebApplication.PhysicalPath | Should Be "C:\App"
            $WebApplication.WebAppPool | Should Be "MyAppPool"
            $WebApplication.AuthenticationInfo.CimInstanceProperties["Anonymous"].Value | Should Be "true"
            $WebApplication.AuthenticationInfo.CimInstanceProperties["Basic"].Value | Should Be "false"
            $WebApplication.AuthenticationInfo.CimInstanceProperties["Digest"].Value | Should Be "false"
            $WebApplication.AuthenticationInfo.CimInstanceProperties["Windows"].Value | Should Be "true"
        }
    }

    Context "when the web application is absent" {
        It "returns an absent web application hashtable" {
            $WebApplication = Get-TargetResource -Website "MySite" -Name "MyApp"
            $WebApplication.WebSite | Should Be "MySite"
            $WebApplication.Name | Should Be "MyApp"
            $WebApplication.Ensure | should be "Absent"
            $WebApplication.PhysicalPath | Should Be $null
            $WebApplication.WebAppPool | Should Be $null
            $WebApplication.AuthenticationInfo | Should Be $null
        }
    }
}

Describe "Test-TargetResource" {
    Context "when the web application is present" {
        Mock Find-UniqueWebApplication { return $MockWebApplication }

        It "returns true if the web application should be present" {
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Present" -WebAppPool "MyAppPool" -PhysicalPath "C:\App" | Should Be $true
        }

        It "returns false if the web application should be absent" {
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Absent" -WebAppPool "MyAppPool" -PhysicalPath "C:\App" | Should Be $false
        }

        It "returns false if the web application pool is different" {
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Present" -WebAppPool "OtherAppPool" -PhysicalPath "C:\App" | Should Be $false
        }

        It "returns false if the physical path is different" {
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Present" -WebAppPool "MyAppPool" -PhysicalPath "C:\OtherPath" | Should Be $false
        }

        It "returns true if the authentication info is the same" {
            Mock Test-AuthenticationEnabled { return $true } `
                -ParameterFilter { ($Type -eq "Anonymous") }
            Mock Test-AuthenticationEnabled { return $true } `
                -ParameterFilter { ($Type -eq "Windows") }
            $authInfo = New-CimInstance -ClassName SEEK_cWebAuthenticationInformation -ClientOnly -Property @{Anonymous="true";Basic="false";Digest="false";Windows="true"}
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Present" -WebAppPool "MyAppPool" -PhysicalPath "C:\App" -AuthenticationInfo $authInfo | Should Be $true
        }

        It "returns false if the authentication info is different" {
            Mock Test-AuthenticationEnabled { return $true } `
                -ParameterFilter { ($Type -eq "Anonymous") }
            Mock Test-AuthenticationEnabled { return $false } `
                -ParameterFilter { ($Type -eq "Windows") }
            $authInfo = New-CimInstance -ClassName SEEK_cWebAuthenticationInformation -ClientOnly -Property @{Anonymous="true";Basic="false";Digest="false";Windows="true"}
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Present" -WebAppPool "MyAppPool" -PhysicalPath "C:\App" -AuthenticationInfo $authInfo | Should Be $false
        }
    }

    Context "when the web application is absent" {
        It "returns false if the web application should be present" {
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Present" -WebAppPool "MyAppPool" -PhysicalPath "C:\App" | Should Be $false
        }

        It "returns true if the web application should be absent" {
            Test-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Absent" -WebAppPool "MyAppPool" -PhysicalPath "C:\App" | Should Be $true
        }
    }
}

Describe "Set-TargetResource" {
    Mock New-WebApplication
    Mock Remove-WebApplication
    Mock Set-ItemProperty
    Mock Set-WebConfigurationProperty

    Context "when the web application is absent" {
        It "installs the web application" {
            Set-TargetResource -Website "MySite" -Name "MyApp" -WebAppPool "MyAppPool" -PhysicalPath "C:\App"
            Assert-MockCalled New-WebApplication -Exactly 1
        }
    }

    Context "when the web application is present" {
        Mock Find-UniqueWebApplication { return $MockWebApplication }

        It "does nothing" {
            Set-TargetResource -Website "MySite" -Name "MyApp" -WebAppPool "MyAppPool" -PhysicalPath "C:\App"
            Assert-MockCalled New-WebApplication -Times 0
        }
    }

    Context "when configuration specifies the web application should be absent" {
        It "removes the web application if the web application is present" {
            Mock Find-UniqueWebApplication { return $MockWebApplication }
            Set-TargetResource -Website "MySite" -Name "MyApp" -Ensure "Absent" -WebAppPool "MyAppPool" -PhysicalPath "C:\App"
            Assert-MockCalled Remove-WebApplication -Exactly 1
        }
    }
}
