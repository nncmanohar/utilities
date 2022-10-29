function remove_empty_directories
{
	param(
        [String]$SRC_PATH
    )
	gci $SRC_PATH -Recurse -Directory | foreach {
	   if((gci $_.FullName) -eq $null)
	   {
			$_.FullName
		   Remove-Item $_.FullName
		}
	}
}

function get_source_hash
{
	param(
        [String]$Path
    )
	
	&{
		[IO.DirectoryInfo]::new($Path).GetFiles('*', 'AllDirectories')
	}|
	&{
		process
		{
			if ( $_.Length -ne 0 )
			{
				$_
			}
		}
		
	}|
	&{
		begin 
		{
			$hash = @{} 			
		}
		process
		{
			$file = $_
			$key = $file.Length.toString()
			if ($hash.ContainsKey($key) -eq $false) 
			{
				#$hash[$key] = [Collections.Generic.List[String]]::new()
				$hash[$key] = @{}
            }
			
			$MaxFileSize = 100KB
			$bufferSize = [Math]::Min(100KB, $MaxFileSize)
			$result = Get-PsOneFileHash -StartPosition 1KB -Length $MaxFileSize -BufferSize $bufferSize -AlgorithmName SHA1 -Path $file.FullName
			#$hash[$key].Add($result.Hash)
			$hash[$key][$result.Hash] = $result.Path
		}
		end
		{
			$hash
		}
	}
}

function check_files_to_copy
{
	param(
		[String]$Path,
        [hashtable]$Target
    )
	
	New-Item -Path "$($Path)" -Name "New" -ItemType "directory"
	New-Item -Path "$($Path)" -Name "Old" -ItemType "directory"
	&{
		[IO.DirectoryInfo]::new($Path).GetFiles('*', 'AllDirectories')
	}|
	&{
		process
		{
			if ( $_.Length -ne 0 )
			{
				$_
			}
		}
		
	}|
	&{
		process
		{
			$file = $_
			$key = $file.Length.toString()
			if ($Target.ContainsKey($key) -eq $True) 
			{
				$MaxFileSize = 100KB
				$bufferSize = [Math]::Min(100KB, $MaxFileSize)
				$result = Get-PsOneFileHash -StartPosition 1KB -Length $MaxFileSize -BufferSize $bufferSize -AlgorithmName SHA1 -Path $file.FullName
				if ($Target[$key].ContainsKey($result.Hash) -eq $True )
				{
					Move-Item -Path $file.FullName -Destination "$($Path)/Old"
					$Target[$key][$result.Hash]
				}
				else
				{
					Move-Item -Path $file.FullName -Destination "$($Path)/New"
				}
            }
			else
			{
					Move-Item -Path $file.FullName -Destination "$($Path)/New"
			}
		}
	}
}

function Get-PsOneFileHash
{
    [CmdletBinding(DefaultParameterSetName='File')]
    param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName='File',Position=0)]
        [string]
        [Alias('FullName')]
        $Path,

        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='String',Position=0)]
        [string]
        $String,

        [int]
        [ValidateRange(0,1TB)]
        $StartPosition = 1000,

        [long]
        [ValidateRange(1KB,1TB)]
        $Length = 1MB,

        [int]
        $BufferSize = 32KB,

        [Security.Cryptography.HashAlgorithmName]
        [ValidateSet('MD5','SHA1','SHA256','SHA384','SHA512')]
        $AlgorithmName = 'SHA1',

        [Switch]
        $Force
    )

    begin
    {
        $minDataLength = $BufferSize + $StartPosition

        $buffer = [Byte[]]::new($BufferSize)

        $isFile = $PSCmdlet.ParameterSetName -eq 'File'
    }

    
    process
    {
        $result = [PSCustomObject]@{
            Path = $Path
            Length = 0
            Algorithm = $AlgorithmName
            Hash = ''
            IsPartialHash = $false
            StartPosition = $StartPosition
            HashedContentSize = $Length
        }
        if ($isFile)
        {
            try
            {
                $file = [IO.FileInfo]$Path
                $result.Length = $file.Length

                $result.IsPartialHash = ($result.Length -gt $minDataLength) -and (-not $Force.IsPresent)
            }
            catch
            {
                throw "Unable to access $Path"
            }
        }
        else
        {
            $result.Length = $String.Length
            $result.IsPartialHash = ($result.Length -gt $minDataLength) -and (-not $Force.IsPresent)
        }
        try
        {
            $algorithm = [Security.Cryptography.HashAlgorithm]::Create($algorithmName)
        }
        catch
        {
            throw "Unable to initialize algorithm $AlgorithmName"
        }
        try
        {
            if ($isFile)
            {
                $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)

                if ($result.IsPartialHash)
                {
                    $bytesToRead = $Length

                    $stream.Position = $StartPosition

                    while($bytesToRead -gt 0)
                    {
                        $bytesRead = $stream.Read($buffer, 0, [Math]::Min($bytesToRead, $bufferSize))

                        if ($bytesRead -gt 0)
                        {
                            $bytesToRead -= $bytesRead

                            if ($bytesToRead -eq 0)
                            {
                                $null = $algorithm.TransformFinalBlock($buffer, 0, $bytesRead)
                            }
                            else
                            {
                                $null = $algorithm.TransformBlock($buffer, 0, $bytesRead, $buffer, 0)
                            }
                        }
                        else
                        {
                            throw 'This should never occur: no bytes read.'
                        }
                    }
                }
                else
                {
                    $null = $algorithm.ComputeHash($stream)
                }
            }
            else
            {
                if ($result.IsPartialHash)
                {
                    $bytes = [Text.Encoding]::UTF8.GetBytes($String.SubString($StartPosition, $Length))
                }
                else
                {
                    $bytes = [Text.Encoding]::UTF8.GetBytes($String)
                }

                $null = $algorithm.ComputeHash($bytes)
            }

            $result.Hash = [BitConverter]::ToString($algorithm.Hash).Replace('-','')

            if (!$result.IsPartialHash)
            {
                $result.StartPosition = 0
                $result.HashedContentSize = $result.Length
            }
        }
        catch
        {
            throw "Unable to calculate partial hash: $_"
        }
        finally
        {
            if ($PSCmdlet.ParameterSetName -eq 'File')
            {
                $stream.Close()
                $stream.Dispose()
            }

            $algorithm.Clear()
            $algorithm.Dispose()
        }
    
        return $result
    }
}