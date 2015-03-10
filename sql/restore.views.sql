create view vds_geoview_full as
 SELECT vds_geoview.id,
    vds_geoview.name,
    vds_freeway.freeway_id,
    vds_geoview.freeway_dir,
    vds_geoview.lanes,
    vds_geoview.length,
    vds_geoview.cal_pm,
    vds_geoview.abs_pm,
    vds_geoview.latitude,
    vds_geoview.longitude,
    vds_geoview.last_modified,
    vds_geoview.gid,
    vds_geoview.geom,
    vds_vdstype.vds_id,
    vds_vdstype.type_id,
    vds_district.district_id
   FROM vds_geoview
     JOIN vds_vdstype ON vds_geoview.id = vds_vdstype.vds_id
     JOIN vds_freeway ON vds_geoview.id = vds_freeway.vds_id
     JOIN vds_district ON vds_geoview.id = vds_district.vds_id;

create view vds_current_view_grails as
 SELECT v.id,
    v.name,
    v.cal_pm,
    v.abs_pm,
    v.latitude,
    v.longitude,
    vv.lanes,
    vv.segment_length,
    vv.version AS version_ts,
    vf.freeway_id,
    vf.freeway_dir,
    vt.type_id AS vdstype,
    vd.district_id AS district,
    g.gid,
    g.geom
   FROM vds_id_all v
     JOIN vds_versioned vv USING (id)
     JOIN vds_points_4326 ON v.id = vds_points_4326.vds_id
     JOIN vds_vdstype vt USING (vds_id)
     JOIN vds_district vd USING (vds_id)
     JOIN vds_freeway vf USING (vds_id)
     JOIN geom_points_4326 g USING (gid)
     JOIN ( SELECT vds_district.district_id,
            max(vds_versioned.version) AS version
           FROM vds_versioned
             JOIN vds_district ON vds_versioned.id = vds_district.vds_id
          GROUP BY vds_district.district_id) dv ON dv.district_id = vd.district_id AND dv.version = vv.version;

create view  vds_2007data_geoview as
 SELECT vds.id,
    vds.name,
    vds_vdstype.type_id,
    vds_district.district_id,
    vds.freeway_dir,
    vds.lanes,
    vds.cal_pm,
    vds.abs_pm,
    vds.length,
    vds.latitude,
    vds.longitude,
    vds.last_modified,
    geom_points_4326.gid,
    geom_points_4326.geom
   FROM vds
     JOIN vds_haspems5min a ON vds.id = a.vds_id
     JOIN vds_points_4326 b USING (vds_id)
     JOIN geom_points_4326 USING (gid)
     JOIN vds_freeway USING (vds_id)
     JOIN vds_district USING (vds_id)
     JOIN vds_vdstype USING (vds_id);

create view vds_current_view as
 SELECT v.id,
    v.name,
    v.cal_pm,
    v.abs_pm,
    v.latitude,
    v.longitude,
    vv.lanes,
    vv.segment_length,
    vv.version,
    vf.freeway_id,
    vf.freeway_dir,
    vt.type_id AS vdstype,
    vd.district_id AS district,
    g.gid,
    g.geom,
    regexp_replace(v.cal_pm::text, '[^[:digit:]^\.]'::text, ''::text, 'g'::text)::numeric AS cal_pm_numeric
   FROM vds_id_all v
     JOIN vds_versioned vv USING (id)
     JOIN vds_points_4326 ON v.id = vds_points_4326.vds_id
     JOIN vds_vdstype vt USING (vds_id)
     JOIN vds_district vd USING (vds_id)
     JOIN vds_freeway vf USING (vds_id)
     JOIN geom_points_4326 g USING (gid)
     JOIN ( SELECT vds_district.district_id,
            max(vds_versioned.version) AS version
           FROM vds_versioned
             JOIN vds_district ON vds_versioned.id = vds_district.vds_id
          GROUP BY vds_district.district_id) dv ON dv.district_id = vd.district_id AND dv.version = vv.version;

create view vds_current_ordered as
 SELECT vds_current_view.id,
    vds_current_view.name,
    vds_current_view.cal_pm,
    vds_current_view.abs_pm,
    vds_current_view.latitude,
    vds_current_view.longitude,
    vds_current_view.lanes,
    vds_current_view.segment_length,
    vds_current_view.version,
    vds_current_view.freeway_id,
    vds_current_view.freeway_dir,
    vds_current_view.vdstype,
    vds_current_view.district,
    vds_current_view.gid,
    vds_current_view.geom,
    vds_current_view.cal_pm_numeric,
        CASE
            WHEN vds_current_view.freeway_dir::text = ANY (ARRAY['N'::character varying::text, 'E'::character varying::text]) THEN vds_current_view.abs_pm
            ELSE - vds_current_view.abs_pm
        END AS ord_pm
   FROM vds_current_view;

create view distinctfacilities as
 SELECT DISTINCT vds_current_view.freeway_id,
    vds_current_view.freeway_dir
   FROM vds_current_view;

