<?php
$response['phpversion'] = PHP_VERSION;
header('Content-type: application/json');
echo json_encode($response);
