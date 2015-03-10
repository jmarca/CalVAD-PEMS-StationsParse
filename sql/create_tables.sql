--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: geom_points_4326; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE geom_points_4326 (
    gid integer NOT NULL,
    geom geometry,
    CONSTRAINT enforce_dims_geom CHECK ((st_ndims(geom) = 2)),
    CONSTRAINT enforce_geotype_geom CHECK (((geometrytype(geom) = 'POINT'::text) OR (geom IS NULL))),
    CONSTRAINT enforce_srid_geom CHECK ((st_srid(geom) = 4326))
);


--
-- Name: vds_district; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE vds_district (
    vds_id bigint NOT NULL,
    district_id integer NOT NULL
);


--
-- Name: vds_freeway; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE vds_freeway (
    vds_id bigint NOT NULL,
    freeway_id integer NOT NULL,
    freeway_dir character varying(2)
);


--
-- Name: vds_id_all; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE vds_id_all (
    id bigint NOT NULL,
    name character varying(64) NOT NULL,
    cal_pm character varying(12) NOT NULL,
    abs_pm double precision NOT NULL,
    latitude numeric,
    longitude numeric
);


--
-- Name: vds_points_4326; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE vds_points_4326 (
    gid integer NOT NULL,
    vds_id bigint NOT NULL
);


--
-- Name: vds_vdstype; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE vds_vdstype (
    vds_id bigint NOT NULL,
    type_id character varying(4) NOT NULL
);


--
-- Name: vds_versioned; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE vds_versioned (
    id bigint NOT NULL,
    lanes integer NOT NULL,
    segment_length numeric,
    version date NOT NULL
);


--
-- Name: freeways; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE freeways (
    id integer NOT NULL,
    name character varying(64)
);


--
-- Name: geom_ids; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE geom_ids (
    gid integer NOT NULL,
    dummy integer
);


--
-- Name: geom_ids_gid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE geom_ids_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: geom_ids_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE geom_ids_gid_seq OWNED BY geom_ids.gid;


--
-- Name: geom_points_4269; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE geom_points_4269 (
    gid integer NOT NULL,
    geom geometry,
    CONSTRAINT enforce_dims_geom CHECK ((st_ndims(geom) = 2)),
    CONSTRAINT enforce_geotype_geom CHECK (((geometrytype(geom) = 'POINT'::text) OR (geom IS NULL))),
    CONSTRAINT enforce_srid_geom CHECK ((st_srid(geom) = 4269))
);


--
-- Name: vds_points_4269; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE vds_points_4269 (
    gid integer NOT NULL,
    vds_id bigint NOT NULL
);


--
-- Name: vdstypes; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE vdstypes (
    id character varying(4) NOT NULL,
    description character varying(64) NOT NULL
);


--
-- Name: gid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY geom_ids ALTER COLUMN gid SET DEFAULT nextval('geom_ids_gid_seq'::regclass);


--
-- Name: freeways_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY freeways
    ADD CONSTRAINT freeways_pkey PRIMARY KEY (id);


--
-- Name: geom_ids_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY geom_ids
    ADD CONSTRAINT geom_ids_pkey PRIMARY KEY (gid);


--
-- Name: geom_points_4269_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY geom_points_4269
    ADD CONSTRAINT geom_points_4269_pkey PRIMARY KEY (gid);


--
-- Name: geom_points_4326_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY geom_points_4326
    ADD CONSTRAINT geom_points_4326_pkey PRIMARY KEY (gid);


--
-- Name: vds_district_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY vds_district
    ADD CONSTRAINT vds_district_pkey PRIMARY KEY (vds_id);


--
-- Name: vds_freeway_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY vds_freeway
    ADD CONSTRAINT vds_freeway_pkey PRIMARY KEY (vds_id);


--
-- Name: vds_id_all_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY vds_id_all
    ADD CONSTRAINT vds_id_all_pkey PRIMARY KEY (id);


--
-- Name: vds_points_4269_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY vds_points_4269
    ADD CONSTRAINT vds_points_4269_pkey PRIMARY KEY (vds_id);


--
-- Name: vds_points_4326_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY vds_points_4326
    ADD CONSTRAINT vds_points_4326_pkey PRIMARY KEY (vds_id);


--
-- Name: vds_vdstype_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY vds_vdstype
    ADD CONSTRAINT vds_vdstype_pkey PRIMARY KEY (vds_id);


--
-- Name: vds_versioned_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY vds_versioned
    ADD CONSTRAINT vds_versioned_pkey PRIMARY KEY (id, version);


--
-- Name: vdstypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY vdstypes
    ADD CONSTRAINT vdstypes_pkey PRIMARY KEY (id);


--
-- Name: geom_points_4269_geom_index; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX geom_points_4269_geom_index ON geom_points_4269 USING gist (geom);


--
-- Name: geom_points_4326_geom_index; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX geom_points_4326_geom_index ON geom_points_4326 USING gist (geom);


--
-- Name: vds_district_district_idx; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX vds_district_district_idx ON vds_district USING btree (district_id);


--
-- Name: vds_points_4326_gid_index; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX vds_points_4326_gid_index ON vds_points_4326 USING btree (gid);


--
-- Name: vds_versioned_version_idx; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX vds_versioned_version_idx ON vds_versioned USING btree (version);


--
-- Name: geom_points_4269_gid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY geom_points_4269
    ADD CONSTRAINT geom_points_4269_gid_fkey FOREIGN KEY (gid) REFERENCES geom_ids(gid) ON DELETE CASCADE;


--
-- Name: geom_points_4326_gid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY geom_points_4326
    ADD CONSTRAINT geom_points_4326_gid_fkey FOREIGN KEY (gid) REFERENCES geom_ids(gid) ON DELETE CASCADE;


--
-- Name: vds_freeway_vds_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY vds_freeway
    ADD CONSTRAINT vds_freeway_vds_id_fkey FOREIGN KEY (vds_id) REFERENCES vds_id_all(id);


--
-- Name: vds_points_4269_gid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY vds_points_4269
    ADD CONSTRAINT vds_points_4269_gid_fkey FOREIGN KEY (gid) REFERENCES geom_points_4269(gid) ON DELETE CASCADE;


--
-- Name: vds_points_4269_vds_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY vds_points_4269
    ADD CONSTRAINT vds_points_4269_vds_id_fkey FOREIGN KEY (vds_id) REFERENCES vds_id_all(id);


--
-- Name: vds_points_4326_gid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY vds_points_4326
    ADD CONSTRAINT vds_points_4326_gid_fkey FOREIGN KEY (gid) REFERENCES geom_points_4326(gid) ON DELETE CASCADE;


--
-- Name: vds_points_4326_vds_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY vds_points_4326
    ADD CONSTRAINT vds_points_4326_vds_id_fkey FOREIGN KEY (vds_id) REFERENCES vds_id_all(id);


--
-- Name: vds_versioned_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY vds_versioned
    ADD CONSTRAINT vds_versioned_id_fkey FOREIGN KEY (id) REFERENCES vds_id_all(id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--
