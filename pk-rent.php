<?php
function parseHeaders($headers) {
    $headerData = array();

    foreach ($headers as $header) {
        $parts = explode(':', $header, 2);
        if (count($parts) == 2) {
            $headerData[trim($parts[0])] = trim($parts[1]);
        }
    }
    return $headerData;
}
if(isset($argv[1]) && isset($argv[2])) {
    $user = $argv[1];
    $ebook = $argv[2];
// testovaci klic:
//$lib = '4171';
//$key = 'wb]jd7,}EW(H6J:lZ(mXHzes}nWqjcWY';
//
$lib = '5';
$key = 'phup3SteWUs6Ex3Beqaj7yabrEth4nek';
$method = 'POST';
$time = dechex(time());
$urlR = '/api/lib_rents';
//$body = array('user' => 'rena.pet@email.cz', 'count' => 1, 'ebook' => 206555);
$body = array('user' => $user, 'count' => 1, 'ebook' => $ebook);
$body = http_build_query($body);
$data = $method.$urlR.$body;
$time_key = hash_hmac('sha256', $lib.$time, $key, true);
$hmac = hash_hmac('sha256', $data, $time_key, true);
$authorization = $lib.':'.$time.':'.base64_encode($hmac);
$opts = array(
'http'=>array(
'method'=>$method,
'ignore_errors' => true,
'header'=>"Accept-language: cs\r\n" .
"Accept: text/xml;version=*\r\n" .
"Accept-Encoding: gzip\r\n".
"Content-type: application/x-www-form-urlencoded\r\n".
"Authorization: AB-HLIB $authorization\r\n",
'content' => $body,
'max_redirects' => 0,

),
);
$context = stream_context_create($opts);
$file = file_get_contents('https://core.palmknihy.cz'.$urlR, false, 
$context);

$header = parseHeaders($http_response_header);
if(!empty($header['Content-Encoding']))
{if($header['Content-Encoding'] == 'gzip')
  {$palmResponsefile = fopen("palm_response.gz", "w") ;
   fwrite($palmResponsefile, $file);
   fclose($palmResponsefile);
   exec('gunzip -f palm_response.gz 2>&1',$poutput);
   if ( $poutput )  echo $poutput;
   $palmResponse = file_get_contents("palm_response");
   $fileo=$palmResponse;
  }
 else
 throw new Exception('Unknown compression');
}

var_dump($header);
echo empty($fileo)?$file:$fileo;
}
?>