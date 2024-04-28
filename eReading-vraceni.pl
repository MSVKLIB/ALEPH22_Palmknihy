#!/exlibris/aleph/a22_1/product/bin/perl

use strict;
use DBI;

$ENV{"NLS_LANG"} = "AMERICAN_AMERICA.UTF8";

binmode STDOUT, ":utf8";

my $dbh_aleph
    = DBI->connect( 'dbi:Oracle:', 'aleph', 'aleph',
    { RaiseError => 1, AutoCommit => 0 } )
    || die "Database connection not made: $DBI::errstr";

my $sql = <<'END';
insert into mvk50.z36h 
select
to_char(CURRENT_TIMESTAMP,'YYYYMMDDHH24MISSFF1'),
Z36_REC_KEY, Z36_ID, Z36_NUMBER, Z36_MATERIAL, Z36_SUB_LIBRARY, Z36_STATUS, Z36_LOAN_DATE, Z36_LOAN_HOUR, Z36_EFFECTIVE_DUE_DATE, Z36_DUE_DATE, Z36_DUE_HOUR, to_char(sysdate,'YYYYMMDD') Z36_RETURNED_DATE, to_char(sysdate,'HH24MI') Z36_RETURNED_HOUR, Z36_ITEM_STATUS, Z36_BOR_STATUS, Z36_LETTER_NUMBER, Z36_LETTER_DATE, Z36_NO_RENEWAL, Z36_NOTE_1, Z36_NOTE_2, Z36_LOAN_CATALOGER_NAME, Z36_LOAN_CATALOGER_IP, Z36_RETURN_CATALOGER_NAME, Z36_RETURN_CATALOGER_IP, Z36_RENEW_CATALOGER_NAME, Z36_RENEW_CATALOGER_IP, Z36_RENEW_MODE, Z36_BOR_TYPE, Z36_NOTE_ALPHA, Z36_RECALL_DATE, Z36_RECALL_DUE_DATE, Z36_LAST_RENEW_DATE, Z36_ORIGINAL_DUE_DATE, Z36_PROCESS_STATUS, Z36_LOAN_TYPE, Z36_PROXY_ID, Z36_RECALL_TYPE, Z36_RETURN_LOCATION, Z36_RETURN_SUB_LOCATION, Z36_SOURCE, Z36_DELIVERY_TIME, Z36_TAIL_TIME
,Z36_UPD_TIME_STAMP,Z36_LOAN_CATALOGER_IP_V6,Z36_RETURN_CATALOGER_IP_V6,Z36_RENEW_CATALOGER_IP_V6
from mvk50.z36
where  Z36_ITEM_STATUS = '75' and Z36_DUE_DATE <= to_char(sysdate,'YYYYMMDD') and ( Z36_SUB_LIBRARY = 'MSVK' or Z36_SUB_LIBRARY = 'EBOOK')

END

my $sth_z36 = $dbh_aleph->prepare($sql);
my $r1      = $sth_z36->execute();


$sql = <<'END';
delete from mvk50.z36
where  Z36_ITEM_STATUS = '75' and Z36_DUE_DATE <= to_char(sysdate,'YYYYMMDD') and ( Z36_SUB_LIBRARY = 'MSVK' or Z36_SUB_LIBRARY = 'EBOOK')

END
$sth_z36 = $dbh_aleph->prepare($sql);
my $r2 = $sth_z36->execute();

print "$r1, $r2\n";

# $dbh_aleph->rollback() || die "rollback error";

$dbh_aleph->disconnect()
    || die "Disconnect oracle not succeeded: $DBI::errstr";
