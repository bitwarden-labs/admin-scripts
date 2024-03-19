$name = 'NEW LOGIN ITEM'
$username = 'TestUser'
$password = 'Password123'
$collectionID = '7c0b62f1-2936-4777-b1bd-aaeb004af9cc'
$organizationID = '75aeb479-e2d7-4bd3-adb0-aaac005df65a'
bw sync
bw get template item | jq ('.name="""{0}""" | .login.username="""{1}""" | .login.password="""{2}"""' -f $name,$username,$password) | bw encode | bw create item
$objectID = bw list items --search $name | jq -r '.[].id'
echo ["""$collectionID"""] | bw encode | bw share $objectID $organizationID