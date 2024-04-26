#!/exlibris/aleph/a22_1/product/bin/perl

#BEN 11.12.2023 Palmknihy sub mode_ereading - upraveno na nový feed
#RC2 20240205 - chybne ukonceni skriptu die vraci prohlizeci obecnou chybu, neahrazeno chybovou hlaskou uzivateli. Matyas B.

#RC3 20240206 - v url volajici refereru nemusi byt session. Je ale v cookie. Doplneno do opac sablony item-hold-request-head-flexibooks-self-check at se doda session i do url, za <body> tam pridan nasledujici skript. Matzas B.
#<script type="text/javascript">
#//flexibooks RC3
#function getCookie(cname) {
#  let name = cname + "=";
#  let decodedCookie = decodeURIComponent(document.cookie);
#  let ca = decodedCookie.split(';');
#  for(let i = 0; i <ca.length; i++) {
#     let c = ca[i];
#     while (c.charAt(0) == ' ') { c = c.substring(1); }
#     if (c.indexOf(name) == 0) { return c.substring(name.length, c.length); }
#     }
#  return "";
#  }
#if ( !window.location.href.match(/\/F\/[\dA-Z]+/) ) { //url does not contain session, get it from cookie
#   let as=getCookie('ALEPH_SESSION_ID');
#   if ( as ) { //redirect to url with session
#      window.location = window.location.href.replace('/F/','/F/'+as);
#      }
#   }
#</script>

use strict;
use warnings;
use diagnostics;
use utf8;
binmode STDOUT, ":utf8";
use XML::Simple qw(:strict);
use DBI;
use URI::Escape;

use CGI;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

my $q = CGI->new;
require LWP::UserAgent;
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);

use Time::HiRes q/gettimeofday/;

$| = 1;    # unbuffered output

my $ua = LWP::UserAgent->new;
$ua->timeout(30);
$ua->env_proxy;

#my $in_file = shift or die "input XML file needed\n";

my $url = 'http://localhost/X';

my $xml;
my $x_barcode;

#eval {

$ENV{"alephe_tab"} = '/exlibris/aleph/u22_1/alephe/tab';
my $usr_library = 'MVK50';
my $adm_library = 'MVK50';

$ENV{"aleph_db"}    = 'katalog.aleph22';
$ENV{"ORACLE_HOME"} = '/exlibris/app/oracle/product/11r2';
$ENV{"LOGDIR"}      = '/exlibris/aleph/a22_1/log';
$ENV{"NLS_LANG"}    = "AMERICAN_AMERICA.UTF8";

my $config_file_name = $ENV{'alephe_tab'} . '/ereading.cfg';

open( my $LOGFILE, ">>", $ENV{"LOGDIR"} . "/ereading.log" )
    #RC2 || die "cannot open logfile " . $ENV{"LOGDIR"} . "/ereading.log";
    || exemption ("cannot open logfile " . $ENV{"LOGDIR"} . "/ereading.log", 'WARNING', 'unknown_error');
binmode( $LOGFILE, ":unix" );
open( STDERR, ">&", $LOGFILE )
    #RC2 || die "cannot redirect stderr";
    || exemption ("cannot redirect stderr", 'WARNING', 'unknown_error');
select(STDERR);
$| = 1;    # make unbuffered
select(STDOUT);
$| = 1;    # make unbuffered
print $LOGFILE get_time3(), " START\n";

my $sth_aleph;
$ENV{'ORACLE_SID'} = 'aleph22';
my $dbh_aleph = DBI->connect( 'dbi:Oracle:',
    'aleph', 'aleph', { RaiseError => 1, AutoCommit => 0, Warn => 1 } )
    #RC2 || die "03 oracle connection error: $DBI::errstr";
    ||  exemption ("03 oracle connection error: $DBI::errstr", 'ERROR', 'database_error');
my $referer = $q->referer();
my $session_id;

#my $referer_host;
my $mode = 'CHYBA';

#20240209 if (( $referer =~ /^https?:\/\/([^\/]+)\/F\/([0-9A-Z]{50})-[0-9]+/ ) && (defined CGI::param('adm_doc_number')))
if (( $referer =~ /^https?:\/\/([^\/]+)\/F\/([0-9A-Z\-]{50,70})/ ) && (defined CGI::param('adm_doc_number')))
   {
      $session_id = $2;
      $session_id =~ s/\-.+$//; #20240209
      #    $referer_host = $1;
      $mode = 'SELFCHECK';
   }
