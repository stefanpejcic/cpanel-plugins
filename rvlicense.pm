#!/usr/bin/perl


use strict;
use File::Basename;
use Data::Dumper;
use Socket;
use IO::Socket;
use Cwd qw(realpath);
use Getopt::Long;
use Exporter;
use Digest::MD5 qw(md5_hex);
use MIME::Base64;
use LWP::UserAgent qw();
my $ua = LWP::UserAgent->new;
use IO::Socket::INET;



my $DEBUG = 0;
my $SERIALIZE_DBG = 0;
###start main###
##first to check ioncube
#my $ionCube = checkIoncube();
##install ioncube
#if(!$ionCube){
#    print "\nInstall ionCube...";
#   my $installed;
#   if (-f '/scripts/phpextensionmgr') {
#       $installed =  callBackticks('/scripts/phpextensionmgr --prefix /usr/local/cpanel/3rdparty install IonCubeLoader');
#       if ($installed=~/ioncube has been installed/ig) {
#               print " completed.\n";
#       }
#       else {
#               print " Can't install ionCube.\n";
#       }
#   } else {
#       print " Not found /scripts/phpextensionmgr.Can't install ionCube.\n";
#   }
#}

###end main###

#sub checkIoncube{
#    my $cmd = callBackticks("/usr/local/cpanel/3rdparty/bin/php -r 'if(extension_loaded(\"ionCube Loader\")){echo 1;}else{ echo 0;}'");
#    my $install = trim($cmd);
#    return $install;
#}
 
sub trim {
        my $string = $_[0];
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        return $string;
}


sub rvsLicenseEncode {
    my @aAllIP = getAllIP();
    _printdebug(join(" ","AllIP: ",@aAllIP));
    my $aRVCode = {
            'ips' => serialize(\@aAllIP),
            'virtualization' => 0,
            'encrypt-type' => 'ioncube',
            'license-code' => '',
    };
    $aRVCode = encodeData($aRVCode);
    $aRVCode =~ s/\r|\t|\n//gi;
    _printdebug("rvcode: $aRVCode");
    return $aRVCode;
}

sub getcontentbyurl {
    my ($url,$method,$args) = @_;

    my ($host,$port,$path) = extracturl($url);

    my %OPT = {};
    
    if ($url =~ '^https:\/\/') {
        $OPT{'usessl'} = 1;
    }

    $OPT{'host'} = $host;
    $OPT{'port'} = $port;
    $OPT{'request'} = $path;
    $OPT{'args'} = $args;
    $OPT{'method'} = (defined $method && $method ne '')? $method : 'GET';
    my %result =  _socket(%OPT);
    return %result;    
}


sub _socket {
    my %OPT = @_;
    
    #prepare vars
    my %result;    
    my ($host,$port,$request,$args,$method,$usessl);
       
    $host = defined $OPT{'host'} ? $OPT{'host'} : '';
    $port = defined $OPT{'port'} ? $OPT{'port'} : '';  
    $request = defined $OPT{'request'} ? $OPT{'request'} : '/'; 
    $args = defined $OPT{'args'} ? $OPT{'args'} : '';
    $method = defined $OPT{'method'} ? $OPT{'method'} : 'GET';
    $usessl = defined $OPT{'usessl'} ? $OPT{'usessl'} : 0;
    
    my ($authBasic,$user,$password,$accountEncode);
    
    $authBasic = defined $OPT{'authbasic'} ? $OPT{'authbasic'} : '0';
    $user = defined $OPT{'user'} ? $OPT{'user'} : ''; 
    $password = defined $OPT{'password'} ? $OPT{'password'} : '';
    
    $accountEncode = '';
    
    if ($authBasic) {
        $password =~ s/[\r\n]+//g;
        $accountEncode = "$user:$password";
        $accountEncode = encode_base64_2("$user:$password");
    }
    
    if ($usessl) {
        _printdebug("## SSL Connect ##");
        %result = _sslsocket($host,$port,$request,$args,$method,$accountEncode);
    } else {
        _printdebug("## None SSL Connect ##");
        %result = _nonsslsocket($host,$port,$request,$args,$method,$authBasic,$accountEncode);
    }
    return %result;
}

