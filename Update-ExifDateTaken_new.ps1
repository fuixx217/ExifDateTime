Function Update-ExifDateTaken {
<#
.Synopsis
Changes the DateTaken EXIF property in an image file.
.DESCRIPTION
This script cmdlet updates the EXIF DateTaken property in an image by adding an offset to the 
existing DateTime value.  The offset (which must be able to be interpreted as a [TimeSpan] type)
can be positive or negative  moving the DateTaken value to a later or earlier time, respectively.
This can be useful (for example) to correct times where the camera clock was wrong for some reason  
perhaps because of timezones; or to synchronise photo times from different cameras.

.PARAMETER Path
The image file or files to process.

.PARAMETER DateTaken
The desired DateTaken to be assigned to the specified file(s).
Offset can be positive or negative and must be convertible to a [TimeSpan] type.

.PARAMETER PassThru
Switch parameter, if specified the paths of the image files processed are written to the pipeline.
The PathInfo objects are additionally decorated with the Old and New EXIF DateTaken values.

.EXAMPLE
[datetime]$datetaken="2019-01-26"; Update-ExifDateTaken -Path "C:\temp\from_pantry_view.JPG"
-DateTaken $datetaken -Verbose
Set the image "C:\temp\from_pantry_view.JPG" to 2019-01-26


#>

[CmdletBinding(SupportsShouldProcess=$True)]

Param (
[Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
[Alias('FullName', 'FileName')]
$Path,

[Parameter(Mandatory=$True)]
[datetime]$DateTaken,
#[ValidatePattern('YYYY-MM-DD')][string]$Date,

[Switch]$PassThru
)

Begin
{
Set-StrictMode -Version Latest
If ($PSVersionTable.PSVersion.Major -lt 3) {
Add-Type -AssemblyName 'System.Drawing'
#Add-Type -AssemblyName 'System.Drawing.Imaging.Metafile'
}

}

Process
{

#[datetime]$DateTaken = $Date

[datetime]$today = (get-date)
[TimeSpan]$Offset = New-TimeSpan -Start $today -End $DateTaken

# Cater for arrays of filenames and wild-cards by using Resolve-Path
Write-Verbose "Processing input item '$Path'"

$PathItems=Resolve-Path $Path -ErrorAction SilentlyContinue -ErrorVariable ResolveError
If ($ResolveError) {
Write-Warning "Bad path '$Path' ($($ResolveError[0].CategoryInfo.Category))"
}

Foreach ($PathItem in $PathItems) {
# Read the current file and extract the Exif DateTaken property

$ExifDT = $null

$ImageFile=(Get-ChildItem $PathItem.Path).FullName
$ImageFile

Try {
$FileStream=New-Object System.IO.FileStream($ImageFile,
[System.IO.FileMode]::Open,
[System.IO.FileAccess]::Read,
[System.IO.FileShare]::Read,
1024,     # Buffer size
[System.IO.FileOptions]::SequentialScan
)
$Img=[System.Drawing.Imaging.Metafile]::FromStream($FileStream)
#$Img.PropertyItems
$ExifDT=$Img.GetPropertyItem('36867')
}
Catch{
Write-Warning "Check $ImageFile is a valid image file ($_)"
If ($Img) {$Img.Dispose()}
If ($FileStream) {$FileStream.Close()}
Break
}
#region Convert the raw Exif data and modify the time

Try {
$ExifDtStringDt=[System.Text.Encoding]::ASCII.GetString($ExifDT.Value[0..9])
#$ExifDtString=([System.Text.Encoding]::ASCII.GetString($ExifDT.Value[0..9])) -replace ":", "-"
#$ExifDtStringDt=([System.Text.Encoding]::ASCII.GetString($ExifDT.Value[0..9])) -replace ":", "-"
$ExifDtString = "$ExifDtStringDt 00:00:00"
#$ExifDtString

# Convert the result to a [DateTime]
# Note: This looks like a string, but it has a trailing zero (0x00) character that 
# confuses ParseExact unless we include the zero in the ParseExact pattern.

"Old date taken value is $ExifDtString"

$OldTime=[datetime]::ParseExact($ExifDtString,"yyyy:MM:dd HH:mm:ss",$Null)
}
Catch {
Write-Warning "Problem reading Exif DateTaken string in $ImageFile ($_)"
# Only continue if an absolute time was specified
#Todo: Add an absolute parameter and a parameter-set
# If ($Absolute) {Continue} Else {Break}
$Img.Dispose();
$FileStream.Close()
Break
}

Write-Verbose "Extracted EXIF infomation from $ImageFile"
#Write-Verbose "Original Time is $($OldTime.ToString('F'))"

Try {
# Convert the time by adding the offset
$NewTime=(get-date).Add($Offset)
}
Catch {
Write-Warning "Problem with time offset $Offset ($_)"
$Img.Dispose()
$FileStream.Close()
Break
}

# Convert to a string, changing slashes back to colons in the date.  Include trailing 0x00
$ExifTime=$NewTime.ToString('yyyy:MM:dd HH:mm:ss`0')

Write-Verbose "New Time is $($NewTime.ToString('F')) (Exif: $ExifTime)"

#endregion

# Overwrite the EXIF DateTime property in the image and set
#$ExifDtNewValue = [Byte[]][System.Text.Encoding]::ASCII.GetBytes($ExifTime)
$ExifDT.Value=[Byte[]][System.Text.Encoding]::ASCII.GetBytes($ExifTime)
#$ExifDT.Value
#$ExifDtNew.
#"exif time bytes next"
#[Byte[]][System.Text.Encoding]::ASCII.GetBytes($ExifTime)

$Img.SetPropertyItem($ExifDT)
#$Img.SetPropertyItem($ExifDtNew)
#$Img.GetPropertyItem('36867').Value
#$ExifDT.Value


# Create a memory stream to save the modified image
$MemoryStream=New-Object System.IO.MemoryStream

Try {
# Save to the memory stream then close the original objects
# Save as type $Img.RawFormat  (Usually [System.Drawing.Imaging.ImageFormat]::JPEG)
$Img.Save($MemoryStream, $Img.RawFormat)

}
Catch {
Write-Warning "Problem modifying image $ImageFile ($_)"
$MemoryStream.Close(); $MemoryStream.Dispose()
Break
}
Finally {
$Img.Dispose()
$FileStream.Close()
}

# Update the file (Open with Create mode will truncate the file)

If ($PSCmdlet.ShouldProcess($ImageFile,'Update EXIF DateTaken')) {
Try {
$Writer = New-Object System.IO.FileStream($ImageFile, [System.IO.FileMode]::Create)
$MemoryStream.WriteTo($Writer)
}
Catch {
    $_.Exception.MEssage  
Write-Warning "Problem saving to $OutFile ($_)"
Break
}
Finally {
If ($Writer) {$Writer.Flush(); $Writer.Close()}
$MemoryStream.Close(); $MemoryStream.Dispose()
}
}
# Finally, if requested, decorate the path object with the EXIF dates and pass it on

If ($PassThru) {
$PathItem |
Add-Member -MemberType NoteProperty -Name ExifDateTaken -Value $NewTime -PassThru # |
#Add-Member -MemberType NoteProperty -Name ExifOriginalDateTaken -Value $OldTime -PassThru
}

[System.IO.FileSystemInfo]$fsInfo = new-object System.IO.FileInfo($PathItem)
[datetime]$early_create_date = "1971-01-02 00:00:00"

#if we specify a date before Jan 1 1971, the OS shell cannot display that in windows
#set the date to 1/2/1971 so that we at least see something for last modified date in
# windows explorer;  otherwise, set the date to the date taken
if ($DateTaken -lt $early_create_date) {
    $fsInfo.CreationTime = $early_create_date
    $fsInfo.LastWriteTime = $early_create_date
    $fsInfo.LastAccessTime = $early_create_date
}
else {
    $fsInfo.CreationTime = $DateTaken
    $fsInfo.LastWriteTime = $DateTaken
    $fsInfo.LastAccessTime = $DateTaken
}

} # End Foreach Path

} # End Process Block

End
{
# There is no end processing
}

} # End Function


#Update-ExifDateTaken -Path "C:\temp\AUS032_steve_sr1.jpg" -DateTaken $datetime