elsif ( defined CGI::param('bar') ) {
    $mode = 'EREADING';
    if ( $referer =~ /.*?func=self-check&.*&session=([0-9A-Z]{50,70})(&.*)*$/ ) {
        $session_id = $1;
    }
    if ( $referer =~ /.*?func=self-check&.*mode=FLEXIBOOKS/) {
        $mode = 'FLEXIBOOKS';
    }

}
else {
    $session_id = 'CHYBA';
}

print $LOGFILE get_time3(), " REFERER: $referer",    "\n";
print $LOGFILE get_time3(), " MODE: $mode, QS: ",    $q->query_string(), "\n";
print $LOGFILE get_time3(), " SESSION: $session_id", "\n";

my $sql
    = "select Z63_CLIENT_ADDRESS,Z63_BOR_ID from vir01.z63 where Z63_REC_KEY = ?";
$sth_aleph = $dbh_aleph->prepare($sql)
    #RC2 or die "Couldn't prepare statement: " . $dbh_aleph->errstr;
    or exemption( "Couldn't prepare statement: " . $dbh_aleph->errstr,  'ERROR', 'database_error');
$sth_aleph->execute($session_id)
    #RC2 or die "Couldn't execute statement: " . $sth_aleph->errstr;
    or exemption( "Couldn't execute statement: " . $sth_aleph->errstr,  'ERROR', 'database_error');
my ( $z63_client_address, $z63_bor_id ) = $sth_aleph->fetchrow_array()
    #RC2 or die "No session";
    or exemption("No session - no z63_bor_id found in z36 table",'ERROR', 'no_session');

$z63_client_address =~ s/\.0+/./g;
$z63_client_address =~ s/^0+//;

print $LOGFILE get_time3(),
    " z63_bor_id: $z63_bor_id, z63_client_address: $z63_client_address\n";

#RC 20190423 vybira se jen platna adresa dle data
#       dale se vybira typ adresy 1,2 a preferovane 2
#$sql
    #= "select distinct Z304_EMAIL_ADDRESS from ${usr_library}.z304 where trim(substr(Z304_REC_KEY,1,12)) = ? and trim(Z304_EMAIL_ADDRESS) is not NULL and Z304_EMAIL_ADDRESS like '%@%' and rownum=1";
my $today = strftime( '%Y%m%d', localtime );
$sql = "select distinct Z304_EMAIL_ADDRESS from ${usr_library}.z304 where trim(substr(Z304_REC_KEY,1,12)) = ? and trim(Z304_EMAIL_ADDRESS) is not NULL and Z304_EMAIL_ADDRESS like '%@%' and Z304_DATE_FROM <= $today and Z304_DATE_TO >=$today and Z304_ADDRESS_TYPE=2 and rownum=1";
$sth_aleph = $dbh_aleph->prepare($sql)
    or die "Couldn't prepare statement: " . $dbh_aleph->errstr;
$sth_aleph->execute($z63_bor_id)
    or die "Couldn't execute statement: " . $sth_aleph->errstr;
my $er_user = '';
my @er_arr = $sth_aleph->fetchrow_array();
my $er_arr_lenth = scalar @er_arr;
if ( $er_arr_lenth > 0 ) {
    $er_user = @er_arr[0];
    }
else {    
    print $LOGFILE get_time3(), " adress type 02 not found, looking for type 01\n";
    $sql = "select distinct Z304_EMAIL_ADDRESS from ${usr_library}.z304 where trim(substr(Z304_REC_KEY,1,12)) = ? and trim(Z304_EMAIL_ADDRESS) is not NULL and Z304_EMAIL_ADDRESS like '%@%' and Z304_DATE_FROM <= $today and Z304_DATE_TO >=$today and Z304_ADDRESS_TYPE=1 and rownum=1";
    $sth_aleph = $dbh_aleph->prepare($sql)
        or die "Couldn't prepare statement: " . $dbh_aleph->errstr;
    $sth_aleph->execute($z63_bor_id)
        or die "Couldn't execute statement: " . $sth_aleph->errstr;
    $er_user = $sth_aleph->fetchrow_array() or die "no er_user";
    }
print $LOGFILE get_time3(), " er_user: $er_user\n";
#RC2 die "vadny mail" until $er_user =~ /@/;
until ($er_user =~ /@/) { exemption("Vadny email - $er_user",'ERROR','bad_email'); }

my $fb_user = $er_user;

mode_selfcheck() if ( $mode eq 'SELFCHECK' );
mode_ereading()  if ( $mode eq 'EREADING' );
mode_flexibooks()  if ( $mode eq 'FLEXIBOOKS' );

$sth_aleph->finish     or warn $sth_aleph->errstr;
$dbh_aleph->disconnect or warn $dbh_aleph->errstr;
print $LOGFILE get_time3(), " END $mode\n";