sub _nonsslsocket {
    my ($host,$port,$request,$args,$method,$authBasic,$accountEncode) = @_;
    
    $port = ($port ne '') ? $port : '80'; 
    
    my %result;
    my ($sin,$ipaddr,$len,$header);
    
    socket (SOCKET,PF_INET,SOCK_STREAM,0);
    
    $ipaddr = gethostbyname($host);
    if (!defined ($ipaddr)) {
        $result{'socketfail'} = "Cannot get protocal by hostname $host";
        return %result;
    }
    
    $sin = sockaddr_in($port,$ipaddr);
    if (!connect (SOCKET,$sin)) {
        $result{'socketfail'} = "Cannot create socket connection to server `$host`";
        return %result;
    }
    
    if ($method eq 'GET') {
        if ($args ne '') {
            $request .= "?$args";
        }
        $args = '';
    }
    
    my $oldfh = select(SOCKET);
    $| = 1;
    select($oldfh);
    my ($referer )="http://$host$request";
    
    $len = length($args);
    $header = "$method $request HTTP/1.0\r\n";
    $header .= "Content-Type: application/x-www-form-urlencoded\r\n";
    $header .= "Host: $host\r\n";
    $header .= "Content-Length: $len\r\n";
    $header .= "Connection: Keep-Alive\r\n";
    $header .= "Cache-Control: no-cache\r\n";
    $header .= "Referer: $referer\r\n";
    $header .= "\r\n";
    
    if ($authBasic) {
        $header .= "Authorization: Basic ".
        $accountEncode."\r\n";
    }
    
    $header.= $args;
    
    print SOCKET $header;
    
    my ($inheaders) = 1;
    
    my($chunk_size,$lefttoget,$thisread,$buf);


    while (<SOCKET>) {
       my $temp = $_;
        if ($temp =~/^\n|^\r\n$/) {
            $inheaders = 0;
        }

        chomp($temp);
        
        if($inheaders) { 
            $temp =~s/\n//g;
            $temp =~s/\s$//g;
            
            my ($key,$value)=split(/: /,$temp);
            chomp($key);
            chomp($value);
            if ($key =~/^http\//i) {
                $result{'header'}{'httpresponse'} = $temp;
            }
            $result{'header'}{lc($key)} = $value;
        } else {
            $result{'page'} .= $temp;
        }
    }
    close SOCKET;
    return %result;
}

sub _sslsocket {
    my ($host,$port,$request,$args,$method,$accountEncode) = @_;
     
    my %result;
    my $socketResult = '';
    my $page = '';
    my $httpresponse = ''; 
    my %headers;
    
    $port = ($port ne '') ? $port : '443';
    
    my $perlcommand = rvsWhich('perl');
    my $hasNetSSLeay = `$perlcommand -e 'eval { require Net::SSLeay; print 1; }' 2>&1`;
        
    if ($hasNetSSLeay ne '1') {
        $result{'socketfail'} = 'Not support Net::SSLeay';
        return %result;
    }
    
    if ( $method && $method eq 'POST' ) {
        $socketResult = `$perlcommand -e "
        use Net::SSLeay;
        print join\('{RVNL}',Net::SSLeay::post_https\( '$host', '$port', '$request',Net::SSLeay::make_headers\( 'Authorization' => 'Basic $accountEncode', 'Connection' => 'close' \),'$args'\)\);
        " 2>&1`;
    } else {
        if ($args ne '') {
            $request .= "?$args";
        }
        $socketResult = `$perlcommand -e "
        use Net::SSLeay;
        print join\('{RVNL}',Net::SSLeay::get_https\( '$host', '$port', '$request',Net::SSLeay::make_headers\( 'Authorization' => 'Basic $accountEncode', 'Connection' => 'close' \)\)\);
        " 2>&1`;
    }
    
    ($page, $httpresponse, %headers) = split('{RVNL}', $socketResult);
    
    $result{'header'}{'httpresponse'} = $httpresponse;
    foreach my $headkey(keys %headers) {
        $result{'header'}{lc($headkey)} = $headers{$headkey};
    }
    $result{'page'} = $page;
    return %result;
}

