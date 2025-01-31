# Import the TagLib# library
Add-Type -Path "C:\Repos\taglib-sharp\src\TaglibSharp\bin\Debug\net6.0\TagLibSharp.dll" #https://github.com/mono/taglib-sharp - clone and build this project to get the DLL

# Set the path to your album folder
$albumFolder = read-host "Provide the path to your album folder without quotes" # Path to your album folder

# Set common metadata
$artist = "artist"
$albumTitle = "album"
$albumArtist = "FyreFurr"
$year = 2024
$genre = "genre"
$albumArtPath = read-host "Provide the path to your album art without quotes" # Path to your album art image

# Get all MP3 files in the album folder and subfolders
$mp3Files = Get-ChildItem -Path $albumFolder -Filter *.mp3 -Recurse

foreach ($file in $mp3Files) {
     # Load the MP3 file
     $tfile = [TagLib.File]::Create($file.FullName)

     # Extract the track number and title from the file name
     $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

     # Regular expression to match track number and title
     $regex = '^(?<TrackNumber>\d+)\s*[-.\s]\s*(?<Title>.+)$'

     if ($fileNameWithoutExtension -match $regex) {
          $trackNumber = [uint]$Matches['TrackNumber']
          $title = $Matches['Title']
     }
     else {
          # If no track number is found, set track number to 0 or handle as needed
          $trackNumber = 0
          $title = $fileNameWithoutExtension
     }

     # Determine Disc Number if using separate folders for bonus tracks
     if ($file.DirectoryName -like "*Bonus Tracks*") {
          $discNumber = 2
     }
     else {
          $discNumber = 1
     }

     # Set metadata
     $tfile.Tag.Title = $title
     $tfile.Tag.Performers = @($artist)
     $tfile.Tag.Album = $albumTitle
     $tfile.Tag.AlbumArtists = @($albumArtist)
     $tfile.Tag.Year = [uint]$year
     $tfile.Tag.Genres = @($genre)
     $tfile.Tag.Track = $trackNumber
     $tfile.Tag.Disc = [uint]$discNumber

     # Embed album art
     if (Test-Path $albumArtPath) {
          $albumArtBytes = [System.IO.File]::ReadAllBytes($albumArtPath)
          $picture = New-Object TagLib.Picture
          $picture.Type = [TagLib.PictureType]::FrontCover
          $picture.Description = "Cover"
          $picture.MimeType = "image/jpeg"
          $picture.Data = New-Object TagLib.ByteVector($albumArtBytes)
          $tfile.Tag.Pictures = @($picture)
     }
     else {
          Write-Warning "Album art image not found at $albumArtPath"
     }

     # Save changes
     $tfile.Save()
     $tfile.Dispose()

     Write-Host "Updated metadata for: $($file.Name)"
}

Write-Host "All metadata updated successfully!"