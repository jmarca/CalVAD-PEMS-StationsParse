
package CalVAD::PEMS;

use Moops;
# ABSTRACT: Breaks up the daily all-vds-per-district files into yearly per vds files

class StationsParse using Moose : ro {

    use Carp;
    use Data::Dumper;
    use English qw(-no_match_vars);
    use File::Path qw(make_path);
    use Testbed::Spatial::VDS::Schema;
    use DateTime::Format::Pg;
    use DateTime::Format::Strptime;
    use Text::CSV;
    with 'CouchDB::Trackable';


    my $param = 'psql';

    has 'inner_loop_method' =>
        ( is => 'ro',
          isa => 'CodeRef',
          init_arg => undef,
          builder => '_build_inner_loop_method',);


    has 'csv' =>
        ( is => 'ro',
          isa=>'Text::CSV',
          init_arg =>undef,
          builder=>'_build_csv',
          lazy=>1,
        );

    has 'geometry_gen_code' => (
        'is' => 'ro',
        'isa'=>'CodeRef',
        'init_arg'=>undef,
        'builder'=>'_build_geometry_gen_code',
        'lazy'=>1
        );

    method _build_csv {
        # set up the csv parser
        my $csv = Text::CSV->new( { 'sep_char' => "\t",
                                    'allow_loose_quotes'=>1,
                                    'blank_is_undef'=>1,
                                  } );

        # bind variables to lines
        $csv->column_names(
            qw{vdsid fwy dir district county city state_pm abs_pm latitude longitude length type lanes name user_id_1 user_id_2 user_id_3 user_id_4}
            );

        $csv->types ([Text::CSV::IV (), # vdsid
                      Text::CSV::IV (), # fwy
                      Text::CSV::PV (), # dir
                      Text::CSV::IV (), # district
                      Text::CSV::IV (), # county
                      Text::CSV::IV (), # city
                      Text::CSV::PV (), # state_pm
                      Text::CSV::NV (), # abs_pm
                      Text::CSV::NV (), # latitude
                      Text::CSV::NV (), # longitude
                      Text::CSV::NV (), # length
                      Text::CSV::PV (), # type
                      Text::CSV::IV (), # lanes
                      Text::CSV::PV (), # name
                      Text::CSV::PV (), Text::CSV::PV (), Text::CSV::PV (), Text::CSV::PV (),# user_id_1..4
                     ]);


        return $csv;
    }


    method get_new_geoid {
        my $geoid;
        my $test_eval = eval { $geoid = $self->resultset('Public::GeomId')->create( { 'dummy' => 1 } ); };
        if ($EVAL_ERROR) {    # find or create failed
            carp "can't create new geomid $EVAL_ERROR";
            croak;
        }
        return $geoid;
    }

    method create_geompoint_4269 ($lon,$lat,$gid){
        my $creategeom;
        # ST_GeometryFromText('POINT("+lon+" "+lat+")',"+SRID+")
        my $geomfn = join q{}, 'POINT(', $lon, q{ }, $lat, q{)};
        my $arr = [ q/ST_GeometryFromText(?,4269)/, ['dummy'=>$geomfn] ];
        my $test_eval = eval {
            $creategeom = $self->resultset('Public::GeomPoints4269')->create(
                {
                    gid  => $gid,
                    geom => \$arr,
                }
                )};
        if ($EVAL_ERROR) {    # find or create failed
            carp "can't create new geometry $EVAL_ERROR";
            croak;
        }