sub extracturl {
    my $url = $_[0];
    my ($host,$port,$path);
    $url =~s/http:\/\///;
    $url =~s/https:\/\///;
    $host = $url;
    if ($url =~ /\//) {
        ($host,$path)=split(/\//,$url,2);
        $path = '/' . $path;
        $url =~s/\/.*//;
    }
    if ($url =~ /:/) {
        ($host,$port) = split(/:/,$host,2);
    }    
    return ($host,$port,$path);
}

sub encode_base64_2 {
    my $res = "";
    my $eol = "\n";
    pos($_[0]) = 0;
    while ($_[0] =~ /(.{1,45})/gs) {
        $res .= substr(pack("u", $1), 1);
        chop($res);
    }
    $res =~ tr/` -_/AA-Za-z0-9+\//;
    my $padding = (3 - length($_[0]) % 3) % 3;
    $res =~ s/.{$padding}$/"=" x $padding/e if $padding;
    if (length $eol) {
        $res =~ s/(.{1,76})/$1$eol/g;
    }
    return $res;
}

sub _printdebug {
    my $msg = $_[0];
    print ":: LOG :: $msg\n" if $DEBUG;
}

sub getAllIP{
    my $cmd_uname = rvsWhich('uname');
    my $system = callBackticks("$cmd_uname -s");
    my @allIPList = ();
    $system =~s/\n|\r//gi;
    my $ips = '';
    my @ListIPS = ();
    if ( $system =~/freebsd/i) {
        $ips = callBackticks('/sbin/ifconfig -a');
    } else {
        $ips = callBackticks("/sbin/ifconfig");
    }
    @ListIPS = split('\n', $ips);
    foreach (@ListIPS) {
        if ( /(\d*)\.(\d*)\.(\d*).(\d*)/) {
            if ( $1 ne '127' ) {
                push(@allIPList, $1 . '.' . $2 . '.' . $3 . '.' . $4);
            }
        }
    }
    return @allIPList;
}

sub rvsWhich {
    my ($cmd) = $_[0];
    return if ($cmd eq '');
    return if ($cmd =~/\//);
    my @binpathList = (
        '/bin',
        '/usr/bin',
        '/usr/local/bin',
        '/sbin',
        '/usr/sbin',
        '/usr/local/sbin'
    );
    my $whichCmd = '';
    foreach my $path(@binpathList) {
        if ( -x $path . '/' . 'which') {
            $whichCmd = $path . '/' . 'which';
            last;
        }  
    }
    if ($whichCmd eq '') {
        print STDERR "which command is not support.\n";
        return '';
    } 
    my $binpath = '';
    
    $binpath = callBackticks("$whichCmd $cmd");
    chomp ($binpath);
    $binpath =~s/\n|\r//gi;
    
    if ($binpath eq '') {
        foreach my $path(@binpathList) {
            if ( -x $path . '/' . $cmd) {
                $binpath = $path . '/' . $cmd;
                last;
            }  
        }
    }

    if ($binpath eq '') {
        print STDERR "$cmd command is not support.\n";
        return '';
    }
    return $binpath;
}


sub encodeData{
    return MIME::Base64::encode(serialize($_[0]));
}

sub serialize {
    my ($ref) = @_;
    my $s;
    if ( ref($ref) =~ /hash|array/i ) {
        $s = serialize_sub( $ref, '', 1 );
    }
    else {
        return serialize_value($ref);
    }
    return $s;
}

sub serialize_sub {
    my ( $ref, $k, $no_key ) = @_;
    my $s;
    $s .= serialize_value($k) unless ($no_key);

    if ($no_key) {
        #print "\n\nno_key is set, ref=$ref, ". ref($ref) .", k=$k, s=$s\n\n";
    }

    if ( ref($ref) =~ /hash/i ) {
        my $num = keys( %{$ref} );
        $s .= "a:$num:{";
        foreach my $k ( keys(%$ref) ) {
            $s .= serialize_sub( $$ref{$k}, $k );
        }
        $s .= "}";
    }
    elsif ( ref($ref) =~ /array/i ) {
        my $num = @{$ref};
        $s .= "a:$num:{";
        for ( my $k = 0 ; $k < @$ref ; $k++ ) {
            $s .= serialize_sub( $$ref[$k], $k );
        }
        $s .= "}";
    }
    elsif ( !ref($ref) ) {
        $s .= serialize_value($ref);
    }
    else {
        die( "Cannot handle $ref = type (" . ref($ref) . ")" );
    }

    return $s;
}

sub serialize_value {
    my ($value) = @_;
    my $s;
    if ( $value =~ /^\-?\d+$/ ) {
        if ( abs($value) > 2**32 ) {
            $s = "d:$value;";
        }
        else {
            $s = "i:$value;";
        }
    }
    elsif ( $value =~ /^\-?(\d+)\.(\d+)$/ ) {
        $s = "d:$value;";
    }
    elsif ( $value eq "\0" ) {
        $s = "N;";
    }
    else {
        my $vlen = length($value);
        $s = "s:$vlen:\"$value\";";
    }

    return $s;
}

sub showerrortext {
    my %licensedata = @_;
    my $errorCode = $licensedata{'issue_id'};
    my $dateexpire = '';
    my $solutionbyproduct = '';
    my @monthname = qw(January February March April May June July August September October November December);  
    foreach my $keys(keys %licensedata) {
        if ($keys =~ /tmp_/i) {
            my ($S,$M,$H,$d,$m,$Y) = localtime($licensedata{$keys});
            $Y += 1900;
            $dateexpire = sprintf("%s %02d, %04d - %02d:%02d (GMT+0)", $monthname[$m], $d, $Y, $H, $M);
            last;
        }
        
    }
    my @allip = getAllIP();
    
    print "\n";
    if ($errorCode eq '001') {
        print "Unknown software code. Please contact RVStaff immediately at https://rvglobalsoft.com/tickets/new&deptId=2.";
    }
    elsif ($errorCode eq '002') {
        print "There's no IP to be submitted from this server environment. Please check IP setting in your server and fix it before trying to connect rvglobalsoft again.";
    }
    elsif ($errorCode eq '101') {
        print "RVsitebuilder license for ".join(" ",@allip)." has not been activated yet. ";
        if (defined $licensedata{'license_type'} && $licensedata{'license_type'} eq '0') {
            print "Please check your payment in https://rvglobalsoft.com/clientarea/invoices/ or check license status at https://rvglobalsoft.com/verifyrvlicense.";
        }
        if (defined $licensedata{'license_type'} && $licensedata{'license_type'} eq '1') {
            print "Please make sure you’ve added the license IP already in https://rvglobalsoft.com/clientarea/services/noc-licenses/.";
        }
    }
    elsif ($errorCode eq '301') {
       print "RVsitebuilder license for ".join(" ",@allip)." has been suspended. Last expiration date ".$dateexpire." . " ;
       if (defined $licensedata{'license_type'} && ($licensedata{'license_type'} eq '0' || $licensedata{'license_type'} eq '1')) { 
           print "Please login to your account to renew the pending invoice at https://rvglobalsoft.com/clientarea -> “Account” -> “Invoices” and pay the pending invoice.";
       }
       if (defined $licensedata{'license_type'} && $licensedata{'license_type'} eq '2') { 
           print "The license still can be used but can't update versions. Please login to your account at https://rvglobalsoft.com/clientarea, click “Service”  -> “Perpetual Licenses” -> check box infront of the license(s) you want to renew, click “Renew” botton.";
       }
    }
    elsif ($errorCode eq '302') {
       print "RVsitebuilder license for ".join(" ",@allip)." has been forced to suspend. Please contact RVGlobalsoft staff at https://rvglobalsoft.com/tickets/new&deptId=2." ;
    }
    elsif ($errorCode eq '401') {
       my $isPrivateIP = is_privateIP(@allip);
       if ($isPrivateIP) {
          my %yourPublicIP = getcontentbyurl('https://myip.cpanel.net/v1.0/');
          print "Your server is running behind NAT/Firewall IP ".join(" ",@allip)." with public IP ".$yourPublicIP{'page'}." which has not been found in our license system. Please update the license IP related to this server by this guide. https://rvglobalsoft.com/knowledgebase/article/306/order-and-change-ip-for-rv-product-licenses/" ;
       } else {
          print "None of this server IPs ".join(" ",@allip)." was found in RVGlobalsoft license system. Please validate license with RVGlobalsoft https://rvglobalsoft.com/verifyrvlicense, or contact rvstaff at https://rvglobalsoft.com/tickets/new&deptId=2." ;        
       }
    }
    elsif ($errorCode eq '402') {
       print "RVsitebuilder license for ".join(" ",@allip)." has more than 1 record. Please contact RVGlobalsoft staff at https://rvglobalsoft.com/tickets/new&deptId=2." ;
    }
    elsif ($errorCode eq '501') {
        print "RVsitebuilder license for ".join(" ",@allip)." has been expired. (".$dateexpire.") . " ;
        if (defined $licensedata{'license_type'} && ($licensedata{'license_type'} eq '0' || $licensedata{'license_type'} eq '1')) { 
           print "To avoid license suspended, please login to your account to renew at https://rvglobalsoft.com/clientarea -> “Account” -> “Invoices” and pay the pending invoice.";
        }
        if (defined $licensedata{'license_type'} && $licensedata{'license_type'} eq '2') { 
           print "The license still can be used but can't update versions. Please login to your account at https://rvglobalsoft.com/clientarea, click “Service”  -> “Perpetual Licenses” -> check box infront of the license(s) you want to renew, click “Renew” botton.";
        }
    }
    else {
        print "Unknown ERROR";
    }
    print "\n\n";
}

sub is_privateIP {
    my @ip = @_;
    foreach my $aip (@ip) {
       my @ipsplit =  split(/\./, $aip , 4);
       #if ip prefix is not 10,172,192, this ip is not private ip
       if ($ipsplit[0] !~/10|172|192/) {
           return 0;
       }
       my $ipCompare = join('',@ipsplit);
       if ($ipCompare >= 10000 && $ipCompare <= 10255255255) { #between 10.0.0.0 to 10.255.255.255
          return 1;
       }
       if ($ipCompare >= 1721600 && $ipCompare <= 17231255255) { #between 172.16.0.0 to 172.31.255.255
          return 1;
       }
       if ($ipCompare >= 19216800 && $ipCompare <= 192168255255) { #between 192.168.0.0 to 192.168.255.255
          return 1;
       }
    }
    return 0;
}

sub installershowinfotext {
    my (%licensedata) = @_;
    print "\nYour license Status : $licensedata{'rvsitebuilder'}{'status'}\n";
    print "Your license Expire Date : $licensedata{'rvsitebuilder'}{'expire-show'}\n";
}

#sub downloadlicensefile {
#    
#    my $rvadmindir = (getpwnam("rvadmin"))[7];  #normally is /home/rvadmin
#    print "Download RVSkin license file.\n";
#   my $serverData = callBackticks("/usr/local/cpanel/3rdparty/bin/php -r 'if(function_exists(\"ioncube_server_data\")) { echo ioncube_server_data(); }'");
#   if ( $serverData ) {
#       $serverData =~ s/\r|\n//g;
#       my $rvCode2 = getRvCode2($serverData);
#       _printdebug("rvCode2: $rvCode2");
#       my $url = "https://license2.rvglobalsoft.com/downloadlicense/rvskin";
#       _printdebug("url for download licensefile: $url");
#       
#       my %result = getcontentbyurl($url,'POST',"rvcode=$rvCode2");
#       if (!defined $result{'page'} || $result{'socketfail'}) {
#            print "\nERROR : $result{'socketfail'} \n";
#       }
#       writeFile('rvskinlicense.tar',$result{'page'});    
#
#       my $fileCommand = rvsWhich('file');
#       my $resultFile = callBackticks($fileCommand . ' rvskinlicense.tar');
#       if($resultFile =~/tar archive/gi){
#           system('tar','-xvf','rvskinlicense.tar');
#           if (-d $rvadmindir) {
#               system('chown','rvadmin:rvadmin','rvskin.lic'); 
#                system('mv','-f','rvskin.lic',"$rvadmindir");
#           }     
#           if (!-l '/usr/local/cpanel/Cpanel/rvskin.lic' && -f "$rvadmindir/rvskin.lic") {
#                system('ln','-s',$rvadmindir.'/rvskin.lic','/usr/local/cpanel/Cpanel/');
#           }
#           system('rm','-f','rvskinlicense.tar');
#           return 1;
#       }
#   }
#   
#   print "Can't get ioncube_server_data.\nCan't download RVSkin license file.\n";
#   return 0;
#}

sub writeFile {
    my ($path, $linesRef) = @_;
    my $iswriteFile = 0;
    if (open(my $FILEWrite, '>', $path)) {
        print $FILEWrite $linesRef;
        close($FILEWrite);
        $iswriteFile = 1;
    }
    return $iswriteFile;
}

sub getRvCode2{
    my $data = $_[0];
    my @allIp = getAllIP();
    
    my $rvcode = {
        'ips' => serialize(\@allIp),
        'virtualization' => 0,
        'encrypt-type' => 'ioncube',
        'license-code' => $data,
    };
    $rvcode = encodeData($rvcode);
    $rvcode =~ s/\r|\n|\t//gi;
    return $rvcode;
}

sub callBackticks{
    my $cmd = join(' ', @_);

    if (-f '/tmp/.rvsSkinBackticks') {
        system('rm -f /tmp/.rvsSkinBackticks');
    }
    
    my ($TestBackticks) = `echo 'RV Test RVSkin Backticks'`;
    my ($skipBackticks) = 0;
    if ($TestBackticks !~/RV Test RVSkin Backticks/) {
        $skipBackticks = 1;
    }
    if (-f '/tmp/.rvsSkinBackticks' || $skipBackticks eq 1) {
        system("$cmd > /tmp/.rvsSkinBackticks 2>&1");
    }
    my ($resuft);
    if (-f '/tmp/.rvsSkinBackticks') {
        if (open(my $fd, '<', '/tmp/.rvsSkinBackticks')) {
            $resuft = join('',<$fd>);
            close($fd);
        }
        system('rm -f /tmp/.rvsSkinBackticks');
    } else {
        $resuft = `$cmd 2>&1`;
    }
 
    return $resuft;
}

sub decodeData{
    eval {
        return %{unserialize(MIME::Base64::decode($_[0]))};
    };
}

sub unserialize {
    my ($string) = @_;
    if ( $string =~/^a:(\d+):({(.*)})$/s ) {
        print "Unserializing complex array ($string)" if ($SERIALIZE_DBG);
        my $keys = $1 * 2;
        my @chars = split( //, $2 );
        undef $string;

        return unserialize_sub( {}, $keys, \@chars );
    }
    elsif ( $string =~/^s/ ) {
        print "Unserializing single string ($string)" if ($SERIALIZE_DBG);

        $string =~/^s:(\d+):/;
        return substr( $string, length($1) + 4, $1 );
    }
    elsif ( $string =~/^i|^d/ ) {
        print "Unserializing integer or double ($string)" if ($SERIALIZE_DBG);

        return substr( $string, 2 ) + 0;
    }
    elsif ( $string =~/^N/i ) {
        print "Unserializing NULL value ($string)" if ($SERIALIZE_DBG);

        return "\0";
    }
    else {
        print "Unserializing BAD DATA! ($string)" if ($SERIALIZE_DBG);

        return '';
    }
}

sub unserialize_sub {
    my ( $hashref, $keys, $chars ) = @_;
    my ( $temp, $keyname, $skip, $strlen );
    my $mode = 'normal';

    print "unserialize: $hashref, $keys, $chars\n" if ($SERIALIZE_DBG);

    while ( defined( my $c = shift @{$chars} ) ) {
        print "\t[$mode] = $c\n" if ($SERIALIZE_DBG);

        if ( $mode eq 'string' ) {
            $skip = 1;
            if ( $c =~/\d+/ ) {

                $strlen = $strlen . $c;
                print "string length = $strlen ($c)\n" if ($SERIALIZE_DBG);
            }
            if ( ( $strlen =~/\d+/ ) && ( $c eq ':' ) ) {
                $mode = 'readstring';
            }

        }
        elsif ( $mode eq 'readstring' ) {

            next if ( $skip-- > 0 );
            $mode = 'set', next if ( !$strlen-- );

            $temp .= $c;

        }
        elsif ( $mode eq 'integer' ) {
            next if ( $c eq ':' );
            $mode = 'set', next if ( $c eq ';' );

            if ( $c =~/\-|\d+/ ) {
                if ( $c eq '-' ) {
                    $temp .= $c unless $temp;
                }
                else {
                    $temp .= $c;
                }
            }

        }
        elsif ( $mode eq 'double' ) {
            next if ( $c eq ':' );
            $mode = 'set', next if ( $c eq ';' );

            if ( $c =~/\-|\d+|\./ ) {
                if ( $c eq '-' ) {
                    $temp .= $c unless $temp;
                }
                else {
                    $temp .= $c;
                }
            }

        }
        elsif ( $mode eq 'null' ) {
            $temp = "\0";
            $mode = 'set', next;
        }
        elsif ( $mode eq 'array' ) {
            if ( $c eq '{' ) {
                $$hashref{$keyname} = unserialize_sub( $$hashref{$keyname}, ( $temp * 2 ), $chars );
                undef $keyname;
                $mode = 'normal';

            }
            elsif ( $c =~/\d+/ ) {
                $temp = $temp . $c;
                print "array_length = $temp ($c)\n" if ($SERIALIZE_DBG);
            }

        }
        elsif ( $mode eq 'set' ) {
            if ( defined($keyname) ) {
                print "set VALUE=$temp\n" if ($SERIALIZE_DBG);

                $$hashref{$keyname} = $temp;

                undef $keyname;

            }
            else {
                print "set KEYNAME=$temp\n" if ($SERIALIZE_DBG);
                $keyname = $temp;
            }

            $mode = 'normal';
        }

        if ( $mode eq 'normal' ) {
            $strlen = $temp = '';

            if ( !$keys ) {
                print "return, no more keys to process = ($keys)\n" if ($SERIALIZE_DBG);
                return $hashref;
            }

            if ( $c eq 'i' ) {
                $mode = 'integer';
                $keys--;
            }

            if ( $c eq 'd' ) {
                $mode = 'double';
                $keys--;
            }

            if ( $c eq 'b' ) {
                $mode = 'integer';
                $keys--;
            }

            if ( $c eq 's' ) {
                $mode = 'string';
                $keys--;
            }

            if ( $c eq 'a' ) {
                $mode = 'array';
                $keys--;
            }

            if ( $c eq 'N' ) {
                $mode = 'null';
                $keys--;
            }

        }

    }
    print "return normally (chars=" . ( join ',', @$chars ) . ")\n" if ($SERIALIZE_DBG);
    return $hashref;
}




1;