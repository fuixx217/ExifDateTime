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

Add-Type -AssemblyName 'System.Drawing'

    #[datetime]$DateTaken = $Date

    [datetime]$today = (get-date)
    [TimeSpan]$Offset = New-TimeSpan -Start $today -End $DateTaken

    Write-Verbose $Offset

    # Cater for arrays of filenames and wild-cards by using Resolve-Path
    Write-Verbose "Processing input item '$Path'"

    if (Test-Path $Path) {
        $PathItem = $Path
    }
    else {
        throw $_.Exception.Message
    }

    If ($ResolveError) {
        Write-Warning "Bad path '$Path' ($($ResolveError[0].CategoryInfo.Category))"
    }

        # Read the current file and extract the Exif DateTaken property


        Write-VErbose "foreach PathItem variable value is $PathItem"

        $ExifDT = $null

        #$ImageFile=(Get-ChildItem $PathItem.Path).FullName
        $ImageFile=(Get-Item $PathItem).FullName
        write-verbose "ImageFile variable is $ImageFile"

        Try {

            write-verbose "trying to populate FileStream variable"

            $FileStream= New-Object System.IO.FileStream($ImageFile,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::Read,
                1024,     # Buffer size
                [System.IO.FileOptions]::SequentialScan
            )
            $Img=[System.Drawing.Imaging.Metafile]::FromStream($FileStream)
            #$Img.PropertyItems

            #pull existing "Date Taken" value if it exists
            try {
                $ExistingDateTaken=$Img.GetPropertyItem('36867')
                $ExifDT = $ExistingDateTaken
            }
            catch {
                $ExifDT = $null;
            }
            #$ExifDT
        }
        Catch{
            Write-Warning "Check $ImageFile is a valid image file ($_)"
            If ($Img) {$Img.Dispose()}
            If ($FileStream) {$FileStream.Close()}
            Break
        }
        #region Convert the raw Exif data and modify the time

        Try {
            if ($null -ne $ExifDT) {
                
                Write-Verbose "Old date taken ASCII.GetString call next"
                #the first 10 characters will have the date without the time and that's all I really care about
                $ExifDtStringDt=([System.Text.Encoding]::ASCII.GetString($ExifDT.Value[0..9])) -replace ":", "-"
                
                Write-Verbose "Old date taken appending 00:00:00"
                $ExifDtStringDt = "$ExifDtStringDt 00:00:00`0"
                [datetime]$ExifDt2 = $ExifDtStringDt;
                Write-Verbose $ExifDt2

                # Convert the result to a [DateTime]
                # Note: This looks like a string, but it has a trailing zero (0x00) character that 
                # confuses ParseExact unless we include the zero in the ParseExact pattern.

                Write-Verbose "Old date taken value is $ExifDtStringDt"

                #$OldTime = [datetime]::ParseExact($ExifDtStringDt,"yyyy:MM:dd HH:mm:ss`0",$Null)  #uncomment this one after testing
                $OldTime = [datetime]::ParseExact($ExifDt2,"yyyy:MM:dd HH:mm:ss`0",$Null)  #uncomment this one after testing

                Write-Verbose "Old date taken is $OldTime"

            }
            else {
                #set up an item to update with the new date
                write-verbose "no previous exif date (aka [date taken]) property exists"
                
                #274 seems to exist for all files/images
                $ExistingProperty=$Img.GetPropertyItem('274')
                $ExistingProperty.Id = 36867
                $ExistingProperty.Len = 41
                $ExistingProperty.Type = 2
                $ExifDT = $ExistingProperty

            }
        }
        Catch {
            Write-Warning "Problem reading Exif DateTaken string in $ImageFile ($_)"
            # Only continue if an absolute time was specified
            #Todo: Add an absolute parameter and a parameter-set
            # If ($Absolute) {Continue} Else {Break}
            
            #removed when troubleshooting
            #$Img.Dispose();
            #$FileStream.Close()

            $ExistingProperty=$Img.GetPropertyItem('274')
            $ExistingProperty.Id = 36867
            $ExistingProperty.Len = 41
            $ExistingProperty.Type = 2
            $ExifDT = $ExistingProperty

            #Break
        }

        Write-Verbose "Extracted EXIF infomation from $ImageFile"

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
        $ExifDT.Value=[Byte[]][System.Text.Encoding]::ASCII.GetBytes($ExifTime)
        $Img.SetPropertyItem($ExifDT)



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

        If ($PSCmdlet.ShouldProcess($ImageFile,'Update EXIF DateTaken3')) {
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
        }

        Write-Verbose "PathItem is $PathItem"

        [System.IO.FileSystemInfo]$fsInfo = new-object System.IO.FileInfo($PathItem)
        
        $fsInfo.CreationTime = $DateTaken
        $fsInfo.LastWriteTime = $DateTaken
        $fsInfo.LastAccessTime = $DateTaken
        


        
        # [datetime]$early_create_date = "1980-01-02 00:00:00"
        # write-verbose "$early_create_date"
        

        # #if we specify a date before Jan 1 1980, the Windows Explorer UI cannot display that in windows
        # #set the date to 1/2/1980 so that we at least see something for last modified date in
        # # windows explorer;  otherwise, set the date to the date taken
        # if ($DateTaken -lt $early_create_date) {
        #     Write-Verbose "date taken less than early create date"
        #     $fsInfo.CreationTime = $early_create_date
        #     $fsInfo.LastWriteTime = $early_create_date
        #     $fsInfo.LastAccessTime = $early_create_date
        # }
        # else {
        #     $fsInfo.CreationTime = $DateTaken
        #     $fsInfo.LastWriteTime = $DateTaken
        #     $fsInfo.LastAccessTime = $DateTaken
        # }

}


#Update-ExifDateTaken -Path "C:\temp\AUS032_steve_sr1.jpg" -DateTaken $datetime