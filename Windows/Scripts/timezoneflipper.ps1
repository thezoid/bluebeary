# script to randomly change a devices time zone
# non-desctruvtive, but definitely disruptive
while($true){
     get-timezone -list | get-random | set-timezone
     $delayInSecs = 60*60*24*(Get-random -Minimum 0.1 -Maximum 30.0)
     start-sleep -seconds $delayInSecs
}