#} or do { };

exit;

sub get_time3 {
    my ( $seconds, $microseconds ) = gettimeofday;
    return strftime( q/%FT%T/, localtime($seconds) )
        . sprintf( ".%03d", $microseconds / 1000 );
}

sub mode_selfcheck {
    print $LOGFILE get_time3(), " BEGIN $mode\n";
    my %form;
    my $data;
    my $in_file_name = $ENV{'DOCUMENT_ROOT'} . '/75_EB_item_template.xml';
    open( my $in_file_handle, '<', $in_file_name )
        #RC2 or die "Cannot open file as input\n";
        or exemption ("Cannot open file $in_file_name as input",'ERROR','unknown_error');
    while (<$in_file_handle>) { $data .= $_; }

    $xml = XMLin(
        $data,
        ForceArray => 0,
        KeyAttr    => {},
        KeepRoot   => 1,
    );

    $sql
        = "select Z30_CALL_NO from ${adm_library}.z30 where Z30_REC_KEY like ?||'%'
 and trim(Z30_ITEM_PROCESS_STATUS) is NULL and Z30_COLLECTION = 'EREAD'";

    $form{'adm_doc_number'} = CGI::param('adm_doc_number');
    $form{'item-sequence'} = CGI::param('item-sequence');

    $sth_aleph = $dbh_aleph->prepare($sql)
        #RC2 or die "Couldn't prepare statement: " . $dbh_aleph->errstr;
        or exemption ("Couldn't prepare statement: " . $dbh_aleph->errstr,'ERROR','database_error');
    #nasledujici bralo prvni jednotku z ADM zaznamu. Problem pokud byly jednotky vzajemne odlisne - napr. svkos ADM 532887
    #musi se pridat do dotazu i cislo jednotky
    #Matyas Bajger 20180116
    #$sth_aleph->execute( $form{'adm_doc_number'} )
    $sth_aleph->execute( $form{'adm_doc_number'}.$form{'item-sequence'} )
        #RC2 or die "Couldn't execute statement: " . $sth_aleph->errstr;
        or exemption ("Couldn't execute statement: " . $sth_aleph->errstr,'ERROR','database_error');

print $LOGFILE "where Z30_REC_KEY like ",$form{'adm_doc_number'}, " ... ",$form{'item-sequence'},"\n";
    my ($z30_call_no) = $sth_aleph->fetchrow_array()
        #RC2 or die "no callno";
        or exemption ("no callno found in z30 table",'ERROR','database_error');

    $xml->{'z30'}->{'z30-call-no'} = $z30_call_no;
    $xml->{'z30'}->{'z30-enumeration-a'} = $z30_call_no;  #vícedílné exempláře potřebují být odlišné Ben20240223

    $data = XMLout(
        $xml,
        NoAttr   => 1,
        KeyAttr  => [],
        RootName => undef,
        XMLDecl  => '<?xml version = "1.0" encoding = "UTF-8"?>',
    );

    print $LOGFILE "NEW DATA - create_item xml_full_req:\n$data\n";

    $form{'xml_full_req'} = $data;
    $form{'op'}           = 'create_item';

#
# Adm_Library: This is a mandatory parameter to determine the Administrative library in which new item is to be created.
#
    $form{'adm_library'} = 'mvk50';

#
# Bib_Library: This parameter is not mandatory. It should be used when the new item should be created for a bib record. If no Adm_Doc_Number is specified, then this parameter is a must.
#
    $form{'bib_library'} = 'mvk01';

#
# Adm_Doc_Number: This parameter is not mandatory. It should be used when the new item should be created for an already existing ADM record. But if this parameter is provided and there is no such ADM record, then service is aborted.
#
    my $z30_rec_key = sprintf( "%09u%06u", $form{'adm_doc_number'},
        $form{'item-sequence'} );

    #
    # Bib_Doc_Number: The same as Bib_Library.
    #
    $form{'bib_doc_number'} = '';
    $form{'user_name'}      = 'ebook-x';
    $form{'user_password'}  = 'selfchitem';

    my $sf_success = 0;
    my $res = $ua->post( "$url", \%form );
    if ( $res->is_success ) {

        $xml = XMLin(
            $res->content,
            ForceArray => ['error'],
            KeyAttr    => {},
            KeepRoot   => 0,
        );

        #$x_barcode = $xml->{'create-item'}->{'z30'}->{'z30-barcode'};
        $x_barcode = $xml->{'z30'}->{'z30-barcode'};

        foreach my $x_tmp ( @{ $xml->{'error'} } ) {

            $sf_success = 1
                if ( $x_tmp =~ 'Item has been created successfully' );
        }

    }
    else {
        print $LOGFILE "\nError: " . $res->code . " " . $res->message . "\n";
    }
    print $LOGFILE "\ncreate_item result:\n" . $res->content . "\n";

    my $self_check_url
        = "/F/?func=self-check&CONTINUE=Y&BARCODE=$x_barcode&session=$session_id&mode=eReading";

    print $LOGFILE "-> self_check_url: $self_check_url\n";

    print $q->redirect($self_check_url);

}

