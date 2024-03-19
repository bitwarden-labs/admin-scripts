
$bw_clientid="" #fill this with your API client id
$bw_clientsecret="" #fill this with your API secret
$org_id="" #fill this with your org id
$bw_path="" #FULL path to your BW CLI, including bw.exe
$user_pass="" #password of your account
$exformat="json" #format of the export
$expath="" #FULL path to save the export

#export API id and secret
$env:BW_CLIENTID=$bw_clientid
$env:BW_CLIENTSECRET=$bw_clientsecret


& $bw_path login --apikey

if ($?) {
	$session_key= & $bw_path unlock $user_pass --raw
	& $bw_path export $user_pass --output $expath --format $exformat --organizationid $org_id --session $session_key
}

& $bw_path logout