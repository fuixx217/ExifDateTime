Add-Type -AssemblyName 'System.Drawing'

. .\Test-Image.ps1

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
        The image file to process.

        .PARAMETER DateTaken
        The desired DateTaken to be assigned to the specified file(s).
        Offset can be positive or negative and must be convertible to a [TimeSpan] type.

        .EXAMPLE
        Set-ExifDate `
            -Path "C:\temp\from_pantry_view.JPG"
            -DateTaken "2019-01-26" -Verbose
        Set the date taken and other dates on image "C:\temp\from_pantry_view.JPG" to 2019-01-26

        .EXAMPLE
        $path_to_search = "\\diskstation\photo\From_Steve\Photos_and_videos\Family2_Scanned_From_Mom\1992"
        $filesearch_pattern = "dec25_1992"; $date_taken = "1992-12-25"
        gci $path_to_search | `
            Where-Object {$_.Name -like "*$filesearch_pattern*"} | `
            %{
                Set-ExifDate `
                    -Path $_.FullName `
                    -DateTaken $date_taken
                
                Start-Sleep -Milliseconds 500
            }

        Loops through \\diskstation\photo\From_Steve\Photos_and_videos\Family2_Scanned_From_Mom\1984
        looking for files containing the text "dec25_1984", and then sets the date properties to
        "1984-12-25" for each of them.
    #>

    Param (
            [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
            [Alias('FullName', 'FileName')]
            [string]$Path,
            [Parameter(Mandatory=$True)]
            [datetime]$DateTaken
    )

    #Test to see if the file path exists; if not, throw an error
    if (Test-Path $Path) {
        $PathItem = $Path
    }
    else {
        throw $_.Exception.Message
    }

    #Test to see if the file provided is an image file.  If not, throw an error
    if (-not (Test-Image -Path $Path)) {
        throw "Not a valid image file that can have the Exif data modified"
    }

    #Load the image file into a FileStream variable
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

    #Establish a variable to be used for the expected format of the Exif Date Taken property
    $ExifTime = $DateTaken.ToString("yyyy:MM:dd HH:mm:ss`0")


    #obtain a property to establish an object to modify
    $PropertyItemId = $Img.PropertyItems[1].Id
    $ExistingProperty=$Img.GetPropertyItem("$PropertyItemId")

    #Change the values for each sub-property of the loaded ItemProperty
    #36867 is the Date Taken property ID
    #Len of 41 seemed to be what was on other images with the 36867 property already existing
    #Type 2 seemed to be what was on other images with the 36867 property already existing
    #Value is the encoded ASCII value of the DateTaken provided
    $ExistingProperty.Id = 36867
    $ExistingProperty.Len = 41
    $ExistingProperty.Type = 2
    $ExistingProperty.Value = [Byte[]][System.Text.Encoding]::ASCII.GetBytes($ExifTime)

    #Set Property 36867 on the $img variable loaded
    $Prop36867 = $ExistingProperty
    $Img.SetPropertyItem($Prop36867)

    #Establish a memory stream to stash the image to use later in the function
    $MemoryStream=New-Object System.IO.MemoryStream
    $Img.Save($MemoryStream, $Img.RawFormat)

    #close the image and file stream opened to read the image
    $Img.Dispose()
    $FileStream.Close()

    #Write the updated file from the memory stream that is still "active"
    $Writer = New-Object System.IO.FileStream($ImageFile, [System.IO.FileMode]::Create)
    $MemoryStream.WriteTo($Writer)

    #clean up variables for the writer and the memory stream
    If ($Writer) {$Writer.Flush(); $Writer.Close()}
    $MemoryStream.Close(); $MemoryStream.Dispose()


    #update the created date, last modified date, and last accessed date to that which was provided
    [System.IO.FileSystemInfo]$fsInfo = new-object System.IO.FileInfo($PathItem)
            
            $fsInfo.CreationTime = $DateTaken
            $fsInfo.LastWriteTime = $DateTaken
            $fsInfo.LastAccessTime = $DateTaken

    }