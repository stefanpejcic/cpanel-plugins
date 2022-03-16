<?php

if (!extension_loaded('json')) {
    header('Content-Type: text/html');
    echo 'Cannot load Extension JSON';
    exit;
}

$response['status'] = true;
$response['message'] = '';
$response['phpversion'] = phpversion();



//php extension
if (!extension_loaded('mysqlnd')) {
    $response['message'] = $response['message'] . ' / Cannot load PHP Extension (mysqlnd)';
    $response['status'] = false;
}
if (!extension_loaded('pdo')) {
    $response['message'] = $response['message'] . ' / Cannot load PHP Extension (pdo)';
    $response['status'] = false;
}
if (!extension_loaded('gd') && !extension_loaded('imagick')) {
    $response['message'] = $response['message'] . ' / Cannot load PHP Image Extension (GD  or  ImageMagick)';
    $response['status'] = false;
}
if (!extension_loaded('curl')) {
    $response['message'] = $response['message'] . ' / Cannot load PHP Extension (curl)';
    $response['status'] = false;
}
if (!extension_loaded('iconv')) {
    $response['message'] = $response['message'] . ' / Cannot load PHP Extension (iconv)';
    $response['status'] = false;
}
if (!extension_loaded('mbstring')) {
    $response['message'] = $response['message'] . ' / Cannot load PHP Extension (mbstring)';
    $response['status'] = false;
}
if (!extension_loaded('zip')) {
    $response['message'] = $response['message'] . ' / Cannot load PHP Extension (zip)';
    $response['status'] = false;
}
if (!extension_loaded('json')) {
    $response['message'] = $response['message'] . ' / Cannot load PHP Extension (json)';
    $response['status'] = false;
}
if (!extension_loaded('fileinfo')) {
    $response['message'] = $response['message'].' / Cannot load PHP Extension (fileinfo)';
    $response['status'] = false;
}
if (!extension_loaded('exif')) {
    $response['message'] = $response['message'].' / Cannot load PHP Extension (exif)';
    $response['status'] = false;
}
if (!extension_loaded('bcmath')) {
    $response['message'] = $response['message'].' / Cannot load PHP Extension (bcmath)';
    $response['status'] = false;
}
if (!extension_loaded('ctype')) {
    $response['message'] = $response['message'].' / Cannot load PHP Extension (ctype)';
    $response['status'] = false;
}
if (!extension_loaded('openssl')) {
    $response['message'] = $response['message'].' / Cannot load PHP Extension (openssl)';
    $response['status'] = false;
}
if (!extension_loaded('tokenizer')) {
    $response['message'] = $response['message'].' / Cannot load PHP Extension (tokenizer)';
    $response['status'] = false;
}
if (!extension_loaded('xml')) {
    $response['message'] = $response['message'].' / Cannot load PHP Extension (xml)';
    $response['status'] = false;
}
if (!extension_loaded('pdo_mysql')) {
    $response['message'] = $response['message'].' / Cannot load PHP Extension (pdo_mysql)';
    $response['status'] = false;
}

//php config
preg_match('/([0-9]+)/', ini_get('memory_limit'), $match);
if ($match[0] < 64) {
    $response['message'] = $response['message'] . ' / php.ini, Set Memory limit at least 64M.';
    $response['status'] = false;
}
/*
 if (ini_get('allow_url_fopen') != 1) {
 $response['message'] = $response['message'].' / php.ini, Must set allow_url_fopen=ON';
 $response['status'] = false;
 }
 */

//php function
if (!function_exists('posix_getpwuid') && (!function_exists('getmyuid') || (!function_exists('fileowner') && !function_exists('stat')))) {
    $response['message'] = $response['message'] . ' / Cannot load PHP Function (posix_getpwuid or getmyuid,fileowner)';
    $response['status'] = false;
}

if (!function_exists('file_put_contents')) {
    $response['message'] = $response['message'] . ' / Cannot load PHP Function (file_put_contents)';
    $response['status'] = false;
}

if ($response['status'] == true) {
    $response['message'] = "PHP Version,Extentsion,INI OK";
}

$response['phpini'] = '';
if (function_exists('php_ini_loaded_file')) {
    $response['phpini'] = php_ini_loaded_file();
}




header('Content-type: application/json');
echo json_encode($response);
