function Count-FilesRecursively {
    param (
        [Parameter(Mandatory=$true)]
        [string]$directory
    )

    # Get all files recursively from the directory and count them
    $fileCount = (Get-ChildItem -Path $directory -Recurse -File).Count
    return $fileCount
}

New-Alias -Name nof -Value Count-FilesRecursively

function Get-SubdirectoriesFileCount {
    param (
        [Parameter(Mandatory=$true)]
        [string]$parentDirectory
    )
    
    # Get all subdirectories in the parent directory
    $subDirectories = Get-ChildItem -Path $parentDirectory -Directory

	# Print header for clarity
    Write-Output ("{0,-30} {1,10}" -f "Subdirectory", "File Count")
    Write-Output ("{0,-30} {1,10}" -f ("-"*30) , ("-"*10))
	
	
    # Loop through each subdirectory and count files
    foreach ($subDir in $subDirectories) {
        $fileCount = Count-FilesRecursively -directory $subDir.FullName
        Write-Output ("{0,-30} {1,10}" -f $subDir.Name, $fileCount)
    }
}

New-Alias -Name nofr -Value Get-SubdirectoriesFileCount


$hash | ConvertTo-Json -Depth 10 | Set-Content $CacheFile
$hashTable = Get-Content "H:\hash_lookup.json" | ConvertFrom-Json -AsHashtable
