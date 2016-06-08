--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

--
-- Name: reasons_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('reasons_id_seq', 25, true);


--
-- Data for Name: reasons; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO reasons VALUES (1, 'ABANDON');
INSERT INTO reasons VALUES (2, 'AGENTDUMP');
INSERT INTO reasons VALUES (3, 'AGENTLOGIN');
INSERT INTO reasons VALUES (4, 'AGENTCALLBACKLOGIN');
INSERT INTO reasons VALUES (5, 'AGENTLOGOFF');
INSERT INTO reasons VALUES (6, 'AGENTCALLBACKLOGOFF');
INSERT INTO reasons VALUES (7, 'COMPLETEAGENT');
INSERT INTO reasons VALUES (8, 'COMPLETECALLER');
INSERT INTO reasons VALUES (9, 'CONFIGRELOAD');
INSERT INTO reasons VALUES (10, 'CONNECT');
INSERT INTO reasons VALUES (11, 'ENTERQUEUE');
INSERT INTO reasons VALUES (12, 'EXITWITHKEY');
INSERT INTO reasons VALUES (13, 'EXITWITHTIMEOUT');
INSERT INTO reasons VALUES (14, 'QUEUESTART');
INSERT INTO reasons VALUES (15, 'SYSCOMPAT');
INSERT INTO reasons VALUES (16, 'TRANSFER');
INSERT INTO reasons VALUES (17, 'RINGNOANSWER');
INSERT INTO reasons VALUES (18, 'ADDMEMBER');
INSERT INTO reasons VALUES (19, 'PAUSEALL');
INSERT INTO reasons VALUES (20, 'UNPAUSEALL');
INSERT INTO reasons VALUES (21, 'PAUSE');
INSERT INTO reasons VALUES (23, 'REMOVEMEMBER');
INSERT INTO reasons VALUES (24, 'UNPAUSE');


--
-- PostgreSQL database dump complete
--

