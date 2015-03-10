--


pg_dump -s \
        -t public.freeways \
        -t public.geom_ids \
        -t public.geom_points_4269 \
        -t public.geom_points_4326 \
        -t public.vds_district \
        -t public.vds_id_all \
        -t public.vds_freeway \
        -t public.vds_points_4269 \
        -t public.vds_points_4326 \
        -t public.vds_vdstype \
        -t public.vds_versioned \
        -t public.vdstypes \
        -U slash -h 192.168.0.1 spatialvds > ct.sql
