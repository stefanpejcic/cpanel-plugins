    package Cpanel::API::RVsitebuilderCMS;

    use strict;
    use warnings;
    use Cpanel::FileUtils          ();
    use LWP::UserAgent;
    use JSON;
    use JSON::WebToken;
    use DBI;
    use DBD::mysql;
    use Cpanel::API ();
    use Cpanel::SafeRun::Object ();
    use MIME::Base64   ();
    use Cpanel::API ();
    use Cpanel::JSON::Sanitize  ();
    use Cpanel::JSON            ();

    our %API = (
        list_website => { allow_demo => 1 },
        get_rvsb7_cpplugin_version => { allow_demo => 1 },
    );


    sub isCloudlinux {
        my ($arags , $result) = @_;
        if (-f '/etc/sysconfig/lve') {

            open (my $FD , '<' , '/etc/sysconfig/lve');
            my (@line) = <$FD>;
            close($FD);

            my (%lveConf);

            foreach my $inLine(@line) {
                chomp($inLine);
                my ($key , $val) = split(/=/ , $inLine , 2);
                chomp($key); chomp($val);
                $lveConf{$key} = $val;
            }

            if (defined $lveConf{'LVE_ENABLE'} && lc($lveConf{'LVE_ENABLE'}) eq 'yes') {
                $result->data({
                    success => 'true' ,
                    is_cloudlinux => 1,
                    reason => '',
                    exectime => 0,
                });
                return 1;
            } else {
                $result->data({
                    success => 'true' ,
                    is_cloudlinux => 0,
                    reason => '',
                    exectime => 0,
                });
                return 1;
            }
        } else {
            $result->data({
                success => 'false' ,
                is_cloudlinux => 0,
                reason => '',
                exectime => 0,
            });
            return 1;
        }
    }

    sub check_license {
        my ( $args, $result ) = @_;
        #TODO check license process
        $result->data(
                {
                    success => 'true' ,
                    license_status => 'valid',
                    check_license => 1,
                    license_expire => '',
                    license_info => '',
                    reason => '',
                    exectime => 0,
                }
        );
        #debug_log('check_license',('success' => 'true','license_status' => 'valid'));
        return 1;
    }

    sub disk_required {
        my ( $args, $result ) = @_;
        #TODO check license process
        $result->data(
                {
                    success => 'true' ,
                    disk_required => 1,
                    reason => '',
                    exectime => 0,
                }
        );
        #debug_log('disk_required',('success' => 'true','disk_required' => '1'));
        return 1;
    }

    sub load_installer_config {

        my $publicpath = $_[0];

        my $installerconfig =  {};

        #1 default config
        $installerconfig->{'mirror'} = "http://files.mirror1.rvsitebuilder.com";
        # $installerconfig->{'urldownload'} = "/download/rvsitebuilderinstaller/setup";
        $installerconfig->{'setup'}->{'getversion'} = "stable";
        $installerconfig->{'removeinstallerpath'} = "true";
        $installerconfig->{'debug_log'} = "false";
        $installerconfig->{'framework_version'}->{'getversion'} = "stable";
        $installerconfig->{'version_url'} = "https://getversion.rvsitebuilder.com";

        #2 root config
        my $rootconfig = {};
        if(-f '/usr/local/rvglobalsoft/rvsitebuilder7/.rvsitebuilderinstallerconfig/root_config.ini') {
            if(!-f "$publicpath/.rvsitebuilderinstallerconfig"){
                mkdir("$publicpath/.rvsitebuilderinstallerconfig");
            }
            system("cp","-af","/usr/local/rvglobalsoft/rvsitebuilder7/.rvsitebuilderinstallerconfig/root_config.ini","$publicpath/.rvsitebuilderinstallerconfig/");
            system("chown","$Cpanel::user:$Cpanel::user","$publicpath/.rvsitebuilderinstallerconfig/root_config.ini");
            $rootconfig = parseIniFile("$publicpath/.rvsitebuilderinstallerconfig/root_config.ini");
        }
        if(defined $rootconfig->{'mirror'} && $rootconfig->{'mirror'} ne ''){
            $installerconfig->{'mirror'} = $rootconfig->{'mirror'};
        }
        # if(defined $rootconfig->{'setup'}->{'getversion'}  && $rootconfig->{'setup'}->{'getversion'} =~ m/latest|stable/ ) {
        #     $installerconfig->{'urldownload'} = "/download/rvsitebuilderinstaller/setup/tier/".$rootconfig->{'setup'}->{'getversion'};
        # }
        # if(defined $rootconfig->{'setup'}->{'getversion'}  && $rootconfig->{'setup'}->{'getversion'} =~ m/[0-9]+\.[0-9]+\.[0-9]+/ ) {
        #     $installerconfig->{'urldownload'} = "/download/rvsitebuilderinstaller/setup/version/".$rootconfig->{'setup'}->{'getversion'};
        # }
        if(defined $rootconfig->{'setup'}->{'getversion'}  && $rootconfig->{'setup'}->{'getversion'} ne "" ) {
            $installerconfig->{'setup'}->{'getversion'} = $rootconfig->{'setup'}->{'getversion'};
        }
        if(defined $rootconfig->{'removeinstallerpath'} && $rootconfig->{'removeinstallerpath'} =~ m/true|false/ ) {
            $installerconfig->{'removeinstallerpath'} = $rootconfig->{'removeinstallerpath'};
        }
        if(defined $rootconfig->{'debug_log'} && $rootconfig->{'debug_log'} =~ m/true|false/ ) {
            $installerconfig->{'debug_log'} = $rootconfig->{'debug_log'};
        }
        if(defined $rootconfig->{'framework'}->{'getversion'} && $rootconfig->{'framework'}->{'getversion'} ne ''){
            $installerconfig->{'framework_version'} = $rootconfig->{'framework'}->{'getversion'};
        }
        if(defined $rootconfig->{'version'} && $rootconfig->{'version'} ne ''){
            $installerconfig->{'version_url'} = $rootconfig->{'version'};
        }

        #3 user config
        my $userconfig = {};
        if(-f "$publicpath/.rvsitebuilderinstallerconfig/config.ini") {
            $userconfig = parseIniFile("$publicpath/.rvsitebuilderinstallerconfig/config.ini");
        }
        if(defined $userconfig->{'mirror'} && $userconfig->{'mirror'} ne ''){
            $installerconfig->{'mirror'} = $userconfig->{'mirror'};
        }
        # if(defined $userconfig->{'setup'}->{'getversion'}  && $userconfig->{'setup'}->{'getversion'} =~ m/latest|stable/ ) {
        #     $installerconfig->{'urldownload'} = "/download/rvsitebuilderinstaller/setup/tier/".$userconfig->{'setup'}->{'getversion'};
        # }
        # if(defined $userconfig->{'setup'}->{'getversion'}  && $userconfig->{'setup'}->{'getversion'} =~ m/[0-9]+\.[0-9]+\.[0-9]+/ ) {
        #     $installerconfig->{'urldownload'} = "/download/rvsitebuilderinstaller/setup/version/".$userconfig->{'setup'}->{'getversion'};
        # }
        if(defined $userconfig->{'setup'}->{'getversion'}  && $userconfig->{'setup'}->{'getversion'} ne "" ) {
            $installerconfig->{'setup'}->{'getversion'} = $userconfig->{'setup'}->{'getversion'};
        }
        if(defined $userconfig->{'removeinstallerpath'} && $userconfig->{'removeinstallerpath'} =~ m/true|false/ ) {
            $installerconfig->{'removeinstallerpath'} = $userconfig->{'removeinstallerpath'};
        }
        if(defined $userconfig->{'debug_log'} && $userconfig->{'debug_log'} =~ m/true|false/ ) {
            $installerconfig->{'debug_log'} = $userconfig->{'debug_log'};
        }
        if(defined $userconfig->{'framework'}->{'getversion'} && $userconfig->{'framework'}->{'getversion'} ne ''){
            $installerconfig->{'framework_version'} = $userconfig->{'framework'}->{'getversion'};
        }
        if(defined $userconfig->{'version'} && $userconfig->{'version'} ne ''){
            $installerconfig->{'version_url'} = $userconfig->{'version'};
        }

        return $installerconfig;
    }
    sub get_version_download {
        my $getversion = $_[0];
        my $versiondownload = "";
        my $defaultversion = "";
        my $ghrepos = "https://api.github.com/repos/rvsitebuilder-service/setup/releases?per_page=100";

        # latest -download the latest release version
        # stable -download stable version that latest release doesn't look alpha , beta
        # beta,alpha -download the latest released version and the name contains the words "alpha" or "beta"
        # version specific (vx.x.x or vx.x.x-beta.xxx) -download according to the specified version

        # curl   -H "Accept: application/vnd.github.v3+json"   https://api.github.com/repos/rvsitebuilder-service/setup/releases
        my $res =  request_LwpUserAgent_get(
                                        $ghrepos,
                                        {'Accept' => 'application/vnd.github.v3+json'},
                                    );

        if ($res->is_success) {
            #print STDERR Cpanel::JSON::Dump( Cpanel::JSON::Sanitize::sanitize_for_dumping($res->decoded_content));
            #print STDERR $res->decoded_content;
            my $response = decode_json($res->decoded_content);
            if ($getversion eq "latest") {
                #print STDERR @$response[0]->{'tag_name'}."\n";
                $versiondownload = @$response[0]->{'tag_name'};
            } else {
                foreach my $index (@$response) {
                    #print STDERR $index->{'tag_name'}."\n";
                    if ($index->{'tag_name'} =~ m/v?[0-9]+\.[0-9]+\.[0-9]+$/ && $defaultversion eq ""){
                        $defaultversion = $index->{'tag_name'};
                    }
                    if ($getversion eq "stable" && $index->{'tag_name'} =~ m/v?[0-9]+\.[0-9]+\.[0-9]+$/){
                        $versiondownload = $index->{'tag_name'};
                        last;
                    }
                    elsif ($getversion eq "alpha" && $index->{'tag_name'} =~ m/v[0-9]+\.[0-9]+\.[0-9]+\-alpha\.[0-9]+$/) {
                        $versiondownload = $index->{'tag_name'};
                        last;
                    } elsif ($getversion eq "beta" && $index->{'tag_name'} =~ m/v[0-9]+\.[0-9]+\.[0-9]+\-beta\.[0-9]+$/) {
                        $versiondownload = $index->{'tag_name'};
                        last;
                    } elsif (($getversion =~ m/v?[0-9]+\.[0-9]+\.[0-9]+/ || $getversion =~ m/v?[0-9]+\.[0-9]+\.[0-9]+\-(beta|alpha)\.[0-9]+/)
                            && ($index->{'tag_name'} =~ m/v?$getversion/)) {
                        $versiondownload = $index->{'tag_name'};
                        last;
                    }
                }
            }

        }

        #default
        if ($versiondownload eq ""){
            $versiondownload = $defaultversion;
        }

        #print STDERR "\nversiondownload $versiondownload\n";
        return $versiondownload;
    }

    sub prepare_installer {
        my ( $args, $result ) = @_;
        my ( $publicpath) = $args->get( 'publicpath');
        my $domainname = $args->get( 'domainname');
        my $protocal = (defined $args->get( 'protocal')) ? $args->get( 'protocal') : 'https://';

        my $installerconfig =  load_installer_config($publicpath);
        # my $mirror = $installerconfig->{'mirror'};
        # my $versiondownload = $installerconfig->{'urldownload'};
        my $mirror = "https://api.github.com/repos/rvsitebuilder-service/setup/zipball";
        my $versiondownload = get_version_download($installerconfig->{'setup'}->{'getversion'});
        debug_log($publicpath ,'prepare_installer',('mirror' => $mirror,'urldownload' => $versiondownload));

        #download by wget
        my $wget = check_wget();
        if(! $wget) {
            $result->data(
                {
                    success => 'false' ,
                    reason => "Cannot use 'wget' command",
                    prepare_installer => 0,
                }
            );
            debug_log($publicpath ,'prepare_installer',('success' => 'false','reason' => 'Cannot use wget'));
            return 1;
        }
        chdir($publicpath);
        # my @cmd_args = (
        #     $mirror.'/'.$versiondownload,
        #     '--header','RV-Referer: '.$protocal.$domainname,
        #     '--header','Allow-GATracking: true',
        #     '--header','RV-Product: rvsitebuilder',
        #     '--header','RV-License-Code: '.getLicenseCode(),
        #     '--header','User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36',
        #     '--header','RV-Forword-REMOTE-ADDR: '.getRemoteAddr($domainname),
        #     '-O','setup.zip',
        # );
        my @cmd_args = (
            $mirror.'/'.$versiondownload,
            '--no-check-certificate',
            '--header','Accept: application/vnd.github.v3+json',
            '--output-document','setup.zip',
        );

        my $run = Cpanel::SafeRun::Object->new(
                                                program => $wget,
                                                args    => \@cmd_args,
                                                timeout => 120,
                                            );

        debug_log($publicpath ,'prepare_installer',('wget' => $wget,'args' => join(" ",@cmd_args)));
        if ( !$run ) {
            $result->data(
                {
                    success => 'false' ,
                    reason => "Failed to invoke 'wget' binary.",
                    prepare_installer => 0,
                }
            );
            debug_log($publicpath ,'prepare_installer',('success' => 'false','reason' => 'Failed to invoke \'wget\' binary.'));
            return 1;
        }
        my $rc = $run->CHILD_ERROR() >> 8;
        if ( $rc != 0 ) {
            my $stderr = "Error encountered while running 'wget' command.\n" . $run->stderr();
            $stderr =~ s/\n+\z//s;
            $result->data(
                {
                    success => 'false' ,
                    reason => $stderr,
                    prepare_installer => 0,
                }
            );
            debug_log($publicpath ,'prepare_installer',('success' => 'false','reason' =>  $stderr));
            return 1;
        }
        #extract with zip
        my $unzip = check_zip();
        if(! $unzip) {
            $result->data(
                {
                    success => 'false' ,
                    reason => "Cannot use 'unzip' command",
                    prepare_installer => 0,
                }
            );
            debug_log($publicpath ,'prepare_installer',('success' => 'false','reason' =>  'Cannot use unzip command'));
            return 1;
        }
        my @cmd_args = (
            "-o",
            "$publicpath/setup.zip"
        );
        my $run = Cpanel::SafeRun::Object->new(
            program => $unzip,
            args    => \@cmd_args
        );
        debug_log($publicpath ,'prepare_installer',('unzip' => $unzip ,'args' => join(" ",@cmd_args)));
        if ( !$run ) {
            $result->data(
                {
                    success => 'false' ,
                    reason => "Failed to invoke 'unzip' binary.",
                    prepare_installer => 0,
                }
            );
            debug_log($publicpath ,'prepare_installer',('success' => 'false' ,'reason' => 'Failed to invoke \'unzip\' binary.'));
            return 1;
        }
        my $rc = $run->CHILD_ERROR() >> 8;
        if ( $rc != 0 ) {
            my $stderr = "Error encountered while running 'unzip' command.\n" . $run->stderr();
            $stderr =~ s/\n+\z//s;
            $result->data(
                {
                    success => 'false' ,
                    reason => $stderr,
                    prepare_installer => 0,
                }
            );
            debug_log($publicpath ,'prepare_installer',('success' => 'false' ,'reason' => $stderr));
            return 1;
        }

        #rename dir rvsitebuilder-service-setup-* to rvsitebuilder
        my @installerdir = glob("$publicpath/rvsitebuilder-service-setup-*");
        system("mv",$installerdir[0],"$publicpath/rvsitebuilder");

        my ($success,$response,$page,$repheader) =  request_netSSLeay($protocal , $domainname , '/rvsitebuilder/setup.php' ,
                                                            ('Installtype' => 'cpanel','RV-License-Code' => getLicenseCode())
                                                        );
        debug_log($publicpath ,'prepare_installer',('protocal' => $protocal ,'domainname' => $domainname ,'request' => '/rvsitebuilder/setup.php'));
        if(! $success) {
            $result->data(
                    {
                        success => 'false' ,
                        reason => $response,
                        prepare_installer => 0,
                        page => $page,
                        response => $response
                    }
                );
            debug_log($publicpath ,'prepare_installer',('success' => 'false' ,'reason' => $response ,'page' => $page));
            return 1;
        }

        #if can't exec because web not run as user
        #chmod if not run as user check file install is downloaded
        #and request again
        if(!-f "$publicpath/rvsitebuilder/install.tar.gz") {
            debug_log($publicpath,'prepare_installer',('message' => 'not found '.$publicpath.'/rvsitebuilder/install.tar.gz'));
            system("chmod","0777","$publicpath/rvsitebuilder");
            ($success,$response,$page,$repheader) =  request_netSSLeay($protocal, $domainname , '/rvsitebuilder/setup.php' ,
                                                            ('Installtype' => 'cpanel','RV-License-Code' => getLicenseCode())
                                                        );
            debug_log($publicpath ,'prepare_installer',('protocal' => $protocal ,'domainname' => $domainname ,'request' => '/rvsitebuilder/setup.php'));
            if(! $success) {
                $result->data(
                        {
                            success => 'false' ,
                            reason => $response,
                            prepare_installer => 0,
                            page => $page,
                            response => $response
                        }
                    );
                debug_log($publicpath ,'prepare_installer',('success' => 'false','reason' => $response,'page' => $page));
                return 1;
            }
        }

        #check again
        if(!-f "$publicpath/rvsitebuilder/install.tar.gz") {
            $result->data(
                    {
                        success => 'false' ,
                        reason => $response,
                        prepare_installer => 0
                    }
                );
                debug_log($publicpath ,'prepare_installer',('success' => 'false','reason' => $response));
            return 1;
        }

        #call to real installer
        ($success,$response,$page,$repheader) =  request_netSSLeay($protocal, $domainname , '/rvsitebuilder/setupapiserver.php' , ());
        debug_log($publicpath ,'prepare_installer',('protocal' => $protocal ,'domainname' => $domainname ,'request' => '/rvsitebuilder/setupapiserver.php'));

        if($response !~ /200 OK/) {
            $result->data(
                {
                    success => 'false' ,
                    reason => "Error ".$page." (".$response.")" ,
                    prepare_installer => 0,
                    page => $page,
                    response => $response
                }
            );
            debug_log($publicpath ,'prepare_installer',('success' => 'false' ,'reason' => "Error ".$page." (".$response.")" ));
            return 1;
        }



        my $pagejson = eval  { decode_json($page) };
        if($@){
            $result->data(
                {
                    success => 'false' ,
                    reason => "decode_json failed, invalid json. error: ".$@,
                    prepare_installer => 0,
                    page => $page,
                    response => $response
                }
                );
                debug_log($publicpath ,'prepare_installer',('success' => 'false' ,'reason' => "decode_json failed, invalid json. error: ".$@ ));
                return 1;
        }

        $result->data(
                {
                    success => 'true' ,
                    reason => $pagejson->{'message'},
                    rvsb_installing_token => $pagejson->{'rvsb_installing_token'},
                    prepare_installer => ($pagejson->{'status'}) ? 1 : 0,
                    exectime => (defined $pagejson->{'exectime'}) ? $pagejson->{'exectime'}  : 0,
                    page => $page,
                    response => $response
                }
        );
        debug_log($publicpath ,'prepare_installer',('success' => 'true' ,'reason' => $pagejson->{'message'} ,'status' => $pagejson->{'status'}));
        return 1;
    }

    sub getRemoteAddr() {
        my $domainname = $_[0];
        require Cpanel::API::DomainInfo;
        my $domainsIP = Cpanel::API::_execute("DomainInfo","single_domain_data",{'domain' => $domainname});
        return $domainsIP->{'data'}->{'ip'};
    }

    sub getLicenseCode() {
        my @aAllIP = getAllIP();
        my @arrLicense = ({'timestamp' => time() } , {'ips' => \@aAllIP});
        my $aRVCode = MIME::Base64::encode_base64(encode_json( \@arrLicense ));
        $aRVCode =~ s/\r|\t|\n//gi;
        return $aRVCode;

    }

    sub getAllIP() {
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



    sub request_netSSLeay {

        my ($protocal,$domainname,$request,%header) = @_;

        eval { use Net::SSLeay qw(get_https get_http post_https sslcat make_headers make_form); };
        if ($@) {
            return (0,'Module Net::SSLeay Error (Can\'t use module Net::SSLeay)','');
        }

        my ($page, $response, %headers);
        if($protocal eq 'https://') {
            ($page, $response, %headers) = Net::SSLeay::get_https(
                                                                $domainname,
                                                                443,
                                                                $request,
                                                                make_headers(%header),
                                                            );
        }
        else {
            ($page, $response, %headers) = Net::SSLeay::get_http(
                                                                $domainname,
                                                                80,
                                                                $request,
                                                                make_headers(%header),
                                                            );
        }

        #debug
        #print STDERR "\n";
        #foreach my $key (keys %headers) {
        #    print STDERR $key.' '.$headers{$key};."\n";
        #}
        #print STDERR "response $response \n";
        #print STDERR "page $page \n";


        return (1,$response, $page, \%headers);
    }

    sub test_ssl_connect {

        my $domainname = $_[0];
        my $request = $_[1];
        my $allowredirect = $_[2];
        my $ua = LWP::UserAgent->new();

        $ua->agent('Chrome/70.0.3538.110');
        $ua->ssl_opts(verify_hostname => 1);
        if($allowredirect){
            $ua->requests_redirectable(['GET','HEAD','POST']);
        } else {
            $ua->requests_redirectable([]);
        }

        #HTTPS
        my $urlreg = 'https://'.$domainname.$request;
        my $res = $ua->get($urlreg);

        #debug
        #print STDERR "urlreg -> $urlreg\n";
        #print STDERR "status_line -> ".$res->status_line."\n";
        #print STDERR "is_success -> ".$res->is_success."\n";
        #print STDERR "decoded_content -> ".$res->decoded_content."\n";
        #print STDERR "as_string -> ".$res->as_string."\n";
        #print STDERR "resp code -> ".$res->code."\n";

        # 200 OK
        if ($res->is_success && $res->status_line =~ /200/) {
            return {'protocal'=>'https://','success'=>$res->is_success,'strresponse'=>$res->decoded_content,'status'=>$res->status_line,'respcode'=>$res->code};
        }
        # 301,302 Moved to www.domainname.com
        elsif (($res->status_line =~ /301/ || $res->status_line =~ /302/) && $res->decoded_content =~ /www\.$domainname/) {
            my $protocal = 'http://';
            if($res->decoded_content =~ /href="https:/){
                $protocal = 'https://';
            }
            $urlreg = $protocal.'www.'.$domainname.$request;
            $res = $ua->get($urlreg);
            return {'protocal'=>$protocal,'success'=>$res->is_success,'strresponse'=>$res->decoded_content,'status'=>$res->status_line,'respcode'=>$res->code};
        }
        # 404 Not Found , 403 Forbidden , 400 Bad Request
        elsif ($res->status_line =~ /400/ || $res->status_line =~ /403/ || $res->status_line =~ /404/){
            return {'protocal'=>'https://','success'=>$res->is_success,'strresponse'=>$res->decoded_content,'status'=>$res->status_line,'respcode'=>$res->code};
        }
        # 500 Name or service not known , 900 ssl error
        else {
            #HTTP
            my $urlreg = 'http://'.$domainname.$request;
            my $res = $ua->get($urlreg);

            #debug
            #print STDERR "status_line -> ".$res->status_line."\n";
            #print STDERR "is_success -> ".$res->is_success."\n";
            #print STDERR "decoded_content -> ".$res->decoded_content."\n";
            #print STDERR "as_string -> ".$res->as_string."\n";
            #print STDERR "resp code -> ".$res->code."\n";

            # 200 OK
            if ($res->is_success && $res->status_line =~ /200/) {
                return {'protocal'=>'http://','success'=>$res->is_success,'strresponse'=>$res->decoded_content,'status'=>$res->status_line,'respcode'=>$res->code};
            }
            # 404 Not Found , 403 Forbidden , 400 Bad Request
            elsif ($res->status_line =~ /400/ || $res->status_line =~ /403/ || $res->status_line =~ /404/){
                return {'protocal'=>'http://','success'=>$res->is_success,'strresponse'=>$res->decoded_content,'status'=>$res->status_line,'respcode'=>$res->code};
            }
            # 301,302 Moved , 500 Name or service not known , 900 ssl error
            else {
                return {'protocal'=>'http://','success'=>$res->is_success,'strresponse'=>$res->decoded_content,'status'=>$res->status_line,'respcode'=>$res->code};
            }
        }

    }

    sub protocal_connect {
        my ( $args, $result ) = @_;
        my ( $domainname) = $args->get( 'domainname');
        my ( $request) = $args->get( 'request');

        my $connect =  test_ssl_connect($domainname,$request,1);
        $result->data(
                {
                    success => 'true' ,
                    reason => "",
                    protocal_connect => 1,
                    protocal => $connect->{'protocal'},
                    success => $connect->{'success'},
                    strresponse => $connect->{'strresponse'},
                    status => $connect->{'status'},
                }
        );
        return 1;
    }

    sub pre_check_php {
        my ( $args, $result ) = @_;
        my ( $domainname) = $args->get( 'domainname');
        my $publicpath = $args->get( 'publicpath');
        my $tokenkey = $args->get( 'tokenkey');
        my $protocal = (defined $args->get( 'protocal')) ? $args->get( 'protocal') : 'https://';

        my ($success,$response,$page,$repheader) =  request_netSSLeay($protocal, $domainname , '/rvsitebuilder/setupapiserver.php?action=pre_check_php' , ('Rvsb-Installing-Token' => $tokenkey));
        debug_log($publicpath ,'pre_check_php',('protocal' => $protocal ,'domainname' => $domainname ,'request' => '/rvsitebuilder/setupapiserver.php?action=pre_check_php'));

        if($response !~ /200 OK/) {
            $result->data(
                {
                    success => 'false' ,
                    reason => "Error $page ($response)",
                    pre_check_php => 0,
                    httpasuser => 'false',
                    page => $page,
                    response => $response
                }
            );
            debug_log($publicpath ,'pre_check_php',('success' => 'false' ,'reason' => "Error $page ($response)"));
            return 1;
        }
        my $pagejson = decode_json($page);
        $result->data(
                {
                    success => 'true' ,
                    reason => $pagejson->{'message'},
                    pre_check_php => ($pagejson->{'status'}) ? 1 : 0,
                    httpasuser => $pagejson->{'httpasuser'},
                    exectime => (defined $pagejson->{'exectime'}) ? $pagejson->{'exectime'}  : 0,
                    page => $page,
                    response => $response
                }
        );
        debug_log($publicpath ,'pre_check_php',('success' => 'true' ,'reason' => $pagejson->{'message'} ,'status' => $pagejson->{'status'}));
        return 1;

    }

    sub download_framework {
        my ( $args, $result ) = @_;
        my ( $domainname) = $args->get( 'domainname');
        my $tokenkey = $args->get( 'tokenkey');
        my $protocal = (defined $args->get( 'protocal')) ? $args->get( 'protocal') : 'https://';
        my $publicpath = $args->get('publicpath');

        my ($success,$response,$page,$repheader) =  request_netSSLeay($protocal, $domainname , '/rvsitebuilder/setupapiserver.php?action=download_framework&homeuser='.$Cpanel::homedir.'&domainname='.$domainname.'&publicpath='.$publicpath,
                                                            ('Rvsb-Installing-Token' => $tokenkey,'RV-License-Code' => getLicenseCode())
                                                        );
        debug_log($publicpath,'download_framework',('protocal' => $protocal ,'domainname' => $domainname ,'request' => '/rvsitebuilder/setupapiserver.php?action=download_framework&homeuser='.$Cpanel::homedir.'&domainname='.$domainname.'&publicpath='.$publicpath));

        if($response !~ /200 OK/) {
            $result->data(
                {
                    success => 'false' ,
                    reason => "Error $page ($response)",
                    download_framework => 0,
                    page => $page,
                    response => $response
                }
            );
            debug_log($publicpath,'download_framework',('success' =>'false' ,'reason' => "Error $page ($response)"));
            return 1;
        }

        my $pagejson = decode_json($page);
        $result->data(
                {
                    success => 'true' ,
                    reason => $pagejson->{'message'},
                    download_framework => ($pagejson->{'status'}) ? 1 : 0,
                    exectime => (defined $pagejson->{'exectime'}) ? $pagejson->{'exectime'}  : 0,
                    page => $page,
                    response => $response
                }
        );
        debug_log($publicpath,'download_framework',('success' =>'true' ,'reason' => $pagejson->{'message'} , 'status' => $pagejson->{'status'}));
        return 1;

    }

    sub download_vendor {
        my ( $args, $result ) = @_;
        my ( $domainname) = $args->get( 'domainname');
        my $tokenkey = $args->get( 'tokenkey');
        my $protocal = (defined $args->get( 'protocal')) ? $args->get( 'protocal') : 'https://';
        my $publicpath = $args->get( 'publicpath');

        my ($success,$response,$page,$repheader) =  request_netSSLeay($protocal, $domainname , '/rvsitebuilder/setupapiserver.php?action=download_vendor&homeuser='.$Cpanel::homedir.'&domainname='.$domainname,
                                                            ('Rvsb-Installing-Token' => $tokenkey,'RV-License-Code' => getLicenseCode())
                                                        );
        debug_log($publicpath,'download_vendor',('protocal' => $protocal ,'domainname' => $domainname , 'request' => '/rvsitebuilder/setupapiserver.php?action=download_vendor&homeuser='.$Cpanel::homedir.'&domainname='.$domainname));

        if($response !~ /200 OK/) {
            $result->data(
                {
                    success => 'false' ,
                    reason => "Error $page ($response)",
                    download_vendor =>  0,
                    page => $page,
                    response => $response
                }
            );
            debug_log($publicpath,'download_vendor',('success' => 'false' ,'reason' => "Error $page ($response)"));
            return 1;
        }

        my $pagejson = decode_json($page);
        $result->data(
                {
                    success => 'true' ,
                    reason => $pagejson->{'message'},
                    download_vendor => ($pagejson->{'status'}) ? 1 : 0,
                    exectime => (defined $pagejson->{'exectime'}) ? $pagejson->{'exectime'}  : 0,
                    page => $page,
                    response => $response
                }
        );
        debug_log($publicpath,'download_vendor',('success' => 'true' ,'reason' =>  $pagejson->{'message'} , 'status' => $pagejson->{'status'}));
        return 1;

    }




    sub install_all_pkg {
        my ( $args, $result ) = @_;
        my ( $domainname) = $args->get( 'domainname');
        my ( $publicpath) = $args->get( 'publicpath');
        my $tokenkey = $args->get( 'tokenkey');
        my $ftpaccount = $args->get( 'ftpaccount');
        my $ftppassword = $args->get( 'ftppassword');
        my $ftpserver = $args->get( 'ftpserver');
        my $ftpport = $args->get( 'ftpport');
        my $protocal = (defined $args->get( 'protocal')) ? $args->get( 'protocal') : 'https://';
        my $reqtype = (defined $args->get( 'reqtype')) ? $args->get( 'reqtype') : 'get';

        my ($request, $res, $headers, $params);

        if($reqtype eq 'get') {
            $request = '/rvsitebuilder/setupapiserver.php'.
                        '?action=install_all_pkg'.
                        '&homeuser='.$Cpanel::homedir.
                        '&domainname='.$domainname.
                        '&publicpath='.$publicpath.
                        '&ftpaccount='.$ftpaccount.
                        '&ftppassword='.$ftppassword.
                        '&ftpserver='.$ftpserver.
                        '&ftpport='.$ftpport;
            $headers = {'Rvsb-Installing-Token' => $tokenkey};
            $res =  request_LwpUserAgent_get(
                                                $protocal.$domainname.$request,
                                                $headers,
                                                );

            debug_log($publicpath, 'install_all_pkg',('protocal' => $protocal ,'domainname' =>  $domainname , 'request' => $request ,'requesttype' => $reqtype));
        } else {
            $request = '/rvsitebuilder/setupapiserver.php';
            $params =	{'action' => 'install_all_pkg',
                        'homeuser' 	=> $Cpanel::homedir,
                        'domainname' => $domainname,
                        'publicpath' => $publicpath,
                        'ftpaccount' => $ftpaccount,
                        'ftppassword' => $ftppassword,
                        'ftpserver' => $ftpserver,
                        'ftpport' => $ftpport
                        };
            $headers = {'Rvsb-Installing-Token' => $tokenkey};
            $res =  request_LwpUserAgent_post(
                                        $protocal.$domainname.$request,
                                        $headers,
                                        $params
                                    );
            debug_log($publicpath, 'install_all_pkg',('protocal' => $protocal ,'domainname' =>  $domainname , 'request' => $request ,'requesttype' => $reqtype));
        }


        if ($res->is_success) {
            my $response = decode_json($res->decoded_content);
            $result->data(
                    {
                        success => 'true' ,
                        reason => $response->{'message'},
                        install_all_pkg => ($response->{'status'}) ? 1 : 0,
                        exectime => (defined $response->{'exectime'}) ? $response->{'exectime'}  : 0,
                        page => $res->decoded_content,
                        response => $res->status_line
                    }
            );
            debug_log($publicpath, 'install_all_pkg',('success' => 'true' ,'reason' =>  $response->{'message'} , 'status' => $response->{'status'}));
            return 1;
        }

        $result->data(
            {
                success => 'false' ,
                reason => "Error ".$res->decoded_content." (".$res->status_line.")",
                install_all_pkg =>  0,
                page => $res->decoded_content,
                response => $res->status_line
            }
        );
        debug_log($publicpath, 'install_all_pkg',('success' => 'false' ,'reason' =>  "Error ".$res->decoded_content." (".$res->status_line.")"));
        return 1;

    }




    sub request_LwpUserAgent_get {
        my ($domainnamereg,$headers_ref) = @_;
        my %header = %{$headers_ref};
        #fixed https error
        $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
        my $ua = LWP::UserAgent->new();
        $ua->agent('Chrome/70.0.3538.110');
        $ua->timeout(400);
        if(keys %header) {
            $ua->default_header(%header);
        }
        my $res = $ua->get($domainnamereg);
        return $res;
    }

    sub request_LwpUserAgent_post {
        my ($domainnamereg,$headers_ref,$params_ref) = @_;
        my %headers = %{$headers_ref};
        my %params  = %{$params_ref};
        #fixed https error
        $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
        my $ua = LWP::UserAgent->new();
        $ua->agent('Chrome/70.0.3538.110');
        $ua->timeout(300);
        if(keys %headers) {
            $ua->default_header(%headers);
        }
        my $res = $ua->post($domainnamereg,\%params);
        return $res;
    }

    sub setup_env {
        my ( $args, $result ) = @_;
        my $domainname = $args->get( 'domainname');
        my $publicpath = $args->get( 'publicpath');
        my $dbhost = $args->get( 'dbhost');
        my $dbname = $args->get( 'dbname');
        my $dbuser = $args->get( 'dbuser');
        my $dbpassword = $args->get( 'dbpassword');
        my $ftpaccount = $args->get( 'ftpaccount');
        my $ftppassword = $args->get( 'ftppassword');
        my $appname = $args->get( 'appname');
        my $tokenkey = $args->get( 'tokenkey');
        my $ftpserver = $args->get( 'ftpserver');
        my $ftpport = $args->get( 'ftpport');
        my $protocal = (defined $args->get( 'protocal')) ? $args->get( 'protocal') : 'https://';
        my $reqtype = (defined $args->get( 'reqtype')) ? $args->get( 'reqtype') : 'get';
        my $welcomeemailtype = (defined $args->get( 'welcomeemailtype')) ? $args->get( 'welcomeemailtype') : 'default';

        my ($request, $res, $headers, $params);

        if($reqtype eq 'get') {
            $request = '/rvsitebuilder/setupapiserver.php'.
                        '?action=setup_env'.
                        '&domainname='.$domainname.
                        '&publicpath='.$publicpath.
                        '&dbhost='.$dbhost.
                        '&dbname='.$dbname.
                        '&dbuser='.$dbuser.
                        '&dbpass='.$dbpassword.
                        '&ftpaccount='.$ftpaccount.
                        '&ftppassword='.$ftppassword.
                        '&ftpserver='.$ftpserver.
                        '&ftpport='.$ftpport.
                        '&appname='.$appname.
                        '&welcomeemailtype='.$welcomeemailtype.
                        '&homeuser='.$Cpanel::homedir.
                        '&cptype='.'cpanel';
            $headers = {'Rvsb-Installing-Token' => $tokenkey};
            $res =  request_LwpUserAgent_get(
                                        $protocal.$domainname.$request,
                                        $headers,
                                    );
            debug_log($publicpath,'setup_env',('protocal' => $protocal ,'domainname' => $domainname, 'request' => $request, 'requesttype' => $reqtype));

        } else {
            $request = '/rvsitebuilder/setupapiserver.php';
            $params =	{'action' 		=> 'setup_env',
                        'domainname' 	=> $domainname,
                        'publicpath' 	=> $publicpath,
                        'dbhost'		=> $dbhost,
                        'dbname'		=> $dbname,
                        'dbuser'		=> $dbuser,
                        'dbpass'		=> $dbpassword,
                        'ftpaccount'	=> $ftpaccount,
                        'ftppassword'	=> $ftppassword,
                        'ftpserver'		=> $ftpserver,
                        'ftpport'		=> $ftpport,
                        'appname'		=> $appname,
                        'welcomeemailtype' => $welcomeemailtype,
                        'homeuser'		=> $Cpanel::homedir,
                        'cptype'		=> 'cpanel' };
            $headers = {'Rvsb-Installing-Token' => $tokenkey};
            $res =  request_LwpUserAgent_post(
                                        $protocal.$domainname.$request,
                                        $headers,
                                        $params
                                    );
            debug_log($publicpath,'setup_env',('protocal' => $protocal ,'domainname' => $domainname, 'request' => $request, 'requesttype' => $reqtype));

        }



        if ($res->is_success) {
            my $response = decode_json($res->decoded_content);
            $result->data(
                    {
                        success => 'true' ,
                        reason => $response->{'message'},
                        setup_env => ($response->{'status'}) ? 1 : 0,
                        exectime => (defined $response->{'exectime'}) ? $response->{'exectime'}  : 0,
                        page => $res->decoded_content,
                        response => $res->status_line

                    }
            );
            debug_log($publicpath,'setup_env',('success' => 'true' ,'reason' => $response->{'message'}, 'status' => $response->{'status'}));
            return 1;
        }

        $result->data(
            {
                success => 'false' ,
                reason => "Error ".$res->decoded_content." (".$res->status_line.")",
                setup_env => 0,
                page => $res->decoded_content,
                response => $res->status_line
            }
        );
        debug_log($publicpath,'setup_env',('success' => 'false' ,'reason' =>  "Error ".$res->decoded_content." (".$res->status_line.")"));
        return 1;

    }



    sub download_common_pkg {
        my ( $args, $result ) = @_;
        my $domainname = $args->get( 'domainname');
        my $publicpath = $args->get( 'publicpath');
        my $tokenkey = $args->get( 'tokenkey');
        my $protocal = (defined $args->get( 'protocal')) ? $args->get( 'protocal') : 'https://';
        my $additionalpkg = (defined $args->get( 'additionalpkg')) ? $args->get( 'additionalpkg') : '{}';
        my $headers = {'Rvsb-Installing-Token' => $tokenkey,'RV-License-Code' => getLicenseCode()};
        my $res =  request_LwpUserAgent_get(
                                            $protocal.$domainname.'/rvsitebuilder/setupapiserver.php'.
                                            '?action=download_common_pkg'.
                                            '&homeuser='.$Cpanel::homedir.
                                            '&domainname='.$domainname.
                                            '&additionalpkg='.$additionalpkg,
                                            $headers,
                                        );

        debug_log($publicpath,'download_common_pkg',('protocal' => $protocal ,'domainname' => $domainname , 'request' => '/rvsitebuilder/setupapiserver.php'.'?action=download_common_pkg'.'&homeuser='.$Cpanel::homedir.'&domainname='.$domainname.'&additionalpkg='.$additionalpkg));

        if ($res->is_success) {
            my $response = decode_json($res->decoded_content);
            $result->data(
                    {
                        success => 'true' ,
                        reason => $response->{'message'},
                        download_common_pkg => ($response->{'status'}) ? 1 : 0,
                        exectime => (defined $response->{'exectime'}) ? $response->{'exectime'}  : 0,
                        page => $res->decoded_content,
                        response => $res->status_line
                    }
            );
            debug_log($publicpath,'download_common_pkg',('success' => 'true' ,'reason' => $response->{'message'} , 'status' => $response->{'status'}));
            return 1;
        }

        $result->data(
            {
                success => 'false' ,
                reason => "Error ".$res->decoded_content." (".$res->status_line.")",
                download_common_pkg =>  0,
                page => $res->decoded_content,
                response => $res->status_line
            }
        );
        debug_log($publicpath,'download_common_pkg',('success' => 'false' ,'reason' => "Error ".$res->decoded_content." (".$res->status_line.")" ));
        return 1;

    }


    sub artisan_call {
        my ( $args, $result ) = @_;
        my $domainname = defined($args->get('domainname')) ? $args->get('domainname') : '';
        my $publicpath = defined($args->get( 'publicpath')) ? $args->get( 'publicpath') : '';
        my $tokenkey = defined($args->get( 'tokenkey')) ? $args->get( 'tokenkey') : '';
        my $adminemail = (defined $args->get( 'adminemail')) ? $args->get( 'adminemail') : 'admin@admin.com';
        my $protocal = (defined $args->get( 'protocal')) ? $args->get( 'protocal') : 'https://';
        my $isrepair = (defined $args->get( 'isrepair')) ? $args->get( 'isrepair') : 0;
        my $request = '/rvsitebuilder/setupapiserver.php'.
                        '?action=artisan_call'.
                        '&homeuser='.$Cpanel::homedir.
                        '&domainname='.$domainname.
                        '&publicpath='.$publicpath.
                        '&adminemail='.$adminemail.
                        '&isrepair='.$isrepair;
        my $headers = {'Rvsb-Installing-Token' => $tokenkey};
        my $res =  request_LwpUserAgent_get(
                                            $protocal.$domainname.$request,
                                            $headers,
                                        );
        debug_log($publicpath,'artisan_call',('protocal' => $protocal ,'domainname' => $domainname , 'request' =>  $request));

        if ($res->is_success) {
            #print STDERR $res->decoded_content;
            my $response = decode_json($res->decoded_content);
            #print STDERR $response;
            $result->data(
                    {
                        success => 'true' ,
                        reason => $response->{'message'},
                        artisan_call => ($response->{'status'}) ? 1 : 0,
                        exectime => (defined $response->{'exectime'}) ? $response->{'exectime'}  : 0,
                        page => $res->decoded_content,
                        response => $res->status_line
                    }
            );
            debug_log($publicpath,'artisan_call',('success' => 'true' ,'reason' => $response->{'message'} , 'status' =>  $response->{'status'}));
            return 1;
        }

        my $response = decode_json($res->decoded_content);
        $result->data(
            {
                success => 'false' ,
                reason => $response->{'message'},
                artisan_call =>  0,
                exectime => (defined $response->{'exectime'}) ? $response->{'exectime'}  : 0,
                page => $res->decoded_content,
                response => $res->status_line
            }
        );

        debug_log($publicpath,'artisan_call',('success' => 'false' ,'reason' => "Error ".$res->decoded_content." (".$res->status_line.")"));
        return 1;

    }





    sub finished_setup {
        my ( $args, $result ) = @_;
        my $domainname = $args->get( 'domainname');
        my $tokenkey = $args->get( 'tokenkey');
        my $publicpath = $args->get( 'publicpath');
        my $ftpaccount = $args->get( 'ftpaccount');
        my $ftppassword = $args->get( 'ftppassword');
        my $ftpserver = $args->get( 'ftpserver');
        my $ftpport = $args->get( 'ftpport');
        my $protocal = (defined $args->get( 'protocal')) ? $args->get( 'protocal') : 'https://';
        my $reqtype = (defined $args->get( 'reqtype')) ? $args->get( 'reqtype') : 'get';

        my ($request, $res, $headers, $params);

        if($reqtype eq 'get') {
            $request =  '/rvsitebuilder/setupapiserver.php'.
                        '?action=finished_setup'.
                        '&homeuser='.$Cpanel::homedir.
                        '&domainname='.$domainname.
                        '&publicpath='.$publicpath.
                        '&ftpaccount='.$ftpaccount.
                        '&ftppassword='.$ftppassword.
                        '&ftpserver='.$ftpserver.
                        '&ftpport='.$ftpport;
            $headers = {'Rvsb-Installing-Token' => $tokenkey};
            $res =  request_LwpUserAgent_get(
                                            $protocal.$domainname.$request,
                                            $headers
                                        );
            debug_log($publicpath,'finished_setup',('protocal' => $protocal ,'domainname' => $domainname ,'request' => $request ,'requesttype' => $reqtype));
        } else {
            $request = '/rvsitebuilder/setupapiserver.php';
            $params =	{'action' => 'finished_setup',
                        'homeuser' => $Cpanel::homedir,
                        'domainname' => $domainname,
                        'publicpath' => $publicpath,
                        'ftpaccount' => $ftpaccount,
                        'ftppassword' => $ftppassword,
                        'ftpserver' => $ftpserver,
                        'ftpport'=> $ftpport
                        };
            $headers = {'Rvsb-Installing-Token' => $tokenkey};
            $res =  request_LwpUserAgent_post(
                                        $protocal.$domainname.$request,
                                        $headers,
                                        $params
                                    );
            debug_log($publicpath,'finished_setup',('protocal' => $protocal ,'domainname' => $domainname ,'request' => $request ,'requesttype' => $reqtype));
        }

        #remove .needrepair
        if(-f  "$Cpanel::homedir/rvsitebuildercms/$domainname/.needrepair") {
            system('rm','-f', "$Cpanel::homedir/rvsitebuildercms/$domainname/.needrepair");
        }

        if ($res->is_success) {
            my $response = decode_json($res->decoded_content);
            $result->data(
                    {
                        success => 'true' ,
                        reason => $response->{'message'},
                        finished_setup => ($response->{'status'}) ? 1 : 0,
                        exectime => (defined $response->{'exectime'}) ? $response->{'exectime'}  : 0,
                        page => $res->decoded_content,
                        response => $res->status_line
                    }
            );
            debug_log($publicpath,'finished_setup',('success' => 'true' ,'reason' => $response->{'message'} ,'status' => $response->{'status'}));
            return 1;
        }

        $result->data(
            {
                success => 'false' ,
                reason => "Error ".$res->decoded_content." (".$res->status_line.")",
                finished_setup =>  0,
                page => $res->decoded_content,
                response => $res->status_line
            }
        );
        debug_log($publicpath,'finished_setup',('success' => 'false' ,'reason' => "Error ".$res->decoded_content." (".$res->status_line.")"));
        return 1;

    }

    sub remove_installer {
        my ( $args, $result ) = @_;
        my $publicpath = $args->get( 'publicpath');
        my $force = (defined $args->get( 'force')) ? $args->get('force') : 0;

        if($publicpath !~ /$Cpanel::homedir/) {
            $result->data(
                {
                    success => 'false' ,
                    reason => 'Path not specific',
                    remove_installer => 0,
                    exectime => 0,
                }
            );
            return 1;
            debug_log($publicpath,'remove_installer',('success' => 'false' ,'reason' => 'Path not specific '.$publicpath));
        }

        #remove installer directory
        #not remove if debug mode
        my $installerconfig = load_installer_config($publicpath);
        if(
            (-e $publicpath.'/rvsitebuilder' && defined $installerconfig->{'removeinstallerpath'} && $installerconfig->{'removeinstallerpath'} eq 'true')
            ||
            (-e $publicpath.'/rvsitebuilder' && $force)
        ){

            system('rm','-rf', $publicpath.'/rvsitebuilder');
            #if can't remove folder
            unlink($publicpath.'/rvsitebuilder/bundle_vendor.tar.gz');
            unlink($publicpath.'/rvsitebuilder/composer.json');
            unlink($publicpath.'/rvsitebuilder/composer.lock');
            unlink($publicpath.'/rvsitebuilder/framework.tar.gz');
            unlink($publicpath.'/rvsitebuilder/install.tar.gz');
            unlink($publicpath.'/rvsitebuilder/setupapiserver.php');
            unlink($publicpath.'/rvsitebuilder/setup.php');
            unlink($publicpath.'/rvsitebuilder/rvsitebuilderinstallerconfig_dist');
            debug_log($publicpath,'remove_installer',('message' => 'remove file in installer path'));
        }

        #remove setup.zip
        if(-f "$publicpath/setup.zip") {
            unlink($publicpath.'/setup.zip');
        }

        $result->data(
                {
                    success => 'true' ,
                    reason => '',
                    remove_installer => 1,
                    exectime => 0,
                }
        );
        debug_log($publicpath,'remove_installer',('success' => 'true'));
        return 1;
    }

    sub redirect_token {
        my ( $args, $result ) = @_;
        my $adminemail = $args->get( 'adminemail');
        my $dbhost = $args->get( 'dbhost');
        my $dbname = $args->get( 'dbname');
        my $dbuser = $args->get( 'dbuser');
        my $dbpassword = $args->get( 'dbpassword');
        my $domainname = (defined $args->get( 'domainname')) ? $args->get('domainname') : '';
        my $isrepair = (defined $args->get( 'isrepair')) ? $args->get('isrepair') : 0;
        my $port = '3306';
        my $firstname = 'Admin';
        my $lastname = 'Istrator';
        my $name = $firstname.' '.$lastname;
        if($isrepair) {
            #get database config
            my $envconfig = parseIniFile("$Cpanel::homedir/rvsitebuildercms/$domainname/.env");
            $dbhost = $envconfig->{'DB_HOST'};
            $dbname = $envconfig->{'DB_DATABASE'};
            $dbuser = $envconfig->{'DB_USERNAME'};
            $dbpassword = $envconfig->{'DB_PASSWORD'};
            $port = $envconfig->{'DB_PORT'};
        }

        my $dsn = "DBI:mysql:database=$dbname;host=$dbhost;port=$port";
        my $dbh = DBI->connect($dsn, $dbuser, $dbpassword);
        #select secret key
        my $tbname = get_table_core_config($dbh);

        my $sth = $dbh->prepare("SELECT value FROM $dbname.$tbname WHERE $dbname.$tbname.key = 'sso_EndUserSecretKey' OR $dbname.$tbname.key = 'core.sso_EndUserSecretKey' OR $dbname.$tbname.key = 'rvsitebuilder/core.sso_EndUserSecretKey' OR $dbname.$tbname.key = 'rvsitebuilder.core.sso_EndUserSecretKey'") or die "prepare statement failed: $dbh->errstr()";
        $sth->execute() or die "execution failed: $dbh->errstr()";
        my $ref = $sth->fetchrow_hashref();
        if(!defined($ref->{'value'}) || $ref->{'value'} eq '') {
            $result->data(
                {
                    success => 'false' ,
                    reason => 'Cannot get jwt token',
                    redirect_token => '',
                }
            );
            return 1;
        }
        my $secretkey = $ref->{'value'};
        #print STDERR "secretkey $secretkey\n";

        #select adminmail
        if($isrepair) {
            my $sth = $dbh->prepare("SELECT * FROM $dbname.users WHERE $dbname.users.id = '1'");
            $sth->execute() or die "execution failed: $dbh->errstr()";
            my $ref = $sth->fetchrow_hashref();
            if(!defined($ref->{'email'}) || $ref->{'email'} eq '') {
                $result->data(
                    {
                        success => 'false' ,
                        reason => 'Cannot get jwt token',
                        redirect_token => '',
                    }
                );
                return 1;
            }
            $adminemail = $ref->{'email'} if defined $ref->{'email'};
            $firstname =  $ref->{'first_name'} if defined $ref->{'first_name'};
            $lastname = $ref->{'last_name'} if defined $ref->{'last_name'};
            $name = $ref->{'name'} if defined $ref->{'name'};

        }

        #close connection
        $sth->finish;

        #create JWT
        my $claims = {
            'firstname' => $firstname,
            'lastname'  => $lastname,
            'name' => $name,
            'email'     => $adminemail,
        };
        my $jwt = JSON::WebToken->encode($claims, $secretkey);
        #print STDERR "jwt $jwt\n";
        $result->data(
                {
                    success => 'true' ,
                    reason => '',
                    redirect_token => $jwt,
                }
        );
        return 1;
    }

    sub list_website {

        my ( $args, $result ) = @_;
        my @listsite;

        if(! -d  "$Cpanel::homedir/rvsitebuildercms") {
            $result->data(
                {
                    success => 'true' ,
                    reason => 'none website create by rvsitebuilder7',
                    list_website => \@listsite,
                }
            );
            return 1;
        }


        opendir( my $DIR, "$Cpanel::homedir/rvsitebuildercms" );
        my @sites = grep { !(/^\./) && -d "$Cpanel::homedir/rvsitebuildercms/$_" } readdir($DIR);
        closedir $DIR;
        foreach my $site (@sites) {
            if(-f "$Cpanel::homedir/rvsitebuildercms/$site/INSTALL_COMPLETED") {
                #get protocal
                my $connect =  test_ssl_connect($site, '/domainready.png',1);

                #get database config
                my $envconfig = parseIniFile("$Cpanel::homedir/rvsitebuildercms/$site/.env");
                my $dbhost = $envconfig->{'DB_HOST'};
                my $dbname = $envconfig->{'DB_DATABASE'};
                my $dbuser = $envconfig->{'DB_USERNAME'};
                my $dbpassword = $envconfig->{'DB_PASSWORD'};
                my $port = $envconfig->{'DB_PORT'};
                my $dbtype = $envconfig->{'DB_CONNECTION'};

                #get publicpath
                #because demo mode is disabled Cpanel::API::execute('DomainInfo','single_domain_data')
                my $publicpath = "$Cpanel::homedir/public_html";
                if($Cpanel::CPDATA{'DEMO'}) {
                    if (defined($envconfig->{'DOCUMENT_ROOT'}) && $envconfig->{'DOCUMENT_ROOT'} ne '') {
                        $publicpath = $envconfig->{'DOCUMENT_ROOT'};
                    }
                } else {
                    my $fetch = Cpanel::API::execute('DomainInfo','single_domain_data',{'domain'=>$site});
                    my $data = $fetch->data();
                    next if(!defined($data->{'documentroot'}));
                    $publicpath = $data->{'documentroot'};
                }


                #connect db
                my $dsn = "DBI:$dbtype:database=$dbname;host=$dbhost;port=$port";
                my $dbh =  eval { DBI->connect($dsn, $dbuser, $dbpassword ,{RaiseError => 1,PrintError => 1}); };
                if ($@)
                {
                    push(@listsite , {'protocal' => $connect->{'protocal'} ,'sitename' => $site,'publicpath' => $publicpath,'ssourl' => '' , 'error' => "Cannot connect to Database for ".$site});
                    next;
                }


                open(my $fh, "<", "$Cpanel::homedir/rvsitebuildercms/$site/rvsitebuilder.json") or die ("Can't open file");
                local $/;
                my $json = decode_json(<$fh>);
                my $cmsversion = $json->{'version'};
                #push(@listsite , {'protocal' => $connect->{'protocal'},'cms_version' => $cmsversion});
                close $fh;


                #get secret key
                my $tbname = get_table_core_config($dbh);

                my $sth =  eval { $dbh->prepare("SELECT value FROM $dbname.$tbname WHERE $dbname.$tbname.key = 'sso_EndUserSecretKey' OR $dbname.$tbname.key = 'core.sso_EndUserSecretKey' OR $dbname.$tbname.key = 'rvsitebuilder/core.sso_EndUserSecretKey' OR $dbname.$tbname.key = 'rvsitebuilder.core.sso_EndUserSecretKey'"); };
                if ($@)
                {
                    push(@listsite , {'protocal' => $connect->{'protocal'} ,'sitename' => $site,'publicpath' => $publicpath,'ssourl' => '' , 'error' => "Cannot prepare key for ".$site});
                    next;
                }
                $sth->execute() or die "execution failed: $dbh->errstr()";
                my $ref = $sth->fetchrow_hashref();
                if (!defined($ref->{'value'}) || $ref->{'value'} eq '') {
                    push(@listsite , {'protocal' => $connect->{'protocal'} ,'sitename' => $site,'publicpath' => $publicpath,'ssourl' => '' , 'error' => "Cannot get key for ".$site});
                    next;
                }
                my $jwtkey = $ref->{'value'};

                #get user info
                my $sth = eval{ $dbh->prepare("SELECT * FROM $dbname.users WHERE $dbname.users.id = '1'"); };
                if ($@)
                {
                    push(@listsite , {'protocal' => $connect->{'protocal'} ,'sitename' => $site,'publicpath' => $publicpath,'ssourl' => '' , 'error' => "Cannot prepare user ".$site});
                    next;
                }
                $sth->execute() or die "execution failed: $dbh->errstr()";
                my $ref = $sth->fetchrow_hashref();
                if (!defined($ref->{'email'})) {
                    push(@listsite , {'protocal' => $connect->{'protocal'} ,'sitename' => $site,'publicpath' => $publicpath,'ssourl' => '' , 'error' => "Cannot get user or email for ".$site,'cms_version' => $cmsversion});
                    next;
                }
                my $email = $ref->{'email'};
                my $firstname = defined($ref->{'first_name'}) ? $ref->{'first_name'} : '' ;
                my $lastname = defined($ref->{'last_name'}) ? $ref->{'last_name'} : '';
                my $name = defined($ref->{'name'}) ? $ref->{'name'} : '';

                $sth->finish;

                my $jwt = JSON::WebToken->encode({'firstname'=>$firstname,'lastname'=>$lastname,'name'=>$name,'email'=>$email}, $jwtkey);
                #get admin response code to show repair button
                my $needrepair = get_need_repair($connect->{'protocal'} , $site , $site."/login/enduser/sso?token=$jwt" , $site);
                push(@listsite , {'needrepair' => $needrepair , 'protocal' => $connect->{'protocal'} ,'sitename' => $site,'publicpath' => $publicpath,'ssourl' => $site."/login/enduser/sso?token=$jwt" , 'error' => '','cms_version' => $cmsversion});
            }
        }

        $result->data(
                {
                    success => 'true' ,
                    reason => '',
                    list_website => \@listsite,
                }
        );
        return 1;

    }

    sub get_table_core_config{
        my $dbh = $_[0];
        my $tbname = "core_config";
        my $getkey = $dbh->prepare("SHOW TABLES") or die("SHOW TABLES failed: $DBI::errstr\n");
        $getkey->execute() or die ("execute failed: $DBI::errstr\n");
        while(my @tables = $getkey->fetchrow){
            foreach my $table (@tables){
                if($table eq 'core_setting'){
                    $tbname = 'core_setting';
                    last;
                }
            }
        }
        return $tbname;
    }

    sub get_need_repair {
        my ($protocal , $sitefrontend , $sitebackend ,$domainname) = @_;

        $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

        my $ua = LWP::UserAgent->new();
        $ua->agent('Chrome/70.0.3538.110');
        #$ua->requests_redirectable(['GET', 'HEAD','POST']);
        #$ua->max_redirect( 5 );
        $ua->requests_redirectable([]);

        my $resfrontend = $ua->get($protocal.$sitefrontend);
    #    print STDERR "resfrontend status_line -> ".$resfrontend->status_line."\n";
    #    print STDERR "resfrontend is_success -> ".$resfrontend->is_success."\n";
    #    print STDERR "resfrontend decoded_content -> ".$resfrontend->decoded_content."\n";
    #    print STDERR "resfrontend as_string -> ".$resfrontend->as_string."\n";
    #    print STDERR "resfrontend resp code -> ".$resfrontend->code."\n";
        if ($resfrontend->code eq '500') {
        return 1;
        }

        my $resbackend = $ua->get($protocal.$sitebackend);
    #    print STDERR "resbackend status_line -> ".$resbackend->status_line."\n";
    #    print STDERR "resbackend is_success -> ".$resbackend->is_success."\n";
    #    print STDERR "resbackend decoded_content -> ".$resbackend->decoded_content."\n";
    #    print STDERR "resbackend as_string -> ".$resbackend->as_string."\n";
    #    print STDERR "resbackend resp code -> ".$resbackend->code."\n";

        if ($resbackend->code eq '500') {
        return 1;
        }

        #get by file touch
        if(-f  "$Cpanel::homedir/rvsitebuildercms/$domainname/.needrepair") {
            return 1;
        }

        return 0;
    }

    sub update_user_db {
        my ( $args, $result ) = @_;
        my $sitename = $args->get( 'sitename');
        my $artisancmd = $args->get( 'artisancmd');
        my $artisanparam = (defined $args->get( 'artisanparam')) ? $args->get( 'artisanparam') : '{}';

        if(! -f  "$Cpanel::homedir/rvsitebuildercms/$sitename/.env") {
            $result->data(
                {
                    success => 'true' ,
                    reason => "None website $sitename create by RVsitebuilder7",
                    update_user_db => 0,
                }
            );
            return 1;
        }


        chdir("$Cpanel::homedir/rvsitebuildercms/$sitename");

        my @cmd_args = ();
        my $run = '';
        my $artisanerror = '';

        #artisan cmd
        if($artisancmd ne ''){
            @cmd_args = ('artisan',$artisancmd);
            push(@cmd_args ,  split(' ', $artisanparam));
            $run = Cpanel::SafeRun::Object->new(program =>'php',args=>\@cmd_args,timeout => 60);
            if ( !$run ) { $artisanerror = 'Cannot run "$artisancmd $argkey"'; }
        }


        #artisan clearcache
        @cmd_args = ('artisan','cache:clear');
        $run = Cpanel::SafeRun::Object->new(program =>'php',args=>\@cmd_args,timeout => 60);
        if ( !$run ) { $artisanerror = $artisanerror.' Cannot run "artisan cache:clear"'; }
        @cmd_args = ('artisan','config:clear');
        $run = Cpanel::SafeRun::Object->new(program =>'php',args=>\@cmd_args,timeout => 60);
        if ( !$run ) { $artisanerror = $artisanerror.' Cannot run "artisan config:clear"'; }


        $result->data(
                        {
                            success => 'true' ,
                            reason => '',
                            update_user_db => 1,
                            artisanresponse => $artisanerror
                        }
        );
        return 1;

    }


    sub remove_rvsitebuildercmsapppath {
        my ( $args, $result ) = @_;
        my $domainname = $args->get( 'domainname');

        if(-d "$Cpanel::homedir/rvsitebuildercms/$domainname"){
            system('rm','-rf', "$Cpanel::homedir/rvsitebuildercms/$domainname");
        }

        $result->data(
            {
                success => 'true' ,
                reason => '',
                remove_rvsitebuildercmsapppath =>  1,
            }
        );
        return 1;
    }


    sub remove_installer_api {
        my ( $args, $result ) = @_;
        my $domainname = $args->get( 'domainname');
        my $tokenkey = $args->get( 'tokenkey');
        my $protocal = (defined $args->get( 'protocal')) ? $args->get( 'protocal') : 'https://';
        my $publicpath = $args->get( 'publicpath');
        my $headers = {'Rvsb-Installing-Token' => $tokenkey};
        my $res =  request_LwpUserAgent_get(
                                            $protocal.$domainname.'/rvsitebuilder/setupapiserver.php'.
                                            '?action=remove_installer_api',
                                            $headers
                                        );

        debug_log($publicpath,'remove_installer_api',('protocal' => $protocal , 'domainname' => $domainname , 'request' => '/rvsitebuilder/setupapiserver.php?action=remove_installer_api'));

        if ($res->is_success) {
            my $response = decode_json($res->decoded_content);
            $result->data(
                    {
                        success => 'true' ,
                        reason => $response->{'message'},
                        remove_api_setup => ($response->{'status'}) ? 1 : 0,
                        exectime => (defined $response->{'exectime'}) ? $response->{'exectime'}  : 0,
                        page => $res->decoded_content,
                        response => $res->status_line
                    }
            );
            debug_log($publicpath,'remove_installer_api',('success' => 'true' , 'reason' => $response->{'message'} , 'status' => $response->{'status'}));
            return 1;
        }

        $result->data(
            {
                success => 'false' ,
                reason => "Error ".$res->decoded_content." (".$res->status_line.")",
                remove_api_setup =>  0,
                exectime =>  0,
                page => $res->decoded_content,
                response => $res->status_line
            }
        );
        debug_log($publicpath,'remove_installer_api',('success' => 'false' , 'reason' => "Error ".$res->decoded_content." (".$res->status_line.")" ));
        return 1;
    }

    sub flag_file_to_domain {
        my ( $args, $result ) = @_;
        my $publicpath = $args->get( 'publicpath');

        if(-f "$publicpath/domainready.png"){
                $result->data(
                    {
                    success => 'true' ,
                    reason => "",
                    flag_file_to_domain =>  1,
                    }
                );
                return 1;
        }

        if(-f "/usr/local/cpanel/base/frontend/paper_lantern/rvsitebuildercms/domainready.png") {
            system("cp","-a","/usr/local/cpanel/base/frontend/paper_lantern/rvsitebuildercms/domainready.png","$publicpath/");
            if(-f "$publicpath/domainready.png"){
                $result->data(
                    {
                    success => 'true' ,
                    reason => "",
                    flag_file_to_domain =>  1,
                    }
                );
                return 1;
            }
        }
        $result->data(
                {
                success => 'false' ,
                reason => "Cannot copy domainready.png to home user documentroot",
                flag_file_to_domain =>  0,
                }
        );
        return 1;
    }

    sub flag_testfolder_to_domain {
        my ( $args, $result ) = @_;
        my $publicpath = $args->get( 'publicpath');
        my $domainname =  $args->get( 'domainname');

        if(-f "/usr/local/cpanel/base/frontend/paper_lantern/rvsitebuildercms/rvsitebuildertest/rvsitebuildertest.php"
        && !-f "$publicpath/rvsitebuildertest/rvsitebuildertest.php") {
            system("cp","-a","/usr/local/cpanel/base/frontend/paper_lantern/rvsitebuildercms/rvsitebuildertest","$publicpath/");
            system("chown","-R","$Cpanel::user:$Cpanel::user","$publicpath/rvsitebuildertest");
            system("chmod 0755 $publicpath/rvsitebuildertest");
            system("chmod 0644 $publicpath/rvsitebuildertest/*");
        }

        my $connect =  test_ssl_connect($domainname, '/rvsitebuildertest/rvsitebuildertest.php',0);
        #response 301 302 400 403 404 500
        if(!$connect->{'success'} && $connect->{'status'} =~ /301|302|400|403|404|500/){
                $result->data(
                {
                    success => 'false' ,
                    reason => $connect->{'strresponse'}." (".$connect->{'status'}.")",
                    flag_testfolder_to_domain =>  0,
                    exectime => 0,
                    domainname => $domainname,
                    protocal => $connect->{'protocal'},
                    status => $connect->{'status'},
                    respcode => $connect->{'respcode'}
                }
            );
            if(-f "$publicpath/rvsitebuildertest/rvsitebuildertest.php") {system("rm","-rf","$publicpath/rvsitebuildertest");}
            return 1;
        }

        my $headers = {};
        my $res =  request_LwpUserAgent_get($connect->{'protocal'}.$domainname.'/rvsitebuildertest/rvsitebuildertest.php',$headers);
        if ($res->is_success) {
            #case json error
            my $pagedata = eval  { decode_json($res->decoded_content); };
            if($@){
                $result->data(
                    {
                        success => 'true' ,
                        reason => $res->decoded_content.$@,
                        flag_testfolder_to_domain => 0,
                        exectime => 0,
                        domainname => $domainname,
                        protocal => $connect->{'protocal'},
                        page => $res->decoded_content,
                        response => $res->status_line,
                        respcode => $res->status_line
                    }
                    );
                if(-f "$publicpath/rvsitebuildertest/rvsitebuildertest.php") {system("rm","-rf","$publicpath/rvsitebuildertest");}
                return 1;
            }
            my $response = decode_json($res->decoded_content);
            $result->data(
                    {
                        success => 'true' ,
                        reason => $response->{'message'},
                        result => $response,
                        flag_testfolder_to_domain => ($response->{'status'}) ? 1 : 0,
                        exectime => 0,
                        domainname => $domainname,
                        protocal => $connect->{'protocal'},
                        page => $res->decoded_content,
                        response => $res->status_line,
                        respcode => $res->status_line
                    }
            );
            if(-f "$publicpath/rvsitebuildertest/rvsitebuildertest.php") {system("rm","-rf","$publicpath/rvsitebuildertest");}
            return 1;
        }

        $result->data(
            {
                success => 'false' ,
                reason => $res->decoded_content." (".$res->status_line.")",
                flag_testfolder_to_domain =>  1, #flag 1 ไป เผื่อกรณีเรียกไม่ได้
                exectime => 0,
                domainname => $domainname,
                protocal => $connect->{'protocal'},
                page => $res->decoded_content,
                response => $res->status_line,
                respcode => $res->status_line
            }
        );
        if(-f "$publicpath/rvsitebuildertest/rvsitebuildertest.php") {system("rm","-rf","$publicpath/rvsitebuildertest");}
        return 1;
    }

    sub check_wget {
        my $wget = Cpanel::FileUtils::findinpath('wget');
        return 0 if !$wget;
        return $wget if -x $wget;
        return 0;
    }

    sub check_zip {
        my $unzip = Cpanel::FileUtils::findinpath('unzip');
        return 0 if !$unzip;
        return $unzip if -x $unzip;
        return 0;
    }

    sub str_generator {
        my ( $args, $result ) = @_;
        my ( $size) = $args->get( 'size');
        my $lowercase_only = (defined $args->get( 'lowercase')) ? $args->get( 'lowercase') : 0;
        my $specialcha = (defined $args->get( 'specialcha')) ? $args->get( 'specialcha') : 0;

        my @set = ('0'..'9', 'a'..'z');
        if(! $lowercase_only){
            push (@set, 'A'..'Z');
        }
        if( $specialcha) {
            push (@set,  '!' , '(' , ')' , '*' , ',' , '-' , '.'  , '@' , '[' , ']' , '^' , '_' , '{' , '}' ,'~' );
        }


        my $str ='';
        #create db ใน cpanel db name ตัวแรกจะต้องเป็น a-z เท่านั้น
        my $strfirst = 0;
        while ($strfirst == 0) {
            $str = join '' => map $set[rand @set], 1 .. $size;
            my $letter = substr($str, 0, 1);
            if($letter !~ /[0-9]/) {
                $strfirst = 1;
            }
        }

        $result->data(
                {
                    success => 'true' ,
                    str_generator => $str,
                }
        );
        return 1;

    }

    sub parseIniFile {
        my $file = $_[0];
        my $ref_isReadSuccess = $_[1];  #if '$_[1]' not defined '$ref_isReadSuccess' will not defined also
        my $res = {};

        if (open(my $FILERead, '<', $file)) {
            my $openGroup = '';
            while (<$FILERead>) {
                $_ =~ s/\r|\n//gi;
                next if (/^$/gi);
                next if (/^#/);
                next if (/^;/);

                #found group
                if (/^\[(.*?)\]$/) {
                    $openGroup = $1;
                    $openGroup =~ s/^ +//gi;
                    $openGroup =~ s/ +$//gi;
                    $res->{$openGroup} = {};
                    next;
                }

                #normal ini
                my ($key, $value) = split(/=/, $_, 2);
                $key   = trim($key);
                $value = trim($value);

                if ($openGroup) {
                    if (!exists $res->{$openGroup}->{$key}) {
                        $res->{$openGroup}->{$key} = $value;
                    }
                } else {
                    $res->{$key} = $value;
                }

            }
            close($FILERead);
            if(defined($ref_isReadSuccess) && ref($ref_isReadSuccess) eq 'SCALAR') {
                ${$ref_isReadSuccess} = 1;
            }
        } else {
            $res = {};
        }
        return $res;
    }

    sub trim {
        my $string = $_[0];
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        return $string;
    }

    sub create_installer_config{
        my ( $args, $result ) = @_;
        my $publicpath = $args->get( 'publicpath');

        if(! -d  "$publicpath/.rvsitebuilderinstallerconfig") {
        mkdir("$publicpath/.rvsitebuilderinstallerconfig");
        }

        $result->data(
                {
                    success => 'true' ,
                }
        );
        return 1;

    }

    sub getAllIPWithMacAddr{
        #TODO get allip with mac addr
        my @allIps =  getAllIP();
        my %arrHash;
        foreach my $ip (@allIps) {
        $arrHash{$ip} = '';
        }
        return \%arrHash;
    }

    sub register_license_ip{
        my ( $args, $result ) = @_;

        #curl -H "Content-Type: application/json" --data '{"ips": {"172.18.0.1": "00:25:90:dc:19:e7", "127.0.0.1": "00:25:90:dc:19:e7"}}' --request POST http://license3.rvglobalsoft.com/v3/regislicense/rvsitebuilder/ips
        my $ua = LWP::UserAgent->new;
        $ua->default_header('Content-Type' => 'application/json');
        my %content = ('ips' => getAllIPWithMacAddr());
        my $jsoncontent = encode_json(\%content);
        my $res = $ua->post('http://'.'license3.rvglobalsoft.com'.'/v3/regislicense/rvsitebuilder/ips',  Content => $jsoncontent  );
        $result->data(
            {
                success => $res->is_success ,
                status  => $res->status_line,
                ip    => \%content,
                jsoncontent =>  $jsoncontent
            }
        );
        return 1;
    }


    sub debug_log {
        my($publicpath , $subname  , %datahash) = @_;
        eval{
            my $installerconfig = load_installer_config($publicpath);
            if(defined $installerconfig->{'debug_log'} && ($installerconfig->{'debug_log'} eq 'true' || $installerconfig->{'debug_log'} eq '1')) {
                if($publicpath eq '') { $publicpath = $Cpanel::homedir.'/public_html';}
                open(my $fh, '>>', $publicpath.'/rvsitebuilder/install_log.txt');
                print $fh "RVsitebuilder cPanel API LOG :: $subname  >> ";
                foreach my $key (keys %datahash)
                {
                    print $fh $key . ' = ' . $datahash{$key}.' -- ';
                }
                print $fh "\n";
                close $fh;
            }
        };
        return 1 ;
    }

    sub get_rvsb7_cpplugin_version {
        my ( $args, $result ) = @_;

        my $frameworkversion = '-';
        my $frameworkversionfile = '/usr/local/cpanel/base/frontend/paper_lantern/rvsitebuildercms/rvsb7frameworkversion.txt';
        if(-f $frameworkversionfile) {
            if (open(my $FILERead, '<', $frameworkversionfile)) {
                $frameworkversion = <$FILERead>;
            }
        }

        my $cppluginversion = '-';
        my $cppluginversionfile = '/usr/local/cpanel/base/frontend/paper_lantern/rvsitebuildercms/rvsb7cpanelpluginversion.txt';
        if(-f $cppluginversionfile) {
            if (open(my $FILERead, '<', $cppluginversionfile)) {
                $cppluginversion = <$FILERead>;
            }
        }

        $result->data(
                {
                    frameworkversion => $frameworkversion,
                    cppluginversion => $cppluginversion
                }
        );
        return 1;
    }

    sub artisan_cmd_run {
        my ( $args, $result ) = @_;
        my $domainname = $args->get('sitename');
        my $artisancmd =  $args->get('artisancmd');
        my $artisanparam = (defined $args->get( 'artisanparam')) ? $args->get( 'artisanparam') : '{}';
        my $reqtype =  $args->get('reqtype');
        my $tokenkey = $args->get('tokenkey');
        my $protocal = (defined $args->get( 'protocal')) ? $args->get( 'protocal') : 'https://';
        my $publicpath = $args->get( 'publicpath');

        my ($request, $res, $headers, $params);

        if($reqtype eq 'get') {
            $request =  '/rvsitebuilder/setupapiserver.php'.
                        '?action=artisan_cmd_run'.
                        '&homeuser='.$Cpanel::homedir.
                        '&domainname='.$domainname.
                        '&artisancmd='.$artisancmd.
                        '&artisanparam='.$artisanparam;

            $headers = {'Rvsb-Installing-Token' => $tokenkey};
            $res =  request_LwpUserAgent_get(
                                            $protocal.$domainname.$request,
                                            $headers
                                        );
            debug_log($publicpath,'artisan_cmd_run',     ('protocal' => $protocal ,'domainname' => $domainname ,'request' => $request ,'requesttype' => $reqtype));

        } else {
            $request = '/rvsitebuilder/setupapiserver.php';
            $params =	{'action' => 'artisan_cmd_run',
                        'homeuser' => $Cpanel::homedir,
                        'domainname' => $domainname,
                        'artisancmd' => $artisancmd,
                        'artisanparam' => $artisanparam,
                        };
            $headers = {'Rvsb-Installing-Token' => $tokenkey};
            $res =  request_LwpUserAgent_post(
                                        $protocal.$domainname.$request,
                                        $headers,
                                        $params
                                    );
            debug_log($publicpath,'artisan_cmd_run',('protocal' => $protocal ,'domainname' => $domainname ,'request' => $request ,'requesttype' => $reqtype));
        }

        if ($res->is_success) {
            my $response = decode_json($res->decoded_content);
            $result->data(
                    {
                        success => 'true' ,
                        reason => $response->{'message'},
                        artisan_cmd_run => ($response->{'status'}) ? 1 : 0,
                        exectime => (defined $response->{'exectime'}) ? $response->{'exectime'}  : 0,
                        page => $res->decoded_content,
                        response => $res->status_line
                    }
            );
            debug_log($publicpath,'artisan_cmd_run',('success' => 'true' ,'reason' => $response->{'message'} ,'status' => $response->{'status'}));
            return 1;
        }

        $result->data(
            {
                success => 'false' ,
                reason => "Error ".$res->decoded_content." (".$res->status_line.")",
                artisan_cmd_run =>  0,
                page => $res->decoded_content,
                response => $res->status_line
            }
        );
        debug_log($publicpath,'artisan_cmd_run',('success' => 'false' ,'reason' => "Error ".$res->decoded_content." (".$res->status_line.")"));
        return 1;
    }
    sub get_php_version{
        my ($args, $result) = @_;
        my $protocal = defined($args->get( 'protocal')) ? $args->get('protocal') : 'https://';
        my $domainname = defined($args->get('domainname')) ? $args->get('domainname') : '';
        my $publicpath = defined($args->get('publicpath')) ? $args->get('publicpath') : '';
        my $cmsversion = defined($args->get('cmsversion')) ? $args->get('cmsversion') : '';
        my $pagejson = {};
        my $phprequire;

        # get version php handle
        system("cp","/usr/local/cpanel/base/frontend/paper_lantern/rvsitebuildercms/rvsitebuildertest/phpversion.php","$publicpath/");
        my ($success,$response,$page,$repheader) = request_netSSLeay($protocal,$domainname,'/phpversion.php');
        system("rm","-f","$publicpath/phpversion.php");

        # get composer.json
        open(my $fh, "<", "$Cpanel::homedir/rvsitebuildercms/$domainname/composer.json") or die ("Can't open composer.json");
        local $/;
        my $composer_json = decode_json(<$fh>);
        if(defined $composer_json && $composer_json->{'require'}->{'php'} ne ''){
            $phprequire = $composer_json->{'require'}->{'php'};
        }
        close $fh;

        # set response and return
        if($response !~ /200 OK/){
            $result->data(
            {
                success => 'false',
                page => $page,
                response => $response,
                phprequire => $phprequire
            });
            return 1;
        }
            $pagejson = eval{ decode_json($page) };
            $result->data(
            {
                success => 'true',
                page => $pagejson,
                response => $response,
                phprequire => $phprequire,
            });
        return 1;
    }
    sub request_getversion{
        my ($args, $result) = @_;
        my $ua = LWP::UserAgent->new();
        my $publicpath = defined($args->get('publicpath')) ? $args->get('publicpath') : '';
        my $loadconfig = load_installer_config($publicpath);
        my $url = $loadconfig->{'version_url'};
        my $framework = $loadconfig->{'framework_version'};
        my $response;
        if(defined $framework && $framework eq 'stable'){
            $response = $ua->get($url.'/getrequire/rvsitebuilder/framework/tier/'.$framework)->decoded_content;
        }elsif(defined $framework && $framework =~ m/[0-9]+\.[0-9]+\.[0-9]+/){
            $response = $ua->get($url.'/getrequire/rvsitebuilder/framework/version/'.$framework)->decoded_content;
        }else{
            $response = $ua->get($url.'/getrequire/rvsitebuilder/framework/tier/stable')->decoded_content;
        }
        my $page = eval { decode_json($response) };
        $result->data({
            php => $page->{'data'}->{'require'}->{'require'}->{'php'},
            cms => $page->{'data'}->{'package_version'}
        });
        return 1;
    }

    sub create_mysql_version{
        my ($args, $result) = @_;
        my $mysql_version = defined($args->get('mysql_version')) ? $args->get('mysql_version') : '';
        my $mysql_service = defined($args->get('mysql_service')) ? $args->get('mysql_service') : '';
        if($mysql_service ne '' && $mysql_service eq 'MariaDB'){
            system("touch","$Cpanel::homedir/public_html/.mariadbversion");
            system("echo $mysql_version > $Cpanel::homedir/public_html/.mariadbversion");
        }
        if($mysql_service ne '' && $mysql_service eq 'Mysql'){
            system("touch","$Cpanel::homedir/public_html/.mysqlversion");
            system("echo $mysql_version > $Cpanel::homedir/public_html/.mysqlversion");
        }
        return 1;
    }

    sub check_writable{
        my ($args, $result) = @_;
        my $publicpath = $args->get('publicpath');
        my $dir_public = 0;
        my $dir_cms = 0;
        my $file_index = 0;
        my $file_htaccess = 0;

        # check writable
        if(-d -w "$Cpanel::homedir/public_html"){
            $dir_public = 1;
        }
        if(! -d "$Cpanel::homedir/rvsitebuildercms" || (-d -w "$Cpanel::homedir/rvsitebuildercms")){
            $dir_cms = 1;
        }
        if(! -e "$publicpath/index.php" || (-f -w "$publicpath/index.php")){
            $file_index = 1;
        }
        if(! -e "$publicpath/.htaccess" || (-f -w "$publicpath/.htaccess")){
            $file_htaccess = 1;
        }

        # set response data
        $result->data({
            'public_html' => $dir_public,
            'rvsitebuildercms' => $dir_cms,
            'index' => $file_index,
            'htaccess' => $file_htaccess,
            'domain' => $publicpath
        });
	    return 1;
    }

    1;