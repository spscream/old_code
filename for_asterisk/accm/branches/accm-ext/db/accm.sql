--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

DROP INDEX public.reasons_idx_id;
DROP INDEX public.queues_idx_id;
DROP INDEX public.queue_log_idx_date;
DROP INDEX public.queue_log_idx_callid;
DROP INDEX public.phones_idx_id;
DROP INDEX public.agents_idx_id;
DROP INDEX public.abonents_idx_id;
ALTER TABLE ONLY public.agents_online DROP CONSTRAINT agents_online_id_key;
ALTER TABLE ONLY public.agents DROP CONSTRAINT agents_no_key;
ALTER TABLE ONLY public.agents DROP CONSTRAINT agents_id_key;
ALTER TABLE public.reasons ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.queues ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.agents ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.abonents ALTER COLUMN id DROP DEFAULT;
DROP TABLE public.transfers;
DROP SEQUENCE public.reasons_id_seq;
DROP TABLE public.reasons;
DROP SEQUENCE public.queues_id_seq;
DROP TABLE public.queues;
DROP TABLE public.queue_log;
DROP TABLE public.phones;
DROP TABLE public.agents_online;
DROP SEQUENCE public.agents_id_seq;
DROP TABLE public.agents;
DROP SEQUENCE public.abonents_id_seq;
DROP TABLE public.abonents;
DROP SCHEMA public;
--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'Standard public schema';


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: abonents; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE abonents (
    id integer NOT NULL,
    comm character varying(100),
    info character varying(50)
);


--
-- Name: abonents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE abonents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: abonents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE abonents_id_seq OWNED BY abonents.id;


--
-- Name: agents; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE agents (
    id integer NOT NULL,
    agent character varying NOT NULL,
    name character varying(50),
    pass character(32)
);


--
-- Name: agents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE agents_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: agents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE agents_id_seq OWNED BY agents.id;


--
-- Name: agents_online; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE agents_online (
    id integer NOT NULL,
    status integer,
    queue integer,
    chan character varying,
    logintime timestamp with time zone,
    callerid character varying,
    callstaken integer,
    penalty integer,
    paused boolean,
    lastcall timestamp with time zone
);


--
-- Name: phones; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE phones (
    id integer NOT NULL,
    ph_no character varying(15) NOT NULL
);


--
-- Name: queue_log; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE queue_log (
    date timestamp with time zone NOT NULL,
    callid double precision NOT NULL,
    queue integer NOT NULL,
    agent integer NOT NULL,
    reason integer NOT NULL,
    data1 character varying,
    data2 character varying,
    data3 character varying
);


--
-- Name: queues; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE queues (
    id integer NOT NULL,
    text character varying(15)
);


--
-- Name: queues_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE queues_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: queues_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE queues_id_seq OWNED BY queues.id;


--
-- Name: reasons; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE reasons (
    id integer NOT NULL,
    text character varying(30)
);


--
-- Name: reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE reasons_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE reasons_id_seq OWNED BY reasons.id;


--
-- Name: transfers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE transfers (
    "no" integer NOT NULL,
    reason integer NOT NULL,
    "start" timestamp with time zone NOT NULL,
    stop timestamp with time zone NOT NULL,
    callid double precision NOT NULL,
    agent integer NOT NULL
);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE abonents ALTER COLUMN id SET DEFAULT nextval('abonents_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE agents ALTER COLUMN id SET DEFAULT nextval('agents_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE queues ALTER COLUMN id SET DEFAULT nextval('queues_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE reasons ALTER COLUMN id SET DEFAULT nextval('reasons_id_seq'::regclass);


--
-- Name: agents_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY agents
    ADD CONSTRAINT agents_id_key UNIQUE (id);


--
-- Name: agents_no_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY agents
    ADD CONSTRAINT agents_no_key UNIQUE (agent);


--
-- Name: agents_online_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY agents_online
    ADD CONSTRAINT agents_online_id_key UNIQUE (id);


--
-- Name: abonents_idx_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX abonents_idx_id ON abonents USING btree (id);


--
-- Name: agents_idx_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX agents_idx_id ON agents USING btree (id);


--
-- Name: phones_idx_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX phones_idx_id ON phones USING btree (id);


--
-- Name: queue_log_idx_callid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX queue_log_idx_callid ON queue_log USING btree (callid);


--
-- Name: queue_log_idx_date; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX queue_log_idx_date ON queue_log USING btree (date);


--
-- Name: queues_idx_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX queues_idx_id ON queues USING btree (id);


--
-- Name: reasons_idx_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX reasons_idx_id ON reasons USING btree (id);


--
-- PostgreSQL database dump complete
--