sub mode_ereading {
  print $LOGFILE get_time3(), " BEGIN $mode\n";

  my $er_passkey              = 'phup3SteWUs6Ex3Beqaj7yabrEth4nek';
  my $er_id                   = '5';
  my $self_check_body_barcode = CGI::param('bar');
    #DEBUG
    #    $er_user = 'rataj%40cuni.cz';
  $er_user =~ s/ *,.*//;
  $er_user =~ s/ *;.*//;
  #$er_user = uri_escape($er_user);
  $er_user = uri_escape($er_user, "^A-Za-z0-9\@\.\_\~\-"); # BEN pomlcka musi byt posledni, jinak bere jako minus
  my $er_count = 1;
  my $er_time = time;
  my $er_type = 2;

  print $LOGFILE "self_check_body_barcode: $self_check_body_barcode\n";
  $sql
        = "select trim(Z30_CALL_NO) from ${adm_library}.z30 where trim(Z30_BARCODE) = ?";
  $sth_aleph = $dbh_aleph->prepare($sql)
        or die "Couldn't prepare statement: " . $dbh_aleph->errstr;
  $sth_aleph->execute($self_check_body_barcode)
        or die "Couldn't execute statement: " . $sth_aleph->errstr;
  my ($er_ebook) = $sth_aleph->fetchrow_array() or die "no er_ebook";
  print $LOGFILE "er_ebook: $er_ebook\n";


=begin
##stary feed / zakomentovano
    my $er_url
        = "?knihovna=$er_id&user=$er_user&count=$er_count&ebook=$er_ebook&time=$er_time";

    my $er_hash = md5_hex( $er_url, $er_passkey );
    print $LOGFILE "er_url: $er_url\n";
    print $LOGFILE "er_hash: $er_hash\n";

    $er_url
        = "http://ereading.cz/api_knihovny/vypujcit.php" 
        . $er_url
        . "&hash=$er_hash";

    print $LOGFILE "er_url: $er_url\n";

### DEBUG
    #    my $er_res = '<xml><state>OK</state></xml>';
    #    $xml = XMLin(
    #        $er_res,
    #        ForceArray => 0,
    #        KeyAttr    => {},
    #        KeepRoot   => 0,
    #    );

    my $er_res = $ua->get($er_url);
    if ( $er_res->is_success ) {

        print $LOGFILE "er_res: " . $er_res->content . "\n";
#        $xml = XMLin(
#            $er_res->content,
#            ForceArray => 0,
#            KeyAttr    => {},
#            KeepRoot   => 0,
#        );
    }
    my $er_success = 1;

#    print $LOGFILE "xml->state: " . $xml->{'state'} . "\n";
#    $er_success = 0 until $xml->{'state'} eq 'OK';
=cut

#BEN 20240112 - půjčení z nového feedu - v perlu nejde sha256, proto volání php

  my $php_script = 'pk-rent.php';  #akt. adresář /exlibris/aleph/u22_1/alephe/apache/cgi-bin/
  # Sestavení příkazu pro volání PHP skriptu s parametry
  my $command = "php $php_script $er_user $er_ebook";
  # Volání PHP skriptu a získání výstupu
  my $output = `$command`;

  # Oddělení hlavičky a XML dat
  my ($header, $xml_data) = split(/\n\}\n/, $output, 2);
  print $LOGFILE "xml_data: " . $xml_data . "\n";

  # Parsování XML výstupu
  my $xml_output = XML::Simple->new();
  my $data = $xml_output->XMLin($xml_data, ForceArray=>0, KeyAttr=>{}, KeepRoot=>0);

  # Získání hodnot z proměnné $data
  my $status = $data->{status};
  my $message = $data->{message};
  print $LOGFILE "Status: $status\n"; 
  print $LOGFILE "Message: $message\n";

  if ($status == '200') {
      print $LOGFILE "-> /\n";
    }
  else {
    my $dev_message = $data->{dev_message};
    print $LOGFILE "Dev Message: $dev_message\n";
	
    open(MAIL, "|/usr/sbin/sendmail -t");
    binmode MAIL, ":encoding(UTF-8)";
    print MAIL 'To: it@msvk.cz; poradna@msvk.cz'."\n";
    print MAIL 'From: aleph@svkos.cz'."\n";
    print MAIL 'Subject: Palmknihy vypujcka - chyba pri vypujceni'."\n\n";
    print MAIL "Status: $status"."\n";
    print MAIL "Message: $message"."\n";
    print MAIL "Dev Message: $dev_message"."\n\n";
    print MAIL 'Zkontrolujte LOG soubor /exlibris/aleph/a22_1/log/ereading.log.'."\n".'Vas Aleph'."\n";
    print $LOGFILE "Email odeslán\n"; 
    }
  print $q->redirect('/F/?func=bor-loan');
}