create view  annual_mainline_volumes as
 SELECT mld.obs_year,
    mld.trucksum::double precision * vds.length::double precision AS annual_truck_vmt,
    mld.vehsum::double precision * vds.length::double precision AS annual_veh_vmt,
    b.vds_id,
    vds.name,
    vds_vdstype.type_id AS vdstype,
    vds_district.district_id AS district,
    vds_freeway.freeway_id::text || vds.freeway_dir::text AS facility,
    vds.lanes,
    vds.cal_pm,
    vds.abs_pm,
    vds.length,
    vds.latitude,
    vds.longitude,
    geom_points_4326.gid,
    geom_points_4326.geom
   FROM vds
     JOIN vds_points_4326 b ON vds.id = b.vds_id
     JOIN geom_points_4326 USING (gid)
     JOIN vds_freeway USING (vds_id)
     JOIN vds_district USING (vds_id)
     JOIN vds_vdstype USING (vds_id)
     JOIN ( SELECT detector_counts.vds_id,
            date_part('year'::text, detector_counts.obs_day) AS obs_year,
            sum(detector_counts.truckcnt) AS trucksum,
            sum(detector_counts.vehcnt) AS vehsum
           FROM detector_counts
          GROUP BY detector_counts.vds_id, date_part('year'::text, detector_counts.obs_day)) mld USING (vds_id)
  WHERE vds_vdstype.type_id::text = 'ML'::text AND mld.trucksum IS NOT NULL AND mld.trucksum > 0::double precision AND mld.vehsum IS NOT NULL AND mld.vehsum > 0::double precision;

create view vds_geoview as
 SELECT vds.id,
    vds.name,
    vds.freeway_dir,
    vds.lanes,
    vds.length,
    vds.cal_pm,
    vds.abs_pm,
    vds.latitude,
    vds.longitude,
    vds.last_modified,
    geom_points_4326.gid,
    geom_points_4326.geom
   FROM vds
     JOIN vds_points_4326 ON vds.id = vds_points_4326.vds_id
     JOIN geom_points_4326 USING (gid);

create view pems_raw_test2_full as
 SELECT q.vds_id,
    q.ts,
    q.n1,
    q.n2,
    q.n3,
    q.n4,
    q.n5,
    q.n6,
    q.n7,
    q.n8,
    q.o1,
    q.o2,
    q.o3,
    q.o4,
    q.o5,
    q.o6,
    q.o7,
    q.o8,
    q.s1,
    q.s2,
    q.s3,
    q.s4,
    q.s5,
    q.s6,
    q.s7,
    q.s8,
    q.n,
    q.o,
    q.lane_counts,
    q.lanes,
    q.segment_length,
    q.version,
    q.lane_counts::double precision / q.lanes::double precision AS pctobs
   FROM ( SELECT pems_raw_test2.vds_id,
            pems_raw_test2.ts,
            pems_raw_test2.n1,
            pems_raw_test2.n2,
            pems_raw_test2.n3,
            pems_raw_test2.n4,
            pems_raw_test2.n5,
            pems_raw_test2.n6,
            pems_raw_test2.n7,
            pems_raw_test2.n8,
            pems_raw_test2.o1,
            pems_raw_test2.o2,
            pems_raw_test2.o3,
            pems_raw_test2.o4,
            pems_raw_test2.o5,
            pems_raw_test2.o6,
            pems_raw_test2.o7,
            pems_raw_test2.o8,
            pems_raw_test2.s1,
            pems_raw_test2.s2,
            pems_raw_test2.s3,
            pems_raw_test2.s4,
            pems_raw_test2.s5,
            pems_raw_test2.s6,
            pems_raw_test2.s7,
            pems_raw_test2.s8,
            COALESCE(pems_raw_test2.n1, 0) + COALESCE(pems_raw_test2.n2, 0) + COALESCE(pems_raw_test2.n3, 0) + COALESCE(pems_raw_test2.n4, 0) + COALESCE(pems_raw_test2.n5, 0) + COALESCE(pems_raw_test2.n6, 0) + COALESCE(pems_raw_test2.n7, 0) + COALESCE(pems_raw_test2.n8, 0) AS n,
            (COALESCE(pems_raw_test2.o1, 0::numeric) + COALESCE(pems_raw_test2.o2, 0::numeric) + COALESCE(pems_raw_test2.o3, 0::numeric) + COALESCE(pems_raw_test2.o4, 0::numeric) + COALESCE(pems_raw_test2.o5, 0::numeric) + COALESCE(pems_raw_test2.o6, 0::numeric) + COALESCE(pems_raw_test2.o7, 0::numeric) + COALESCE(pems_raw_test2.o8, 0::numeric)) / vv.lanes::numeric AS o,
            COALESCE((pems_raw_test2.n1 + 1) / (pems_raw_test2.n1 + 1), 0) + COALESCE((pems_raw_test2.n2 + 1) / (pems_raw_test2.n2 + 1), 0) + COALESCE((pems_raw_test2.n3 + 1) / (pems_raw_test2.n3 + 1), 0) + COALESCE((pems_raw_test2.n4 + 1) / (pems_raw_test2.n4 + 1), 0) + COALESCE((pems_raw_test2.n5 + 1) / (pems_raw_test2.n5 + 1), 0) + COALESCE((pems_raw_test2.n6 + 1) / (pems_raw_test2.n6 + 1), 0) + COALESCE((pems_raw_test2.n7 + 1) / (pems_raw_test2.n7 + 1), 0) + COALESCE((pems_raw_test2.n8 + 1) / (pems_raw_test2.n8 + 1), 0) AS lane_counts,
            vv.lanes,
            vv.segment_length,
            vv.version
           FROM pems_raw_test2
             LEFT JOIN vds_versioned vv ON vv.id = pems_raw_test2.vds_id AND vv.version = (( SELECT vds_versioned.version
                   FROM vds_versioned
                  WHERE vds_versioned.id = pems_raw_test2.vds_id AND vds_versioned.version <= pems_raw_test2.ts
                  ORDER BY vds_versioned.version DESC
                 LIMIT 1))) q;

create view pems.vds_has_data_yr_view as
 SELECT t.vds_id,
    date_part('year'::text, t.ts) AS yr,
    sum(t.n) AS n,
    avg(t.o) AS o,
    avg(t.s) AS s
   FROM pems.vds_aggregate_hr_observed t
  GROUP BY t.vds_id, date_part('year'::text, t.ts);
