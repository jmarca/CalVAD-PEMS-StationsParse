alter    TABLE "accident_risk_results" alter column vds_id type bigint;


drop view vds_geoview_full;
drop view vds_current_view_grails;
drop view  vds_2007data_geoview;

drop view vds_current_ordered;
drop view distinctfacilities;
drop view vds_current_view ;

drop view  annual_mainline_volumes;
alter    TABLE "vds_freeway"  alter column vds_id type bigint;


alter    TABLE "vds_haspems5min" alter column vds_id type bigint;


alter    TABLE "vds_points_4269" alter column vds_id type bigint;

drop view vds_geoview;

alter    TABLE "vds_points_4326" alter column vds_id type bigint;

alter    TABLE "vds_stats"  alter column vds_id type bigint;

alter    TABLE "vds_summarystats" alter column vds_id type bigint;

alter    TABLE "vds_taz_intersections_alt" alter column vds_id type bigint;

alter    TABLE "vds_taz_intersections_simple" alter column vds_id type bigint;

alter    TABLE "vds_taz_intersections" alter column vds_id type bigint;

alter    TABLE "vds_wim_distance" alter column vds_id type bigint;

drop view pems_raw_test2_full;

alter    TABLE "vds_versioned" alter column id type bigint;


drop view pems.vds_has_data_yr_view;

alter    TABLE pems.vds_aggregate_hr_observed alter column vds_id type bigint;


alter    TABLE imputed.vds_wim_neighbors alter column vds_id type bigint;

alter    TABLE imputed.vds_wim_pairs alter column vds_id type bigint;

alter    TABLE vds_id_all alter column id type bigint;