sub mode_flexibooks {
#presmeruje se sem z flexibooks - nevim proc	
    print $LOGFILE get_time3(), " BEGIN $mode\n";

#    my $fb_priv_key             = '36EE5D4C-22A6-48A1-9906-F440E3A392F8';
#    my $fb_library              = 'msvk@svkos.cz';
    my $fb_priv_key             = '8957191D-3D5E-46EA-88EF-546C9F7FDF5B';
    my $fb_library              = 'oravova@svkos.cz';
    my $self_check_body_barcode = CGI::param('bar');
#    my $self_check_body_0100    = CGI::param('r1');
#    my $self_check_body_8000    = CGI::param('r2');

    #DEBUG
#    $fb_user = 'rataj@cuni.cz';
    my $fb_count = 1;

    my $fb_time = time;
    my $fb_hash = md5_hex( $fb_time, $fb_priv_key );
    my $fb_type = 2;

    print $LOGFILE "self_check_body_barcode: $self_check_body_barcode\n";
    $sql
        = "select trim(Z30_CALL_NO) from ${adm_library}.z30 where trim(Z30_BARCODE) = ?";
    $sth_aleph = $dbh_aleph->prepare($sql)
        #RC2 or die "Couldn't prepare statement: " . $dbh_aleph->errstr;
        or exemption( "Couldn't prepare statement: " . $dbh_aleph->errstr,'ERROR','database_error');
    $sth_aleph->execute($self_check_body_barcode)
        #rc2 or die "Couldn't execute statement: " . $sth_aleph->errstr;
        or exemption( "Couldn't execute statement: " . $sth_aleph->errstr,'ERROR','database_error');
    my ($fb_id) = $sth_aleph->fetchrow_array() 
        #RC2 or die "no fb_id";
        or exemption( "table z30 returned no rows - no fb_id",'ERROR','database_error');
    print $LOGFILE "fb_id: $fb_id\n";
    my $fb_url
        = "https://flexibooks.cz/api/create_request/?library=$fb_library&user=$fb_user&count=$fb_count&ebook=$fb_id&time=$fb_time&hash=$fb_hash&type=$fb_type";

    print $LOGFILE "fb_url: $fb_url\n";

### DEBUG
    #    my $fb_res = '<xml><state>OK</state></xml>';
    #    $xml = XMLin(
    #        $fb_res,
    #        ForceArray => 0,
    #        KeyAttr    => {},
    #        KeepRoot   => 0,
    #    );

    my $fb_res = $ua->get($fb_url, 'User-Agent' => 'ALEPH MSVK');
    if ( $fb_res->is_success ) {

        print $LOGFILE "fb_res: " . $fb_res->content . "\n";
        $xml = XMLin(
            $fb_res->content,
            ForceArray => 0,
            KeyAttr    => {},
            KeepRoot   => 0,
        );
    }
    my $fb_success = 1;

    print $LOGFILE "xml->state: " . $xml->{'state'} . "\n";
    $fb_success = 0 until $xml->{'state'} eq 'OK';

    if ($fb_success) {
        print $LOGFILE "-> /\n";

        print $q->redirect('/F/?func=bor-loan');

    }
}

print $LOGFILE "\n------------------------------------------------------------------------------------------\n\n";


sub exemption { #RC2 - subrouting for handling errors, param1-errortext, param2-errorlevel, param3-errortext for user (if different than for log)
   my ($et,$el,$etu) = @_;
   $el = $el ? $el : 'ERROR';
   $etu = $etu ? $etu : $et;
   print $LOGFILE get_time3(), "$el - $et\n"; 
   close ($LOGFILE);
   if ( $el ne "WARNING" ) {
      print $q->redirect('/F/?func=file&file_name=flexibooks-error&cgierror='.uri_escape($etu));
      }
   exit 0;
   }
