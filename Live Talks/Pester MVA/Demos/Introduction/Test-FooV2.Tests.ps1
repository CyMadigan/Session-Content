. "$PSScriptRoot\Test-Foo.ps1"

describe 'Test-Foo' {

	BeforeAll {
		Write-Host 'Hi, I am in the BeforeAll block'
		Add-Content -Path TestDrive:\foofile.txt -Value 'foo'
		Add-Content -Path TestDrive:\nofoofile.txt -Value 'not here'
	}

	AfterAll {
		Write-Host 'Hi, I am in the AfterAll block.'
	}
	
	BeforeEach {
		Write-Host 'Hi, I am in the BeforeEach block'
	}

	AfterEach {
		Write-Host 'Hi, I am in the AfterEach block'
	}

	$fooutput = Test-Foo -FilePath TestDrive:\foofile.txt
    $nofooutput = Test-Foo -FilePath TestDrive:\nofoofile.txt

	it 'when the file has "foo" in it, it should return $true' {
		$fooutput | should be $true
        $fooutput | should beoftype 'bool'
        @($fooutput).Count | should be 1
	}

	it 'when the file does not have "foo" in it, it should return $false' {
		 $nofooutput | should be $false
	}
}