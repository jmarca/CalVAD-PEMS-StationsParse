vds_district

vds_freeway

vds_id_all

vds_points_4269

vds_points_4326

vds_vdstype

vds_versioned


                  List of relations
 Schema |             Name             | Type  | Owner
--------+------------------------------+-------+-------
 public | vds30second_raw_versioned    | table | slash
 public | vds_city                     | table | slash
 public | vds_complete                 | table | slash
 public | vds_county                   | table | slash
 public | vds_current_test             | table | slash
 public | vds_district                 | table | slash
 public | vds_freeway                  | table | slash
 public | vds_geom_2230                | table | slash
 public | vds_haspems5min              | table | slash
 public | vds_id_all                   | table | slash
 public | vds_points_4269              | table | slash
 public | vds_points_4326              | table | slash
 public | vds_route_relation           | table | slash
 public | vds_sed_2000_e_or            | table | slash
 public | vds_sed_2000_n_or            | table | slash
 public | vds_sed_2000_n_or_alt        | table | slash
 public | vds_sed_2000_or              | table | slash
 public | vds_sed_2000_or_alt          | table | slash
 public | vds_sed_2000_s_or            | table | slash
 public | vds_sed_2000_simple_or       | table | slash
 public | vds_sed_2000_w_or            | table | slash
 public | vds_segment_geometry         | table | slash
 public | vds_stats                    | table | slash
 public | vds_summarystats             | table | slash
 public | vds_taz_intersections        | table | slash
 public | vds_taz_intersections_alt    | table | slash
 public | vds_taz_intersections_simple | table | slash
 public | vds_vdstype                  | table | slash
 public | vds_versioned                | table | slash
 public | vds_wim_distance             | table | slash
 public | vdstypes                     | table | slash

-- vds_id_all is Referenced by:


alter    TABLE "accident_risk_results" alter column vds_id type bigint;
alter    TABLE "vds_freeway"  alter column vds_id type bigint;
alter    TABLE "vds_haspems5min" alter column vds_id type bigint;
alter    TABLE "vds_points_4269" alter column vds_id type bigint;
alter    TABLE "vds_points_4326" alter column vds_id type bigint;
alter    TABLE "vds_stats"  alter column vds_id type bigint;
alter    TABLE "vds_summarystats" alter column vds_id type bigint;
alter    TABLE "vds_taz_intersections_alt" alter column vds_id type bigint;
alter    TABLE "vds_taz_intersections_simple" alter column vds_id type bigint;
alter    TABLE "vds_taz_intersections" alter column vds_id type bigint;
alter    TABLE "vds_wim_distance" alter column vds_id type bigint;

alter    TABLE "vds_versioned" alter column id type bigint;

alter    TABLE pems.vds_aggregate_hr_observed alter column vds_id type bigint;

alter    TABLE imputed.vds_wim_neighbors alter column vds_id type bigint;

alter    TABLE imputed.vds_wim_pairs alter column vds_id type bigint;

alter    TABLE vds_id_all alter column id type bigint;


Referenced by:
    TABLE "accident_risk_results" CONSTRAINT "accident_risk_results_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id) ON DELETE CASCADE
    TABLE "pems.vds_aggregate_hr_observed" CONSTRAINT "vds_aggregate_hr_observed_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id) ON DELETE CASCADE
    TABLE "vds_freeway" CONSTRAINT "vds_freeway_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id)
    TABLE "vds_haspems5min" CONSTRAINT "vds_haspems5min_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id) ON DELETE CASCADE
    TABLE "vds_points_4269" CONSTRAINT "vds_points_4269_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id)
    TABLE "vds_points_4326" CONSTRAINT "vds_points_4326_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id)
    TABLE "vds_stats" CONSTRAINT "vds_stats_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id) ON DELETE CASCADE
    TABLE "vds_summarystats" CONSTRAINT "vds_summarystats_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id) ON DELETE CASCADE
    TABLE "vds_taz_intersections_alt" CONSTRAINT "vds_taz_intersections_alt_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id) ON DELETE CASCADE
    TABLE "vds_taz_intersections_simple" CONSTRAINT "vds_taz_intersections_simple_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id) ON DELETE CASCADE
    TABLE "vds_taz_intersections" CONSTRAINT "vds_taz_intersections_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id) ON DELETE CASCADE
    TABLE "vds_versioned" CONSTRAINT "vds_versioned_id_fkey" FOREIGN KEY (id) REFERENCES vds_id_all(id) ON DELETE RESTRICT
    TABLE "vds_wim_distance" CONSTRAINT "vds_wim_distance_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id) ON DELETE CASCADE
    TABLE "imputed.vds_wim_neighbors" CONSTRAINT "vds_wim_neighbors_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id) ON DELETE CASCADE
    TABLE "imputed.vds_wim_pairs" CONSTRAINT "vds_wim_pairs_vds_id_fkey" FOREIGN KEY (vds_id) REFERENCES vds_id_all(id) ON DELETE CASCADE




-- vds_geoview

 WITH latest AS (
         SELECT vds_versioned.id,
            max(vds_versioned.version) AS version
           FROM vds_versioned
          GROUP BY vds_versioned.id
          ORDER BY vds_versioned.id
        )
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
   JOIN vds_points_4326 ON v.id = vds_points_4326.vds_id
   JOIN latest USING (id)
   JOIN vds_versioned vv ON vv.id = v.id AND vv.version = latest.version
   JOIN vds_vdstype vt USING (vds_id)
   JOIN vds_district vd USING (vds_id)
   JOIN vds_freeway vf USING (vds_id)
   JOIN geom_points_4326 g USING (gid);