        # carp 'created new geom_points_4269 entry';
        return $creategeom;
    }
    method project_geom_4326(Int $gid4269,Int $gid4326){
        # carp "projecting from $gid4269 to $gid4326";
        my $transform;
        my $test_eval = eval {
            my $arr = [q/ST_AsText(ST_Transform(me.geom,4326))/];
            ($transform) = $self->resultset('Public::GeomPoints4269')->search(
                { 'gid' => $gid4269 },
                {
                    select => [ 'gid', \$arr ],
                    as => [qw/gid  wkt_transform /],
                },
                );
        };
        if ($EVAL_ERROR) {    # find or create failed
            carp "can't fetch transform $EVAL_ERROR";
            croak;
        }
        # carp 'got a transform';
        # carp $transform;
        # carp $transform->get_column('wkt_transform');
        my $projectedpoint;
        $test_eval = eval {
            my $arr = [
                q{ST_GeometryFromText(?,4326)},
                ['dummy'=>$transform->get_column('wkt_transform')]
                ];
            $projectedpoint = $self->resultset('Public::GeomPoints4326')->create(
                {
                    gid  => $gid4326,
                    geom => \$arr,
                }
                );
	};
        if ($EVAL_ERROR) {    # find or create failed
            carp "can't create new tranformed geometry $EVAL_ERROR";
            croak;
        }
        return $projectedpoint;
    }

    method join_geom($vds,$gid,$projection){
        # carp "test projection of $projection";
        if($projection != 4269 && $projection != 4326){
            croak "unknown projection $projection";
        }
        # carp "joining vds to point $projection";
        my $table = 'Public::VdsPoints' . $projection;
        my $join;
        my $test_eval = eval {
            ($join) =
                $self->resultset($table)->search( { 'vds_id' => $vds->id, } );
        };
        if ($EVAL_ERROR) {    # find or create failed
            carp "can't search for joins $EVAL_ERROR";
            croak;
        }
        # carp 'did not crash searching for join';
        if ( !$join ) {
            # carp 'need to create new join';
            $test_eval = eval {
                $join = $self->resultset($table)->create(
                    {
                        'gid'    => $gid,
                        'vds_id' => $vds->id,
                    }
                    );
            };
            if ($EVAL_ERROR) {    # find or create failed
                carp "can't create new join $EVAL_ERROR";
                croak;
            }

        }
        else {
            # have an existing join.  Update with new gid
            $join->gid($gid);
            $join->update();
        }
        return;
    }

    method _build_geometry_gen_code{
        my $coderef = sub {
            my ( $vds, $lat, $lon ) = @_;

            # carp "$vds is    ", join "\n  ",
            map { join q{;}, "$_", $vds->$_ } (qw/id name latitude longitude/);

            # correct the vds data
            #     carp join q{ }, 'vds correction: id is ', $vds->id, $vds->longitude, 'to',
            #       $lon, '  and ', $vds->latitude, 'to', $lat,;

            if ($lon) {
                $vds->longitude($lon);
            }
            if ($lat) {
                $vds->latitude($lat);
            }
            $vds->update;
            $lon = $vds->longitude;
            $lat = $vds->latitude;

            if(!$lat || !$lon){
                return $vds;
            }
            # carp "$vds is    ", join "\n  ",
            # map { join q{;}, "$_", $vds->$_ } (qw/id name latitude longitude/);

            # get a new geometry id from the db
            my $new_geoid = $self->get_new_geoid;

            # use the new id to create 4269 (unprojected) geometry from lat lon data
            my $gid        = $new_geoid->gid;
            my $creategeom = $self->create_geompoint_4269($lon,$lat,$gid);

            ## join that with the current vds object
            # carp 'join with vds';
            $self->join_geom($vds,$gid,4269);
            # carp 'transform 4269 to 4324';
            # create a new, projected point to 4326 projection

            # transform the geometry
            # create a gid for the 4326 projection
            $new_geoid = $self->get_new_geoid();
            my $projectedgid        = $new_geoid->gid;
            ## and the actual point

            my $projectedpoint = $self->project_geom_4326($gid,$projectedgid);

            $self->join_geom($vds,$projectedgid,4326);

            # carp 'updated vds_points_4326   and _4269  tables';
            return $vds;
        };
        return $coderef;
    }


    method _build_inner_loop_method {

        return sub {}
    }
    method parse_file($fh,$filedate){
        my $csv = $self->csv;
        #burn the first line
        $csv->getline($fh);
        my $linenum = 1;
        my $data;
        while ( $data = $csv->getline_hr($fh)) {
            $linenum++;
            #good read.
            # tack on filedate as version information
            $data->{'version'} = $filedate;
            my $pk = $data->{'vdsid'};
            # carp "$linenum, $pk";

            # make join tables
            if ( !$self->dbload($data) ) {
                carp 'problem with line', Dumper $data;
                my $err = $csv->error_input;
                carp "parse () failed on argument:  $err \n";
                $csv->error_diag();

            }

        }
        # carp "returning";
        #my $err = $self->csv->error_input;
        #carp "parse () failed on argument:  $err \n";
        # carp Dumper $self->csv->error_diag();

        # carp Dumper $data;

        return;
    }

    method _build__connection_psql {
        # carp 'building connection';
        my ( $host, $port, $dbname, $username, $password ) =
            map { $self->$_ }
        map { join q{_}, $_, $param }
        qw/ host port dbname username password /;
        my $vdb = Testbed::Spatial::VDS::Schema->connect(
            "dbi:Pg:dbname=$dbname;host=$host;port=$port",
            $username, $password, {}, { 'disable_sth_caching' => 1 } );
        return $vdb;
    }

    with 'DB::Connection' => {
        'name'                  => 'psql',
        'connection_type'       => 'Testbed::Spatial::VDS::Schema',
        'connection_delegation' => qr/^(.*)/sxm,
    };

    method guess_date($filename){

        my $strp = DateTime::Format::Strptime->new(
            pattern   => '%Y-%m-%d',
            );

        if ( $filename =~ /(\d{4})_(\d{2})_(\d{2})/sxm ) {
            my $dt = $strp->parse_datetime("$1-$2-$3");
            return DateTime::Format::Pg->format_date($dt);
        }
        return ;
    }

    method create_geometries ($vds) {

        # geometry
        my $rs;
        my $test = eval { $rs = $self->txn_do( $self->geometry_gen_code, $vds ); };
        if ( !$test || $EVAL_ERROR ) {    # Transaction failed
            if ( $EVAL_ERROR =~ /Rollback failed/xms ) {
                croak q{rollback failed ... the sky is falling!};  # Rollback failed
            }
            deal_with_failed_transaction( $vds, $EVAL_ERROR );
        }

        return;
    }

    method trim_ca_pm ($value){
        # trim overly long state_pm values, because varchar(12) in db
        if($value =~ /(\D*)(.+)/g){
            my $reformed = $1 . sprintf("%.3f",$2);
            # truncate any excess zeros at the end
            $reformed =~ s/0*$//;
            $value =  $reformed;
        }
        return $value;

    }

    method get_vds_or_die(Int $pk, HashRef $data){
        # carp "get vds or die";
        # carp $self;
        # carp "pk is $pk";
        # carp "data is $data";

        my $vds;
        my $test_eval = eval {
            my $rs = $self->resultset('Public::VdsIdAll');
            $vds = $rs->find($pk);
        };
        if ($EVAL_ERROR) {    # find or create failed
            # carp "find vds failed, test_eval= $test_eval, error= $EVAL_ERROR";
            # carp 'input data is ',     Dumper($data);
            #croak;
        }
        # at the moment, this won't trigger because I croak above
        if ( !$vds ) {
            # carp 'going to build a new vds id';
            my $detectorname   = $data->{'name'} || $data->{'user_id_1'} || $data->{'user_id_2'} || $data->{'user_id_3'} || $data->{'user_id_4'};
            my $attrs = {
                'id'     => $pk,
                'name'   => $detectorname,
                'cal_pm' => $self->trim_ca_pm($data->{'state_pm'}),
                'abs_pm' => $data->{'abs_pm'},
            };


            $test_eval =
                eval {
                    $vds = $self->resultset('Public::VdsIdAll')
                        ->create($attrs);
            };
            if ( !$test_eval || $EVAL_ERROR ) {    # find or create failed
                carp 'create failed failed, ', $EVAL_ERROR;
                carp 'input data is ',                 Dumper($data);
                carp 'attrs hash is ',                 Dumper($attrs);
                croak;
            }
        }
        return $vds
    }

    method check_geometries (HashRef $geo, Ref $vds){
        my $dogeom = 0;
        if (   ( $geo->{'latitude'} && $geo->{'longitude'} )
               && ( !$vds->latitude || !$vds->longitude ) )
        {
            # carp 'must update geometries';
            $dogeom = 1;
        }else{
            # carp "check geometries step 2";

            my $rs  = $vds->vds_points_4269;
            #   $test_eval =
            #       eval {     $rs  = $vds->vds_points_4269; };
            # if ( !$test_eval || $EVAL_ERROR ) {    # find or create failed
            #     carp 'failed getting a link to vds_points_4269!, ', $EVAL_ERROR;
            #     carp $test_eval;
            #     croak;
            # }
            if(!$rs){
                # carp 'must update geometries';
                $dogeom=1;
            } else {
                # carp "check geometries step 4";
                $rs       = $vds->vds_points_4326();
                if ( !$rs ) {
                    # carp 'must update geometries';
                    $dogeom=1;
                }
            }
        }
        return $dogeom;

    }

    method update_versioned_table(HashRef $data){
        # now update the versioned table
        my $attrs = {
            'id'      => $data->{'vdsid'},
            'lanes'   => $data->{'lanes'},
            'version' => $data->{'version'},
        };

        if ( $data->{'length'} && $data->{'length'} ne q{} ) {
            $attrs->{'segment_length'} = $data->{'length'};
        }

        # carp "find is stupid, create is king";
        # find is stupid.  create is king
        my $vds_versioned;
        my $test_eval = eval {
            $vds_versioned =
                $self->resultset('Public::VdsVersioned')->find_or_create($attrs);
        };

        if ( !$test_eval || $EVAL_ERROR ) {    # find or create failed
            carp 'create failed for vds_versioned, ', $EVAL_ERROR;
            carp 'input data is ',                    Dumper($data);
            carp 'attrs hash is ',                    Dumper($attrs);
            croak;
        }
        return;
    }


    method dbload (HashRef $data){


        my $pk = 0+$data->{'vdsid'};
        if ( !$pk ) { return; }

        # carp Dumper $pk;

        my $vds = $self->get_vds_or_die($pk,$data);
        # carp $vds->id;

        # any of these might have changed
        my $detectorname   = $data->{'name'} || $data->{'user_id_1'} || $data->{'user_id_2'} || $data->{'user_id_3'} || $data->{'user_id_4'};

        my $attrs = {
            'id'     => $pk,
            'name'   => $detectorname,
            'cal_pm' => $self->trim_ca_pm($data->{'state_pm'}),
            'abs_pm' => $data->{'abs_pm'},
        };
        # carp $attrs;
        my $geo = {};
        if ( $data->{'latitude'} && $data->{'latitude'} ne q{} ) {
            $geo->{'latitude'} = $data->{'latitude'};
        }
        if ( $data->{'longitude'} && $data->{'longitude'} ne q{} ) {
            $geo->{'longitude'} = $data->{'longitude'};
        }

        # carp "check geometries";
        # check geometries for need for update
        my $dogeom = $self->check_geometries($geo,$vds);


        # carp "slurp keys";
        # copy attributes from $attrs to the $vds object
        foreach ( keys %{$attrs} ) {
            $vds->$_( $attrs->{$_} );
        }
        # carp "slurp geo";
        if ($geo) {
            foreach ( keys %{$geo} ) {
                $vds->$_( $geo->{$_} );
            }
            $vds->update();
        }

        # carp "version table stuff";
        $self->update_versioned_table($data);

        ##################################################
        # make various joins
        ##################################################

        # carp "making joins districtjoin";
        my $districtjoin = $self->resultset('Public::VdsDistrict')->find_or_create(
            {
                'district_id' => $data->{'district'},
                'vds_id'      => $vds->id,
            }
            );
        # carp "making joins vdstypejoin";
        $self->vdstypejoin($data,$vds);

        # carp "making joins freewayjoin";
        $self->freewayjoin($data,$vds);

        # carp "update geometries?";

        if ($dogeom) {
            # carp 'updating geometries';
            $self->create_geometries($vds);
        }
        # carp 'returning';
        return $vds;
    }

    method  deal_with_failed_transaction {
        carp 'The transaction failed for some reason, probably missing lat or lon';
        croak $EVAL_ERROR;
    }

    method freewayjoin (HashRef $data, Ref $vds){
        my $freeway     = $self->fetch_freeway($data->{'fwy'});
        eval{
            my $freewayjoin = $self->resultset('Public::VdsFreeway')->find_or_create(
                {
                    'freeway_id'  => $freeway->id,
                    'freeway_dir' => $data->{'dir'},
                    'vds_id'      => $vds->id,
                }
                );
        };
        if ( $EVAL_ERROR ) {    # find or create failed
            carp 'create failed for freewayjoin, ', $EVAL_ERROR;
            croak;
        }
        return;

    }

    method fetch_freeway ($freewayid) {

        my $freeway = $self->resultset('Public::Freeway')->find_or_create(
            {
                'name' => $freewayid,
                'id'   => $freewayid,
            }
            );
        return $freeway;
    }

    method vdstypejoin (HashRef $data, Ref $vds){
        # carp 'vdstypejon';
        my $vdstype     = $self->fetch_vdstype($data->{'type'});
        my $vdstypejoin;
        my $test_eval = eval {
            $vdstypejoin  = $self->resultset('Public::VdsVdstype')->find_or_create(
                {
                    'type_id' => $vdstype->id,
                    'vds_id'  => $vds->id,
                }
                );
        };
        if ( !$test_eval || $EVAL_ERROR ) {    # find or create failed
            carp 'create failed for vdstypjoin, ', $EVAL_ERROR;
            croak;
        }
        return;
    }

    method fetch_vdstype ($type) {
        my $vdstype;
        # carp 'fetch_vdstype';
        my $test_eval = eval {
            $vdstype  =
                $self->resultset('Public::Vdstype')->find( { 'id' => $type, } );
        };
        if ( !$test_eval || $EVAL_ERROR ) {    # find or create failed
            carp 'find failed for vdstype $type: ', $EVAL_ERROR;
            croak;
        }
        return $vdstype;
    }


}
1;
