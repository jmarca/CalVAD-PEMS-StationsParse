
package CalVAD::PEMS;

use Moops;
# ABSTRACT: Breaks up the daily all-vds-per-district files into yearly per vds files

class Breakup using Moose : ro {

    use Carp;
    use Data::Dumper;
    use File::Path qw(make_path);
    use Testbed::Spatial::VDS::Schema;
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

    method _build_csv {
        # set up the csv parser
        my $csv = Text::CSV->new( { 'sep_char' => "\t",
                                    'allow_loose_quotes'=>1,
                                  } );

        # bind variables to lines
        $csv->column_names(
            qw{vdsid fwy dir district county city state_pm abs_pm latitude longitude length type lanes name user_id_1 user_id_2 user_id_3 user_id_4}
            );
        return $csv;
    }



    sub _build_inner_loop_method {

        my $slurpcode = sub {
            my ($fh,$filedate) = @_;
            #burn the first line
            $self->csv->getline_hr($fh);
            my $linenum = 1;
            my $data;
            while ( $data = $self->csv->getline_hr($fh)) {
                $linenum++;
                #good read.
                # tack on filedate as version information
                $data->{'version'} = $filedate;
                my $pk = $data->{'vdsid'};
                # carp "$linenum, $pk";

                # make join tables
                if ( !dbload($data) ) {
                    carp 'problem with line', Dumper $data;
                    my $err = $self->csv->error_input;
                    carp "parse () failed on argument:  $err \n";
                    $self->csv->error_diag();

                }

            }
            carp "returning";
            #my $err = $self->csv->error_input;
            #carp "parse () failed on argument:  $err \n";
            carp Dumper $self->csv->error_diag();

            # carp Dumper $data;

            return;
        }
        return $slurpcode;
    }

    method create_geometries ($vds) {

        # geometry
        my $rs;
        my $test = eval { $rs = $parser->txn_do( $coderef1, $vds ); };
        if ( !$test || $EVAL_ERROR ) {    # Transaction failed
            if ( $EVAL_ERROR =~ /Rollback failed/xms ) {
                croak q{rollback failed ... the sky is falling!};  # Rollback failed
            }
            deal_with_failed_transaction( $vds, $EVAL_ERROR );
        }

        return;
    }


    ## TODO, break this into pieces

    method dbload ($data){
        my $pk = $data->{'vdsid'};

        if ( !$pk ) { return; }
        my $attrs = {
            'id'     => $data->{'vdsid'},
            'name'   => $data->{'name'},
            'cal_pm' => $data->{'state_pm'},
            'abs_pm' => $data->{'abs_pm'},
        };

        # trim overly long state_pm values, because varchar(12) in db
        if($attrs->{'cal_pm'} =~ /(\D*)(.+)/g){
            my $reformed = $1 . sprintf("%.3f",$2);
            # truncate any excess zeros at the end
            $reformed =~ s/0*$//;
            $attrs->{'cal_pm'} =  $reformed;
        }

        my $options = {};
        if ( $data->{'latitude'} && $data->{'latitude'} ne q{} ) {
            $options->{'latitude'} = $data->{'latitude'};
        }
        if ( $data->{'longitude'} && $data->{'longitude'} ne q{} ) {
            $options->{'longitude'} = $data->{'longitude'};
        }
        my $vds;
        my $test_eval = eval { $vds = $parser->resultset('VdsIdAll')->find($pk); };
        if ($EVAL_ERROR) {    # find or create failed
            carp "find vds failed, test eva $test_eval, error $EVAL_ERROR";
            carp 'input data is ',     Dumper($data);
            carp 'grabbed anything? ', $vds;
            croak;
        }
        if ( !$vds ) {
            $test_eval =
                eval { $vds = $parser->resultset('VdsIdAll')->find_or_create($attrs); };
            if ( !$test_eval || $EVAL_ERROR ) {    # find or create failed
                carp 'find or create failed failed, ', $EVAL_ERROR;
                carp 'input data is ',                 Dumper($data);
                carp 'attrs hash is ',                 Dumper($attrs);
                croak;
            }
        }
        # carp "check geometries";
        # check geometries for need for update
        my $dogeom = 0;
        if (   ( $options->{'latitude'} && $options->{'longitude'} )
               && ( !$vds->latitude || !$vds->longitude ) )
        {
            carp 'must update geometries';
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
                carp 'must update geometries';
                $dogeom=1;
            } else {
                # carp "check geometries step 4";
                $rs       = $vds->vds_points_4326();
                if ( !$rs ) {
                    carp 'must update geometries';
                    $dogeom=1;
                }
            }
        }
        # carp "slurp keys";
        foreach ( keys %{$attrs} ) {
            $vds->$_( $attrs->{$_} );
        }
        # carp "slurp options";
        if ($options) {
            foreach ( keys %{$options} ) {
                $vds->$_( $options->{$_} );
            }
            $vds->update();
        }

