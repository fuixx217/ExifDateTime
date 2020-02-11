Function Update-LastModifiedDate {
<#
    .Synopsis
    Changes the CreationTime, LastWriteTime, and LastAccessTime on a file

    .DESCRIPTION
    This function will change the dates on a file to the provided date.

    .PARAMETER Path
    The image file(s) to process.

    .PARAMETER DateTaken
    The desired date to be assigned to the specified file(s).
    Expected to be a datetime type.

    .EXAMPLE
    [datetime]$datetaken="2019-12-06"; 
    Update-LastModifiedDate `
        -Path "C:\temp\from_stove_view.JPG" `
        -DateTaken $datetaken `
        -Verbose

    Set the image "C:\temp\from_stove_view.JPG" to 2019-01-26

#>

Param (
[Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)][Alias('FullName', 'FileName')]$Path,
[Parameter(Mandatory=$True)][datetime]$DateTaken
)

    # Cater for arrays of filenames and wild-cards by using Resolve-Path
    Write-Verbose "Processing input item '$Path'"

    if (Test-Path $Path) {
        $PathItem = $Path
    }
    else {
        throw $_.Exception.Message
    }

    Write-VErbose "Path is $Path"

        #$ImageFile=(Get-ChildItem $PathItem.Path).FullName
        $FileFullPath=(Get-Item $PathItem).FullName
        write-verbose "FileFullPath variable is $FileFullPath"

        [System.IO.FileSystemInfo]$fsInfo = new-object System.IO.FileInfo($FileFullPath)
        
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