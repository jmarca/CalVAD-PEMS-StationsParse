#!/usr/bin/perl -w

use warnings;
use strict;
use Data::Dumper;
use version; our $VERSION = qv('0.0.3');
use English qw(-no_match_vars);
use Carp;
use Config::Any;

use Getopt::Long;
use Pod::Usage;

use IO::File;

use CalVAD::PEMS::StationsParse;
use File::Find;
use Digest::MD5;

#### This is the part where options are set

##################################################
# read the config file
##################################################
my $config_file = './config.json';
my $cfg = {};

# check if right permissions on file, if so, use it
if( -e $config_file){
    my @mode = (stat($config_file));
    my $str_mode = sprintf "%04o", $mode[2];
    if( $str_mode == 100600 ){

        $cfg = Config::Any->load_files({files => [$config_file],
                                        flatten_to_hash=>1,
                                        use_ext => 1,
                                       });
        # simplify the hashref down to just the one file
        $cfg = $cfg->{$config_file};
    }else{
        croak "permissions for $config_file are $str_mode.  Set permissions to 0600 (only the user can read or write)";
    }
}
else{
  # if no config file, then just note that and move on
    carp "no config file $config_file found";
}

##################################################
# translate config file into variables, for command line override
##################################################

my $year     = $cfg->{'year'};
my $district = $cfg->{'district'};
my $path     = $cfg->{'path'};
my $help;
my $outdir = $cfg->{'outdir'} || q{};

my $user = $cfg->{'postgresql'}->{'username'} || $ENV{PGUSER} || q{};
my $pass = $cfg->{'postgresql'}->{'password'}
  || q{};    # never use a postgres password, use config file or .pgpass
my $host = $cfg->{'postgresql'}->{'host'} || $ENV{PGHOST} || '127.0.0.1';
my $dbname =
    $cfg->{'postgresql'}->{'calvad_pems_stationsparse_db'} || 'spatialvds';
my $port = $cfg->{'postgresql'}->{'port'} || $ENV{PGPORT} || 5432;

my $cdb_user =
  $cfg->{'couchdb'}->{'auth'}->{'username'} || $ENV{COUCHDB_USER} || q{};
my $cdb_pass = $cfg->{'couchdb'}->{'auth'}->{'password'}
  || q{};
my $cdb_host = $cfg->{'couchdb'}->{'host'} || $ENV{COUCHDB_HOST} || '127.0.0.1';
my $cdb_dbname =
    $cfg->{'couchdb'}->{'calvad_pems_stationsparse_db'}
  || $ENV{COUCHDB_DB}
  || 'pems_stations_parsed';
my $cdb_port = $cfg->{'couchdb'}->{'port'} || $ENV{COUCHDB_PORT} || '5984';

my $reparse = $cfg->{'reparse'} || q{};


my $pattern = $cfg->{'pattern'} || 'd\d{2}_text_meta_\d{4}_\d{2}_\d{2}.txt';


my $result = GetOptions(
    'username:s'  => \$user,
    'host:s'      => \$host,
    'db:s'        => \$dbname,
    'port:i'      => \$port,
    'cusername:s' => \$cdb_user,
    'chost:s'     => \$cdb_host,
    'cdb:s'       => \$cdb_dbname,
    'cport:i'     => \$cdb_port,
    'path=s'      => \$path,
    'pattern=s'   => \$pattern,
    'reparse'     => \$reparse,
    'help|?'      => \$help
);

if ( !$result || !$path  || $help ) {
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
my $parser = CalVAD::PEMS::StationsParse->new(

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
    'create'           => 1,

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
    my $filedate = $parser->guess_date($file);
    if ( !$filedate ) {
        croak "couldn't parse a date from input filename $file";
    }
    # track based on digest of file
    my $digest = digest_file($file);
    carp join q/ :  /,$digest,$file;
    my $row = $parser->track( 'id' => $digest );
    if ( $row < 0 ){
      if(!$reparse ) {
        carp "skipping $file, $digest already done according to parser";
        next;    # skip this document, go onto the next one
      }else{
        # are we checking digest?  now we are
      }
    }
    # add the filename to the couchdb...while md5 is useful, it isn't readable
    $parser->track( 'id' => $digest,
                    'otherdata' => {
                        'filename' => $file,
                        'date'=>$filedate,
                    },
        );

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
        my $err = eval { $parser->parse_file($handle,$filedate); };

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
