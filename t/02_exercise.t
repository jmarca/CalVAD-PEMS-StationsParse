use Test::Modern; # see done_testing()
use Carp;
use Data::Dumper;
use Config::Any; # config db credentials with config.json

use CalVAD::PEMS::StationsParse;


# create a test database

use DBI;


##################################################
# read the config file
##################################################
my $config_file = './test.config.json';
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

my $path     = $cfg->{'path'};
my $help;

my $user = $cfg->{'postgresql'}->{'username'} || $ENV{PGUSER} || q{};
my $pass = $cfg->{'postgresql'}->{'password'} || q{};
# never use a postgres password, use config file or .pgpass
my $host = $cfg->{'postgresql'}->{'host'} || $ENV{PGHOST} || '127.0.0.1';
my $dbname =
    $cfg->{'postgresql'}->{'calvad_pems_stationsparse_db'};

my $port = $cfg->{'postgresql'}->{'port'} || $ENV{PGPORT} || 5432;

my $cdb_user =
  $cfg->{'couchdb'}->{'auth'}->{'username'} || $ENV{COUCHDB_USER} || q{};
my $cdb_pass = $cfg->{'couchdb'}->{'auth'}->{'password'}
  || q{};
my $cdb_host = $cfg->{'couchdb'}->{'host'} || $ENV{COUCHDB_HOST} || '127.0.0.1';
my $cdb_dbname =
    $cfg->{'couchdb'}->{'calvad_pems_stationsparse_db'};
my $cdb_port = $cfg->{'couchdb'}->{'port'} || $ENV{COUCHDB_PORT} || '5984';

my $admindb = $cfg->{'postgresql'}->{'admin'}->{'db'} || 'postgres';
my $adminuser = $cfg->{'postgresql'}->{'admin'}->{'user'} || 'postgres';

my $year = 2012;
my $district = 5;

isnt($port,undef,'need a valid pg port defined in env PGPORT');
isnt($user,undef,'need a valid pg user defined in env PGUSER');
isnt($dbname,undef,'need a valid pg db defined in env PGDATABASE');
isnt($host,undef,'need a valid pg host defined in env PGHOST');

isnt($cdb_port,undef,'need a valid couch port defined in "couchdb":"port" ');
isnt($cdb_dbname,undef,'need a valid couch db defined in "couchdb":"calvad_pems_statsionsparse_db"  ');
isnt($cdb_host,undef,'need a valid couch host defined in "couchdb":"host"  ');
isnt($cdb_user,undef,'need a valid couch user defined in "couchdb":"auth":"username" ');
isnt($cdb_pass,undef,'need a valid couch pass defined in "couchdb":"auth":"password" ');

my $admin_dbh;
eval{
    $admin_dbh = DBI->connect("dbi:Pg:dbname=$admindb", $adminuser);
};
if($@) {
    carp 'must have valid admin credentials in test.config.json, and a valid admin password setup in .pgpass file';
    croak $@;
}

my $create = "create database $dbname";
if($user ne $adminuser){
    $create .= " with owner $user";
}
eval {
        $admin_dbh->do($create);
};
if($@) {
    carp 'test db creation failed';
    carp $@;
    carp Dumper [
        'host_psql'=>$host,
        'port_psql'=>$port,
        'dbname_psql'=>$dbname,
        'admin database'=>$admindb,
        'admin user'=>$adminuser,
        ];

    croak 'failed to create test database';
}

## deploy required tables via DBIx::Class

use Testbed::Spatial::VDS::Schema;


## deploy just the tables I'm going to be accessing during testing

## create postgis extensions
my $postgis_args =  ["psql",
                      "-d", "$dbname",
                      "-U", "$user",
                      "-h", "$host",
                      "-p", "$port",
                     "-c", "CREATE EXTENSION postgis;"];

my $postgis_topology_args =  ["psql",
                              "-d", "$dbname",
                              "-U", "$user",
                              "-h", "$host",
                              "-p", "$port",
                              "-c", "CREATE EXTENSION postgis_topology;"];
my $db_deploy_args = ["psql",
                      "-d", "$dbname",
                      "-U", "$user",
                      "-h", "$host",
                      "-p", "$port",
                      "-f", "./sql/create_tables.sql"];

my $vdstype_args = ["psql",
                    "-d", "$dbname",
                    "-U", "$user",
                    "-h", "$host",
                    "-p", "$port",
                    "-f", "./sql/vdstype.sql"];
for my $args ( $postgis_args, $postgis_topology_args, $db_deploy_args,
    $vdstype_args )
{
    my @sysargs = @{$args};
    system(@sysargs) == 0
      or croak "system @sysargs failed: $?";
}

my $obj;
eval {
    $obj = CalVAD::PEMS::StationsParse->new(
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
};
if($@) {
  carp $@;
}

isnt($obj, undef, 'object creation should work with all required fields');
isa_ok($obj,'CalVAD::PEMS::StationsParse','it is okay');

my $connect;
eval {
  $connect = $obj->_connection_psql;
};
if($@) {
  carp $@;
}

isnt($connect, undef, 'db connection should be possible');
isa_ok($connect,'Testbed::Spatial::VDS::Schema','it is okay');
# use the connection
my $rs = $obj->resultset('Public::VdsIdAll');
isa_ok($rs,'DBIx::Class::ResultSet','got a result set');
my @all = $rs->all();
is(@all,0,'nothing in the database');

eval{
    my $vds = $obj->resultset('Public::VdsIdAll')->find(500001009);

    is($vds,undef,'nothing');
};
if($@){
    croak $@;
}

my $VAR1 = {
          'id' => 6,
          'cal_pm' => '77.632',
          'name' => 'SLOAT AVE HWY 1 SB VDS MLSB SB',
          'abs_pm' => 328.101
        };

eval{
    #$obj->storage->debug(1);
    my $vds = $obj->resultset('Public::VdsIdAll')->create($VAR1);

    isa_ok($vds,'Testbed::Spatial::VDS::Schema::Result::Public::VdsIdAll','created an entry');
};
if($@){
    croak $@;
}
eval{
    #$obj->storage->debug(1);
    my $vds = $obj->resultset('Public::VdsIdAll')->create(
        {
            'id' => 6000010092,
            'cal_pm' => '77.632',
            'name' => 'SLOAT AVE HWY 1 SB VDS MLSB SB',
            'abs_pm' => '328.101'
        }
        );

isa_ok($vds,'Testbed::Spatial::VDS::Schema::Result::Public::VdsIdAll','created an entry with a big id');

};
if($@){
    croak $@;
}

my $fh = IO::File->new();
my $file = File::Spec->rel2abs('./t/files/d05_text_meta_2012_02_25.txt');
my $filedate = $obj->guess_date($file);
isnt($filedate,undef,'got file date');

my $handle = $fh->open($file);
ok($handle,'opened file');

$w = [warnings{
    $obj->parse_file($fh,$filedate);
      }];
$fh->close();
is(scalar @{$w},0,'no problems parsing file');


done_testing;

END{
    $connect = undef;
    $obj = undef;
    eval{
        my $dbh = DBI->connect("dbi:Pg:dbname=$admindb", $adminuser);
        $dbh->do("drop database $dbname");
    };
    if($@){
        carp $@;
    }
}
