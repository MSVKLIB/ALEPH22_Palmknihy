#!/exlibris/aleph/a22_1/product/bin/perl
#Fix creates URL link / 856 field for ebook loan based on item the record has
#intended for Palmknihy and Flexibooks, for wwwfull expansion for OPAC and for export to primo (OAI)
#Made by Matyas F. Bajger, 2023
#
#enh1 202401 - pujcovani audioknih, s extra statusem jednotky
#rc1 20240223 - restapi pro dohledani jednotek nevraci skryte jednotky. Prehozeno na x-server
#                pouziva api funkci item-data, ktera musi byt dle nastaveni prav volne pristupna bez user/password (povolena pro user WWW-X)
#
use strict;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDIN, ":utf8");
use POSIX qw/strftime/;
use Data::Dumper;
use LWP;
use Switch;
use Env;
use Storable qw/freeze/; #for array equality check. cf. https://www.tutorialspoint.com/how-to-compare-two-arrays-for-equality-in-perl
$Storable::canonical = 1;
use XML::Simple qw(:strict);
use URI::Escape;

##PARAMETERS
my $opacDomain='katalog.svkos.cz';
#rc1 my $restApiPath='http://localhost:1891'; #path to restapi, including protocol and port
my $xApiPath='http://localhost'; #path to x-server api, including protocol and port, rc1
my $bibBase='MVK01';
my $admBase='MVK50';
my @ebookItemStatusCode=('75','76'); #item status code used for ebooks. Array - you can set more values
my $ebookLinkText="Vypůjčit e-knihu"; #text for link, used for 856 field, y subfield #enh1
my @audiobookItemStatusCode=('75','76'); #item status code used for eudiobooks. Array - you can set more values, enh1 
my $audiobookFMTvalue='AM'; #value of FMT field for audiobbooks. Audiobook can by determined by two ways: special item status ot FMT value (or both), enh1
my $audiobookLinkText="Vypůjčit e-audioknihu"; #text for link, used for 856 field, y subfield #enh1
my $createLinkInfo=0; #if true (1), expansion creates also 85642 field to provider website with book info based on z30-description value
    my $linkInfoText='Info o e-knize';
my $createLinkPreview=0; #if true (1), expansion creates also 85641 field to provider website with book preview based on z30-note-opac value
    my $linkPreviewText='Náhled e-knihy';
    

my $isEbook=0; #value for checking NUM field
my $isAudiobook=0; #value for matching aufiobooks
my $recordSysNo='';
my $fields856;
my $FMTvalue=''; #enh1
if (freeze(\@ebookItemStatusCode) eq freeze(\@audiobookItemStatusCode) ) { @audiobookItemStatusCode=(); } #enh1. if one code is used for ebooks and audio, set unreal code for audio (and use FMT field value instead
while (<>) { # read lines from BIB record, one by one, and create an array containf the record
   my $line=$_;
   $line =~ s/^\s+|\s+$//g;
   if ( $line eq '' ) { #last line
      last;
      }
   if ( not ($line =~ m/^$bibBase/) ) {
      #check if is ebook on base of NUM field
      if ( $_ =~ m/^NUM/) {
         $isEbook=1;
         }
      if ( $_ =~ m/^FMT  L$audiobookFMTvalue/) {
         $isAudiobook=1;
         }
      if ( $_ =~ m/^856/ ) { #radky 856 vypis az na konci po vygenerovanem linku na e-vypujcku, ostatni pole hned
         unless ( $line =~ m/8564.+func=item-hold-request/ ) { $fields856.= "$line\n"; }
         }
      else {
         #pokud uz zaznam obsahuje link na e-vypujcku, vyluc ho a generuj jinde znova
         unless ( $line =~ m/8564.+func=item-hold-request/ ) {
            print "$line\n"; #print line
            }
         }
      }
    else {
      $recordSysNo=$line;
      $recordSysNo =~ s/$bibBase//;
      }   
   }

