#!/usr/bin/perl -w

use warnings;
use strict;
use Data::Dumper;
use version; our $VERSION = qv('0.0.3');
use English qw(-no_match_vars);
use Carp;

use Getopt::Long;
use Pod::Usage;

use IO::File;

use CalVAD::PEMS::StationsParse;
use File::Find;
use Digest::MD5;



my $user   = $ENV{PSQL_USER} || q{};
my $pass   = $ENV{PSQL_PASS} || q{};
my $host   = $ENV{PSQL_HOST} || q{};
my $dbname = $ENV{PSQL_DB}   || 'spatialvds';
my $port   = $ENV{PSQL_PORT} || 5432;
my $path;
my $help;
my $cdb_user   = $ENV{COUCHDB_USER} || q{};
my $cdb_pass   = $ENV{COUCHDB_PASS} || q{};
my $cdb_host   = $ENV{COUCHDB_HOST} || '127.0.0.1';
my $cdb_dbname = $ENV{COUCHDB_DB}   || 'vds_imputed_csv';
my $cdb_globaltracker = $ENV{COUCHDB_TRACKER}   || 'vdsdata/tracking';
my $cdb_port   = $ENV{COUCHDB_PORT} || '5984';


my $reparse;
my $pattern = 'd\d{2}_stations_\d{4}_\d{2}_\d{2}.txt';


my $result = GetOptions(
    'username:s'  => \$user,
    'password:s'  => \$pass,
    'host:s'      => \$host,
    'db:s'        => \$dbname,
    'port:i'      => \$port,
    'cusername:s' => \$cdb_user,
    'cpassword:s' => \$cdb_pass,
    'chost:s'     => \$cdb_host,
    'cdb:s'       => \$cdb_dbname,
    'cport:i'     => \$cdb_port,
    'path=s'      => \$path,
    'pattern=s'   => \$pattern,
    'reparse'     => \$reparse,
    'help|?'      => \$help
);

if ( !$result || $help ) {
    pod2usage(1);
}


sub digest_file{
 my $file = shift;
 open(FILE, $file) or die "Can't open '$file': $!";
 binmode(FILE);
 return Digest::MD5->new->addfile(*FILE)->hexdigest;
}


carp "directory path is $path, pattern is $pattern";
my @files = ();

sub loadfiles {
    if (-f) {
        push @files, grep { /$pattern/sxm } $File::Find::name;
    }
    return;
}
File::Find::find( \&loadfiles, $path );

@files = sort { $a cmp $b } @files;
carp 'going to process ', scalar @files, ' files';


# make a parser of data
my $parser = WIM::ParsePublic->new(

    # first the sql role
    'host_psql'     => $host,
    'port_psql'     => $port,
    'dbname_psql'   => $dbname,
    'username_psql' => $user,
    'password_psql' => $pass,

    # now the couchdb role
    'host_couchdb'     => $cdb_host,
    'port_couchdb'     => $cdb_port,
    'dbname_couchdb'   => $cdb_dbname,
    'username_couchdb' => $cdb_user,
    'password_couchdb' => $cdb_pass,
                                   # 'create'           => 1,

);





# make filehandle
my $fh = IO::File->new();

# mondo outside loop over files
for my $file (@files) {
    my $filename;
    if ( $file =~ /.*\/(.*)$/sxm ) {
        $filename = $1;
    }
    else {
        next;
    }
    # filenames look like: d03_stations_2008_08_08.txt
    # parse out the data using regex
    my $filedate;
    if ( $file =~ /(\d+)_0*(\d+)_0*(\d+)/sxm ) {
        my $dt =
          DateTime::Format::DateParse->parse_datetime( "$1-$2-$3", 'floating' );
        $filedate = DateTime::Format::Pg->format_date($dt);
    }
    if ( !$filedate ) {
        croak "couldn't parse a date from input filename $file";
    }
    # track based on digest of file
    my $digest = digest_file($file);
    carp join q/ :  /,$digest,$file;
    my $row = $parser->track( 'id' => $digest  );
    if ( $row < 0 ){
      if(!$reparse ) {
        carp "skipping $file, $digest already done according to parser";
        next;    # skip this document, go onto the next one
      }else{
        # are we checking digest?  now we are
      }
    }

    my $gzip;
    if ( $file =~ /.txt(\.gz)$/xms ) {
        if($1){
          $gzip = $1;
        }
    }

    my $handle;
    if (!$gzip &&  $fh->open("$file") ) {
      $handle = $fh;
    }elsif( $gzip && ($handle = IO::Uncompress::Gunzip->new("$file") )){
      # no op
    }
    if($handle){
        my $err = eval { slurpcode($handle,$filedate); };

        carp $handle->input_line_number();

        if ( $err || $EVAL_ERROR ) {
            $parser->track(
                'id'        => $digest,
                'otherdata' => {
                                'broken_parse' => $EVAL_ERROR,
                                'date'=>$filedate,
                               },
            );
        }
        else {
            $parser->track(
                           'id'        => $digest,
                           'row'       => $handle->input_line_number(),
                           'processed' => 1,
                           'otherdata' => {
                                           'broken_parse' => $EVAL_ERROR,
                                           'date'=>$filedate,
                                          },
                          );

          }
    } else {
        croak "cannot open file $file for readin";
    }
}
1;

__END__
