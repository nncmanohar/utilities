function Find-PSOneDuplicateFileFast
{
  param
  (
    [String]
    [Parameter(Mandatory)]
    $Path,
  
    [String]
    $Filter = '*',
    
    [switch]
    $TestPartialHash,
    
    [int64]
    $MaxFileSize = 100KB
  )

  & { 
    try
    {
      Write-Progress -Activity 'Acquiring Files' -Status 'Fast Method'
      [IO.DirectoryInfo]::new($Path).GetFiles('*', 'AllDirectories')
    }
    catch
    {
      Write-Progress -Activity 'Acquiring Files' -Status 'Falling Back to Slow Method'
      Get-ChildItem -Path $Path -File -Recurse -ErrorAction Ignore
    }
  } | 
  & {
    process
    {
      if ($_.Length -gt 0)
      {
        $_
      }
    }
  } | 
  & { 
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
        $hash[$key] = [Collections.Generic.List[String]]::new()
        
      }
      $hash[$key].Add()
    } 
  
    end 
    { 
      foreach($pile in $hash.Values)
      {
        if ($pile.Count -gt 1)
        {
          $pile
        }
      }
    } 
  } | 
  & {
    end { ,@($input) }
  } |
  & {
    begin 
    {
      $hash = @{}
      $c = 0
    }
      
    process
    {
      $totalNumber = $_.Count
      foreach($file in $_)
      {
        $c++
        if ($c % 20 -eq 0 -or $file.Length -gt 100MB)
        {
          $percentComplete = $c * 100 / $totalNumber
          Write-Progress -Activity 'Hashing File Content' -Status $file.Name -PercentComplete $percentComplete
        }
      
        $bufferSize = [Math]::Min(100KB, $MaxFileSize)
        $result = Get-PsOneFileHash -StartPosition 1KB -Length $MaxFileSize -BufferSize $bufferSize -AlgorithmName SHA1 -Path $file.FullName
        

        if ($result.IsPartialHash) {
          $partialHash = 'P'
        }
        else
        {
          $partialHash = ''
        }
        
        
        $key = '{0}:{1}{2}' -f $result.Hash, $file.Length, $partialHash
      

        if ($hash.ContainsKey($key) -eq $false)
        {
          $hash.Add($key, [Collections.Generic.List[System.IO.FileInfo]]::new())
        }

        $hash[$key].Add($file)
      }
    }
      
    end
    {

      if ($TestPartialHash)
      {
        $keys = @($hash.Keys).Clone()
        $i = 0
        Foreach($key in $keys)
        {
          $i++
          $percentComplete = $i * 100 / $keys.Count
          if ($hash[$key].Count -gt 1 -and $key.EndsWith('P'))
          {
            foreach($file in $hash[$key])
            {
              Write-Progress -Activity 'Hashing Full File Content' -Status $file.Name -PercentComplete $percentComplete
              $result = Get-FileHash -Path $file.FullName -Algorithm SHA1
              $newkey = '{0}:{1}' -f $result.Hash, $file.Length
              if ($hash.ContainsKey($newkey) -eq $false)
              {
                $hash.Add($newkey, [Collections.Generic.List[System.IO.FileInfo]]::new())
              }
              $hash[$newkey].Add($file)
            }
            $hash.Remove($key)
          }
        }
      }
      
      $keys = @($hash.Keys).Clone()
      
      foreach($key in $keys)
      {
        if ($hash[$key].Count -eq 1)
        {
          $hash.Remove($key)
        }
      }
      $hash
    }
  }
}