#create 856 field(s)
      if ( $isEbook ) {
      #get item info
	  my $countEbook = 0; 
      my $ua = LWP::UserAgent->new;
      $ua->timeout(10);
      #rc1 my $response = $ua->get($restApiPath.'/rest-dlf/record/'.$bibBase.$recordSysNo.'/items?view=full');
      #rc1 my $response = $ua->get($restApiPath.'/rest-dlf/record/'.$bibBase.$recordSysNo.'/items/items?view=full');
      my $response = $ua->get($xApiPath.'/X?op=item-data&doc_number='.$recordSysNo.'&base='.$bibBase); #rc1
      if ($response->is_success) {
          my $items = XMLin( $response->decoded_content, ForceArray => 1, KeyAttr => {});
	  # zjistit, zda je více jednotek
	  #rc1 foreach my $key (@{$items->{items}[0]->{item}}) {
	  foreach my $key (@{$items->{item}}) { #rc1
             #rc1 my $isc=$key->{'z30-item-status-code'}[0];
             #rc1 my $ipsc=$key->{'z30-item-process-status-code'}[0];
             my $loaned = $key->{'loan-status'}[0] ? $key->{'loan-status'}[0] : ''; #rc1
             next if ($loaned); #rc1
             my $isc = $key->{'item-status'}[0]; #rc1, xserver does not have element for process status. If this is set, it's value is given to item-status el.
             #rc1 $ipsc = ref($ipsc) eq 'HASH' ? '' : $ipsc;
             #rc1 if ((grep(/$isc/, @ebookItemStatusCode) || grep(/$isc/, @audiobookItemStatusCode)) && $ipsc eq '') {
             if (grep(/$isc/, @ebookItemStatusCode) || grep(/$isc/, @audiobookItemStatusCode) )  { #rc1
               $countEbook++;
               last if $countEbook > 1;
             }
          }
          #rc1 foreach my $key ( @{$items->{items}[0]->{item}} ) {
          foreach my $key ( @{$items->{item}} ) { #rc1
             #if ($key->{'z30-item-status-code'}[0] eq $ebookItemStatusCode) { #this is ebook
             #rc1 my $isc=$key->{'z30-item-status-code'}[0];
             #rc1 my $ipsc=$key->{'z30-item-process-status-code'}[0];
             #rc1 $ipsc = ref($ipsc) eq 'HASH' ? '' : $ipsc;
	     #rc1	 next if ( $ipsc ); # vzorova ebook jednotka nemá status zpracování, přeskočit jednotku se statusem 

             my $loaned = $key->{'loan-status'}[0] ? $key->{'loan-status'}[0] : ''; #rc1
             next if ($loaned); #rc1

             my $isc=$key->{'item-status'}[0]; #rc1         
             
             if ( grep(/$isc/, @ebookItemStatusCode) || grep(/$isc/, @audiobookItemStatusCode) )  { #this is ebook or audiobook, enh1
                #rc1 start
                my $itemRecKey = $key->{'rec-key'}[0];
                my $admno = substr($itemRecKey,0,9);
                my $itemno = substr($itemRecKey,9,6);
                my $itemDescription = $key->{'description'}[0] ? $key->{'description'}[0] : '';
                my $itemNoteOpac = $key->{'note'}[0] ? $key->{'note'}[0] : '';
                #my $admno = $key->{z30}[0]->{'z30-doc-number'}[0];
                #my $itemno = $key->{z30}[0]->{'z30-item-sequence'}[0];
                #my $itemDescription = $key->{z30}[0]->{'z30-description'}[0];
                #my $itemNoteOpac = $key->{z30}[0]->{'z30-note-opac'}[0];
                #$itemno =~ s/\s//g;
                #$itemno =~ s/\.[0]+$//;
                #$itemno .= '0';
                #$itemno = sprintf ("%06d\n", $itemno); #zero lpad
                #$itemno =~ s/\n//g; $itemno =~ s/\r//g;
                #rc1 end
                my $text2link = ''; #enh1
                if ( $isAudiobook or  grep(/$isc/, @audiobookItemStatusCode) ) {
                    $text2link=$audiobookLinkText; }
                else { 
                    $text2link=$ebookLinkText; }
                #preber text popisu jednotky, je v nem pripadne rozliseni dilu. 20240126
		my $desc2link = '';
		if ($countEbook > 1) {  #více jednotek, zapsat do odkazu popi
                    $desc2link = $itemDescription ? ' - '.$itemDescription : ''; 
		    }
                print '85640L$$uhttps://'.$opacDomain.'/F/?func=item-hold-request&doc_library='.$admBase.'&adm_doc_number='.$admno.'&item_sequence='.$itemno.'$$y'.$text2link.$desc2link.'$$4N'."\n"; #enh1
                #link to provider info page
                if ($createLinkInfo and $itemDescription) {
                   if ($itemDescription =~ /^http/ ) {
                      print '85642L$$u'.$itemDescription.'$$y'.$linkInfoText.'$$4N'."\n";
                      }
                   }
                #link to preview
                if ($createLinkPreview and $itemNoteOpac) {
                   if ($itemNoteOpac =~ /^http/ ) {
                      print '85641L$$u'.$itemNoteOpac.'$$y'.$linkPreviewText.'$$4N'."\n";
                      }
                   }
                # last; #20240126 not last! If record has more ebook items, links for all of them must be created
                }
             }
          }
      }


if ( $fields856 ) { print "$fields856"; }
