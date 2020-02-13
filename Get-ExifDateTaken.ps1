<#
ExifDateTime
Chris Warwick, @cjwarwickps, August 2013
This version: November 2015
The module contains two functions:
    Get-ExifDateTaken -Path <filepaths>
        Takes a file (fileinfo or string) or an array of these
        Gets the ExifDT value (EXIF Property 36867)
    Update-ExifDateTaken -Path <filepaths> -Offset <TimeSpan>
        Takes a file (fileinfo or string) or an array of these
        Modifies the ExifDT value (EXIF Property 36867) as specified
# Example: Rename files based on DateTaken value
gci *.jpg |
 Get-ExifDateTaken |
 Rename-Item -NewName {"Holiday Snap {0:MM-dd HH.mm.ss dddd} ({1}).jpg" -f $_.ExifDateTaken, (Split-Path (Split-Path $_) -Leaf)}
# Example: Correct DateTake value on a set of .jpg images by specifying a time offset
gci *.jpg|Update-ExifDateTaken -Offset '-0:07:10' -PassThru|ft Path, ExifDateTaken
# Example: Update DateTaken & Rename files based on Date
gci *.jpg |
 Update-ExifDateTaken -Offset '-0:07:10' -PassThru |
 Rename-Item -NewName {"Holiday Snap {0:MM-dd HH.mm.ss dddd} ({1}).jpg" -f $_.ExifDateTaken, (Split-Path (Split-Path $_) -Leaf)}
#>

#Requires -Version 2.0


<#
.Synopsis
   Gets the DateTaken EXIF property in an image file.
.Description
   This cmdlet reads the EXIF DateTaken property in an image and passes is down the pipeline
   attached to the PathInfo item of the image file.
.Parameter Path
   The image file or files to process.
.Example
   Get-ExifDateTaken img3.jpg
   Reads the img3.jpg file and returns the im3.jpg PathInfo item with the EXIF DateTaken attached
.Example
   Get-ExifDateTaken *3.jpg |ft path, exifdatetaken
   Output the EXIF DateTaken values for all matching files in the current folder
.Example
   gci *.jpeg,*.jpg|Get-ExifDateTaken 
   Read multiple files from the pipeline
.Example
   gci *.jpg|Get-ExifDateTaken|Rename-Item -NewName {"Holiday Snap {0:MM-dd HH.mm.ss}.jpg" -f $_.ExifDateTaken}
   Gets the EXIF DateTaken on multiple files and renames the files based on the time
.Outputs
   The scripcmdlet outputs FileInfo objects with an additional ExifDateTaken
   property that can be used for later processing.
.Functionality
   Gets the EXIF DateTaken image property on a specified image file.
#>
Function Get-ExifDateTaken {
[OutputType([System.IO.FileInfo])]
Param (
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
    [Alias('FullName', 'FileName')]
    $Path
)



    Begin 
    {
        Set-StrictMode -Version Latest
        If ($PSVersionTable.PSVersion.Major -lt 3) {
            Add-Type -AssemblyName 'System.Drawing'
        }

    }



    Process 
    {
        # Cater for arrays of filenames and wild-cards by using Resolve-Path
        Write-Verbose -Message "Processing input item '$Path'"
        
        
        $FileItems = Resolve-Path $Path -ErrorAction SilentlyContinue -ErrorVariable ResolveError
        If ($ResolveError) {
            Write-Warning -Message "Bad path '$Path' ($($ResolveError[0].CategoryInfo.Category))"
        }


        Foreach ($FileItem in $FileItems) {
            # Read the current file and extract the Exif DateTaken property

            $ImageFile = (Get-ChildItem $FileItem.Path).FullName

            # Parameters for FileStream: Open/Read/SequentialScan
            $FileStreamArgs = @(
                $ImageFile
                [System.IO.FileMode]::Open
                [System.IO.FileAccess]::Read
                [System.IO.FileShare]::Read
                1024,     # Buffer size
                [System.IO.FileOptions]::SequentialScan
            )


            Try {
                $FileStream = New-Object System.IO.FileStream -ArgumentList $FileStreamArgs
                $Img = [System.Drawing.Imaging.Metafile]::FromStream($FileStream)
                $Img.PropertyItems
                $ExifDT = $Img.GetPropertyItem('36867')
            }
            Catch{
                Write-Warning -Message "Check $ImageFile is a valid image file ($_)"
                If ($Img) {$Img.Dispose()}
                If ($FileStream) {$FileStream.Close()}
                Break
            }
    

            # Convert the raw Exif data

            Try {
                $ExifDtString=[System.Text.Encoding]::ASCII.GetString($ExifDT.Value)

                # Convert the result to a [DateTime]
                # Note: This looks like a string, but it has a trailing zero (0x00) character that 
                # confuses ParseExact unless we include the zero in the ParseExact pattern....

                $OldTime = [datetime]::ParseExact($ExifDtString,"yyyy:MM:dd HH:mm:ss`0",$Null)      
            }
            Catch {
                Write-Warning -Message "Problem reading Exif DateTaken string in $ImageFile ($_)"
                Break
            }
            Finally {
                If ($Img) {$Img.Dispose()}
                If ($FileStream) {$FileStream.Close()}
            }

            Write-Verbose -Message "Extracted EXIF infomation from $ImageFile"
            Write-Verbose -Message "Original Time is $($OldTime.ToString('F'))"   

            # Decorate the path object with the EXIF dates and pass it on...

            $FileItem | Add-Member -MemberType NoteProperty -Name ExifDateTaken -Value $OldTime -PassThru

        } # End Foreach Path

    } # End Process Block



    End
    {
        # There is no end processing...
    }


} # End Function