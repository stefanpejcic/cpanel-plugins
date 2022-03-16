#!/usr/bin/perl

BEGIN {
    my $scriptInstallcpan = '/scripts/perlinstaller';
    if(-x $scriptInstallcpan){
        my $cpanModuldeAll = {
            'JSON::WebToken'    => 'JSON/WebToken.pm',
            'DBI'               => 'DBI.pm',
            'DBD::mysql'        => 'DBD/mysql.pm',
            'LWP::UserAgent'    => 'LWP/UserAgent',
            'Net::SSLeay'       => 'Net/SSLeay.pm',
            'MIME::Base64'      => 'MIME/Base64.pm',
            'JSON'				=> 'JSON.pm'
        };
        foreach my $eachCpanModuldeName (keys %{$cpanModuldeAll}){
            my $cpanModuldeName = $eachCpanModuldeName->{$eachCpanModuldeName};
            my $hasModule = `perl -e 'eval { use $eachCpanModuldeName; print 1; }' 2>&1`;
            if ($hasModule ne '1') {
                print "Install cpan module $eachCpanModuldeName\n";
                system($scriptInstallcpan . ' ' . $eachCpanModuldeName);
            }
        }
    }
}

use strict;
use warnings;
use Data::Dumper;
use JSON;

my $tier = 'stable';
if(defined $ARGV[0]) {
	$tier = $ARGV[0];
}

#check license
CheckLicense();

#copy file
system("cp","/usr/src/rvsb7cpplugin/cpanel-plugin/api/RVsitebuilderCMS.pm","/usr/local/cpanel/Cpanel/API/RVsitebuilderCMS.pm");

if(-d "/usr/local/cpanel/base/frontend/paper_lantern"){
    system("cp","-af","/usr/src/rvsb7cpplugin/cpanel-plugin/rvsitebuildercms","/usr/local/cpanel/base/frontend/paper_lantern/");
    system("/usr/local/cpanel/scripts/install_plugin","/usr/src/rvsb7cpplugin/cpanel-plugin/rvsitebuildercms_register_cpanel_plugin.tar.gz","--theme=paper_lantern");
}

if(-d "/usr/local/cpanel/base/frontend/jupiter"){
    system("cp","-af","/usr/src/rvsb7cpplugin/cpanel-plugin/rvsitebuildercms","/usr/local/cpanel/base/frontend/jupiter/");
    system("/usr/local/cpanel/scripts/install_plugin","/usr/src/rvsb7cpplugin/cpanel-plugin/rvsitebuildercms_register_cpanel_plugin.tar.gz","--theme=jupiter");
}

#makeversion file
MakeFrameworkVersionFile($tier);

print "\nInstall Completed\n";
exit();


sub CheckLicense {

    print "Validate license status.";

    require "/usr/src/rvsb7cpplugin/rvlicense.pm";
    my $rvcode = rvsLicenseEncode();
    my $url = "https://license2.rvglobalsoft.com/getinfo/rvsitebuilder";
    my %data = getcontentbyurl($url,'POST',"rvcode=$rvcode");

    #again by http
    if ($data{'socketfail'}) {
        $url = "http://license2.rvglobalsoft.com/getinfo/rvsitebuilder";
        %data = getcontentbyurl($url,'POST',"rvcode=$rvcode");
    }

    #if not get license info
    if (!defined $data{'page'} || $data{'socketfail'}) {
        print "\nERROR : $data{'socketfail'} \n";
        exit;
    }

    my %licensedata = decodeData($data{'page'});

    #if have an error
    if (defined $licensedata{'on error'} && $licensedata{'on error'} ne '') {
         showerrortext(%licensedata);
         #issue_id 501 can update and use program
         if ($licensedata{'issue_id'} ne '501' ) {
            exit();
         } else {
            #downloadlicensefile();
         }
    }
    #if not have an error
    if (defined $licensedata{'rvsitebuilder'}) {
         installershowinfotext(%licensedata);
         #downloadlicensefile();
    }

    return;
}

sub MakeFrameworkVersionFile {
	my $tier = $_[0];
	my $urlgetversion = 'https://getversion.rvsitebuilder.com/getversions';
	if($tier =~ m/latest|stable/ ) {
        $urlgetversion = 'https://getversion.rvsitebuilder.com/getversions/tier/'.$tier;
    }
    require "/usr/src/rvsb7cpplugin/rvlicense.pm";
    my %data = getcontentbyurl($urlgetversion,'GET',"");
    #print Dumper(%data);
    #if not get version info
    if ($data{'socketfail'}) {
        print "\nERROR : $data{'socketfail'} \n";
        return;
    }

    if (!defined $data{'page'}) {
    	print "\nCan not get RVsitebuilder7 cPanel plugin version.\n";
        return;
    }
    else {
    	my $pagedata = eval  { decode_json($data{'page'}) };
    	#print Dumper($pagedata);
    	if(defined $pagedata->{'rvsitebuilder/framework'}->{'version'}) {
    		open(my $fh, '>', '/usr/local/cpanel/base/frontend/paper_lantern/rvsitebuildercms/rvsb7frameworkversion.txt');
			print $fh $pagedata->{'rvsitebuilder/framework'}->{'version'};
			close $fh;
    	}
    }
	return;
}

1;