        # carp "version table stuff";

        # now update the versioned table
        $attrs = {
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
        $test_eval = eval {
            $vds_versioned =
                $parser->resultset('VdsVersioned')->find_or_create($attrs);
        };
        if ( !$test_eval || $EVAL_ERROR ) {    # find or create failed
            carp 'create failed for vds_versioned, ', $EVAL_ERROR;
            carp 'input data is ',                    Dumper($data);
            carp 'attrs hash is ',                    Dumper($attrs);
            croak;
        }

        # carp "making joins districtjoin";
        # make various joins
        my $districtjoin = $parser->resultset('VdsDistrict')->find_or_create(
            {
                'district_id' => $data->{'district'},
                'vds_id'      => $vds->id,
            }
            );
        # carp "making joins vdstypejoin";
        my $vdstype     = fetch_vdstype($data);
        my $vdstypejoin;
        $test_eval = eval {
            $vdstypejoin  = $parser->resultset('VdsVdstype')->find_or_create(
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

        # carp "making joins freewayjoin";
        my $freeway     = fetch_freeway($data);
        my $freewayjoin = $parser->resultset('VdsFreeway')->find_or_create(
            {
                'freeway_id'  => $freeway->id,
                'freeway_dir' => $data->{'dir'},
                'vds_id'      => $vds->id,
            }
            );

        # carp "update geometries?";

        if ($dogeom) {
            carp 'updating geometries';
            $self->create_geometries($vds);
        }
        # carp 'returning';
        return $vds;
    }

    method  deal_with_failed_transaction {
        carp 'The transaction failed for some reason, probably missing lat or lon';
        croak $EVAL_ERROR;
    }

    method fetch_freeway ($freeway) {

        my $freeway = $parser->resultset('Freeway')->find_or_create(
            {
                'name' => $freeway,
                'id'   => $freeway,
            }
            );
        return $freeway;
    }

    method fetch_vdstype ($type) {
        my $vdstype;

        my $test_eval = eval {
            $vdstype  =
                $parser->resultset('Vdstype')->find( { 'id' => $type, } );
        };
        if ( !$test_eval || $EVAL_ERROR ) {    # find or create failed
            carp 'create failed for vdstypjoin, ', $EVAL_ERROR;
            croak;
        }
        return $vdstype;
    }

    my $coderef1 = sub {
        my ( $vds, $lat, $lon ) = @_;

        carp "$vds is    ", join "\n  ",
        map { join q{;}, "$_", $vds->$_ } (qw/id name latitude longitude/);

        # correct the vds data
        #     carp join q{ }, 'vds correction: id is ', $vds->id, $vds->longitude, 'to',
        #       $lon, '  and ', $vds->latitude, 'to', $lat,;

        if ($lon) {
            $vds->longitude($lon);
        }
        else {
            $lon = $vds->longitude;
        }
        if ($lat) {
            $vds->latitude($lat);
        }
        else {
            $lat = $vds->latitude;
        }
        $vds->update;

        if(!$lat || !$lon){
            return $vds;
        }
        carp "$vds is    ", join "\n  ",
        map { join q{;}, "$_", $vds->$_ } (qw/id name latitude longitude/);
        my $new_geoid;
        my $test_eval = eval { $new_geoid = $parser->resultset('GeomId')->create( { 'dummy' => 1 } ); };
        if ($EVAL_ERROR) {    # find or create failed
            carp "can't create new geomid $EVAL_ERROR";
            croak;
        }


        # use the new id to create 4269 (unprojected) geometry from lat lon data
        # GeometryFromText('POINT("+lon+" "+lat+")',"+SRID+")
        my $geomfn = join q{}, 'POINT(', $lon, q{ }, $lat, q{)};

        carp "geometry function is $geomfn, new geoid is ", $new_geoid->gid;
        my $gid        = $new_geoid->gid;
        my $creategeom;
        $test_eval = eval {
            $creategeom = $parser->resultset('GeomPoints4269')->create(
                {
                    gid  => $gid,
                    geom => \[ q/GeometryFromText(?,4269)/, ['dummy'=>$geomfn] ],
                }
        );
    };
    if ($EVAL_ERROR) {    # find or create failed
        carp "can't create new geometry $EVAL_ERROR";
        croak;
    }

    carp 'created new geom_points_4269 entry';
    my $join;
    $test_eval = eval {
        ($join) =
            $parser->resultset('VdsPoints4269')->search( { 'vds_id' => $vds->id, } );
    };
    if ($EVAL_ERROR) {    # find or create failed
        carp "can't search for joins $EVAL_ERROR";
        croak;
    }

    if ( !$join ) {
        carp 'need to create new join';
        $test_eval = eval {
            $join = $parser->resultset('VdsPoints4269')->create(
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
        $join->gid($gid);
        $join->update();
    }

    carp 'now reproject the 4269 to 4326';

    #

    # transform the geometry
    # create a gid for the 4326 projection
    $test_eval = eval {
        $new_geoid = $parser->resultset('GeomId')->create( { 'dummy' => 1 } );
    };
    if ($EVAL_ERROR) {    # find or create failed
        carp "can't create new geomids $EVAL_ERROR";
        croak;
    }

    my $transform;
    $test_eval = eval {
        ($transform) = $parser->resultset('GeomPoints4269')->search(
            { 'gid' => $gid },
            {
                select => [ 'gid', \[q/AsText(Transform(me.geom,4326))/] ],
            as => [qw/gid  wkt_transform /],
            },
    );
};
if ($EVAL_ERROR) {    # find or create failed
    carp "can't create new join $EVAL_ERROR";
    croak;
}
carp 'got a transform';
my $projectedpoint;
$test_eval = eval {
    $projectedpoint = $parser->resultset('GeomPoints4326')->create(
        {
            gid  => $new_geoid->gid,
            geom => \[
                q{GeometryFromText(?,4326)},
                ['dummy'=>$transform->get_column('wkt_transform')]
        ],
        }
);
};
if ($EVAL_ERROR) {    # find or create failed
    carp "can't create new tranformed geometry $EVAL_ERROR";
croak;
}

$test_eval = eval {
    ($join) =
    $parser->resultset('VdsPoints4326')->search( { 'vds_id' => $vds->id, } );
};
if ($EVAL_ERROR) {    # find or create failed
    carp "can't create new join $EVAL_ERROR";
croak;
}
if ( !$join ) {
    $join = $parser->resultset('VdsPoints4326')->create(
        {
            'gid'    => $new_geoid->gid,
            'vds_id' => $vds->id,
        }
    );
}
else {
    $join->gid($projectedpoint);
$join->update();
}
carp 'updated vds_points_4326   and _4269  tables';
return $vds;
};


}
1;
