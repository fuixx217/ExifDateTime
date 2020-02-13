Add-Type -AssemblyName 'System.Drawing'

Function Set-ExifDate {

    <#
        .Synopsis
        Changes the DateTaken EXIF property in an image file, and changes the
        last modified, last accessed, and created date/time values to the
        provided DateTaken value.

        .DESCRIPTION
        This function will override any previous values for the Exif field 
        "Date Taken", plus will override the "Last Modified", "Last Accessed",
        and "Created Date" to the provided DateTaken value.

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

    Param (
            [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
            [Alias('FullName', 'FileName')]
            $Path,
            [Parameter(Mandatory=$True)]
            [datetime]$DateTaken
    )
    #$Path = "\\diskstation\photo\From_Steve\Photos_and_videos\Family2_Scanned_From_Mom\1971\jun_1971Dad_8th_Grade.jpg"
    #$Path = "\\diskstation\photo\From_Steve\Photos_and_videos\Family2_Scanned_From_Mom\1984\aug_1984_stephen83_30_mos.jpg"
    #[datetime]$DateTaken = "1971-06-05";

    if (Test-Path $Path) {
        $PathItem = $Path
    }
    else {
        throw $_.Exception.Message
    }

$ImageFile=(Get-Item $PathItem).FullName
write-verbose "ImageFile variable is $ImageFile"

$FileStream= New-Object System.IO.FileStream($ImageFile,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::Read,
                1024,     # Buffer size
                [System.IO.FileOptions]::SequentialScan
            )
            $Img=[System.Drawing.Imaging.Metafile]::FromStream($FileStream)
#$Img.PropertyItems

#set up an item to update with the new date
write-verbose "no previous exif date (aka [date taken]) property exists"
                
$ExifTime = $DateTaken.ToString("yyyy:MM:dd HH:mm:ss`0")
#[Byte[]][System.Text.Encoding]::ASCII.GetBytes($ExifTime)

#"checking first found property"
#$PropertyItemId = $Img.PropertyItems[1].Id
#$PropertyItemId
#"after first found property"

#274 seems to exist for all files/images
#obtain a property to establish an object
$PropertyItemId = $Img.PropertyItems[1].Id
#$PropertyItemId
$ExistingProperty=$Img.GetPropertyItem("$PropertyItemId")
$ExistingProperty.Id = 36867
$ExistingProperty.Len = 41
$ExistingProperty.Type = 2
$ExistingProperty.Value = [Byte[]][System.Text.Encoding]::ASCII.GetBytes($ExifTime)
#Set Property 36867
$Prop36867 = $ExistingProperty
$Img.SetPropertyItem($Prop36867)

$MemoryStream=New-Object System.IO.MemoryStream
$Img.Save($MemoryStream, $Img.RawFormat)
$Img.Dispose()
$FileStream.Close()

$Writer = New-Object System.IO.FileStream($ImageFile, [System.IO.FileMode]::Create)
$MemoryStream.WriteTo($Writer)



If ($Writer) {$Writer.Flush(); $Writer.Close()}
$MemoryStream.Close(); $MemoryStream.Dispose()
#$Prop36867

[System.IO.FileSystemInfo]$fsInfo = new-object System.IO.FileInfo($PathItem)
        
        $fsInfo.CreationTime = $DateTaken
        $fsInfo.LastWriteTime = $DateTaken
        $fsInfo.LastAccessTime = $DateTaken


#$ExistingDateTaken=$Img.GetPropertyItem('36867')

#}