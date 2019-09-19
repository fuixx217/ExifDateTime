param([string]$file)

function GetTakenData($image) {
	try {
		return $image.GetPropertyItem(36867).Value
	}	
	catch {
		return $null
	}
}

[Reflection.Assembly]::LoadFile('C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Drawing.dll') | Out-Null
$image = New-Object System.Drawing.Bitmap -ArgumentList $file
try {
	$takenData = GetTakenData($image)
	if ($takenData -eq $null) {
		return $null
	}
	$takenValue = [System.Text.Encoding]::Default.GetString($takenData, 0, $takenData.Length - 1)
	$taken = [DateTime]::ParseExact($takenValue, 'yyyy:MM:dd HH:mm:ss', $null)
	return $taken
}
finally {
	$image.Dispose()
}