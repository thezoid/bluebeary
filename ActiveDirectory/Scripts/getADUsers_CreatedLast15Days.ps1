$When = ((Get-Date).AddDays(-15)).Date
# get all users matching the filter - we'll loop them later and access their fields
# -properties already limits what properties are pulled back to improve efficiency
$users = Get-ADUser -Filter {whenCreated -ge $When} -SearchBase "base DN" -Properties samaccountname,givenname,surname,userprincipalname
# cache the path to your report file - i like to use get-date to dynamically name them
$targetFile = "c:\path\to\your\report\$(get-date -Format "yyyyMMdd")_report.csv"
# overwrite or create a report at the location above
# since we do not -append on out-file, this wipes all content and only writes our headers on the first line
$headers = "First name, Last name, Email, UPN`n"
"$headers" | out-file $targetFile
# now we loop through all our users for report processing
foreach($user in $users){
    # access the current iteration's user object, and pulls data from the fields to interpolate into our string
    # we then pipe it into the out-file with -append to add it to the end of current file
    "$($user.givenname),$($user.surname),$($user.samaccountname),$($user.userprincipalname)" | out-file $targetFile -append
}