-- vds_active
 WITH in_out AS (
         SELECT v_1.id,
            min(v_1.version) AS deployed,
            max(v_1.version) AS latest,
            d.district_id AS district
           FROM vds_versioned v_1
      JOIN vds_district d ON v_1.id = d.vds_id
     GROUP BY v_1.id, d.district_id
        ), in_out_details AS (
         SELECT i.id,
            i.deployed,
            i.latest,
            i.district,
            vvd.lanes AS deployed_lanes,
            vvd.segment_length AS deployed_length,
            vvr.segment_length AS latest_length,
            vvd.lanes AS latest_lanes
           FROM in_out i
      JOIN vds_versioned vvd ON i.id = vvd.id AND i.deployed = vvd.version
   JOIN vds_versioned vvr ON i.id = vvr.id AND i.latest = vvr.version
        ), district_updates AS (
         SELECT DISTINCT vds_district.district_id AS district,
            max(vds_versioned.version) AS version
           FROM vds_versioned
      JOIN vds_district ON vds_versioned.id = vds_district.vds_id
     GROUP BY vds_district.district_id
        ), service_history AS (
         SELECT l.id,
            l.deployed,
            d.version AS latest_update,
            l.deployed_lanes,
            l.deployed_length,
            l.latest_lanes,
            l.latest_length,
            l.district
           FROM in_out_details l
      JOIN district_updates d ON l.district = d.district
     WHERE l.latest = d.version
        )
 SELECT v.id,
    v.name,
    v.cal_pm,
    v.abs_pm,
    v.latitude,
    v.longitude,
    vf.freeway_id,
    vf.freeway_dir,
    vt.type_id AS vdstype,
    s.deployed,
    s.latest_update,
    s.deployed_lanes,
    s.deployed_length,
    s.latest_lanes,
    s.latest_length,
    s.district,
    g.gid,
    g.geom,
    regexp_replace(v.cal_pm::text, '[^[:digit:]^\.]'::text, ''::text, 'g'::text)::numeric AS cal_pm_numeric
   FROM vds_id_all v
   LEFT JOIN vds_points_4326 ON v.id = vds_points_4326.vds_id
   LEFT JOIN vds_vdstype vt USING (vds_id)
   LEFT JOIN vds_freeway vf USING (vds_id)
   LEFT JOIN geom_points_4326 g USING (gid)
   JOIN service_history s USING (id)
  ORDER BY v.id;

-- pems.vds_has_data_yr_view
 SELECT t.vds_id,
    date_part('year'::text, t.ts) AS yr,
    sum(t.n) AS n,
    avg(t.o) AS o,
    avg(t.s) AS s
   FROM pems.vds_aggregate_hr_observed t
  GROUP BY t.vds_id, date_part('year'::text, t.ts);

-- vds_retired
 WITH in_out AS (
         SELECT v_1.id,
            min(v_1.version) AS deployed,
            max(v_1.version) AS latest,
            d.district_id AS district
           FROM vds_versioned v_1
      JOIN vds_district d ON v_1.id = d.vds_id
     GROUP BY v_1.id, d.district_id
        ), in_out_details AS (
         SELECT i.id,
            i.deployed,
            i.latest,
            i.district,
            vvd.lanes AS deployed_lanes,
            vvd.segment_length AS deployed_length,
            vvr.segment_length AS retired_length,
            vvd.lanes AS retired_lanes
           FROM in_out i
      JOIN vds_versioned vvd ON i.id = vvd.id AND i.deployed = vvd.version
   JOIN vds_versioned vvr ON i.id = vvr.id AND i.latest = vvr.version
        ), district_updates AS (
         SELECT DISTINCT vds_district.district_id AS district,
            vds_versioned.version
           FROM vds_versioned
      JOIN vds_district ON vds_versioned.id = vds_district.vds_id
        ), service_history AS (
         SELECT l.id,
            l.deployed,
            min(d.version) AS retired,
            l.deployed_lanes,
            l.deployed_length,
            l.retired_lanes,
            l.retired_length,
            l.district
           FROM in_out_details l
      JOIN district_updates d ON l.district = d.district
     WHERE l.latest < d.version
     GROUP BY l.id, l.deployed, l.deployed_lanes, l.deployed_length, l.retired_lanes, l.retired_length, l.district
        )
 SELECT v.id,
    v.name,
    v.cal_pm,
    v.abs_pm,
    v.latitude,
    v.longitude,
    vf.freeway_id,
    vf.freeway_dir,
    vt.type_id AS vdstype,
    s.deployed,
    s.retired,
    s.deployed_lanes,
    s.deployed_length,
    s.retired_lanes,
    s.retired_length,
    s.district,
    g.gid,
    g.geom,
    regexp_replace(v.cal_pm::text, '[^[:digit:]^\.]'::text, ''::text, 'g'::text)::numeric AS cal_pm_numeric
   FROM vds_id_all v
   LEFT JOIN vds_points_4326 ON v.id = vds_points_4326.vds_id
   LEFT JOIN vds_vdstype vt USING (vds_id)
   LEFT JOIN vds_freeway vf USING (vds_id)
   LEFT JOIN geom_points_4326 g USING (gid)
   JOIN service_history s USING (id)
  ORDER BY v.id, s.retired;


-- public | vds_current_view        | view | slash    | 0 bytes |

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

-- distinctfacilities
 SELECT DISTINCT vds_current_view.freeway_id,
    vds_current_view.freeway_dir
   FROM vds_current_view;

-- public | vds_current_ordered     | view | slash    | 0 bytes |
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


-- public | vds_current_view_grails | view | slash    | 0 bytes |
