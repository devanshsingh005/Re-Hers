-- Snapshot of the public schema on 2026-11-16 before the cleanup (taken from the backup). Already applied; do not re-run.
--
-- PostgreSQL database dump
--

\restrict fncV6py2h1gZB0uw0VLXrRfvvZ7yMg3dpAnt0sy6LywdgnTq1mESHWdoU5Tng4o

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.12 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: delete_user_account_data(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_user_account_data(p_user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'storage'
    AS $$
begin
  delete from public.playlist_items
  where playlist_id in (
    select id
    from public.playlists
    where user_id = p_user_id
  );

  delete from public.playlists
  where user_id = p_user_id;

  delete from public.recent_plays
  where user_id = p_user_id;

  delete from public.lesson_events
  where user_id = p_user_id;

  delete from public.jobs
  where user_id = p_user_id;

  delete from public.scans
  where user_id = p_user_id;

  delete from public.user_onboarding
  where id = p_user_id;

  delete from public.profiles
  where id = p_user_id;
end;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  insert into public.profiles (id, full_name, username, avatar_url, created_at, updated_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'username', ''),
    '',
    now(),
    now()
  );
  return new;
end;
$$;


--
-- Name: handle_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


--
-- Name: increment_study_time(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_study_time(p_user_id uuid, p_delta integer) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    AS $$
  UPDATE public.profiles
  SET total_study_seconds = total_study_seconds + p_delta
  WHERE id = p_user_id;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    pdf_path text NOT NULL,
    result_url text,
    status text DEFAULT 'pending'::text NOT NULL,
    error_message text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    label_status text,
    label_warning text,
    CONSTRAINT jobs_label_status_check CHECK ((label_status = ANY (ARRAY['success'::text, 'failed'::text]))),
    CONSTRAINT jobs_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'processing'::text, 'completed'::text, 'completed_with_warning'::text, 'failed'::text])))
);


--
-- Name: lesson_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lesson_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    chapter_index smallint NOT NULL,
    part_index smallint NOT NULL,
    event_type text NOT NULL,
    stars smallint,
    attempts smallint,
    duration_seconds integer,
    score_points smallint,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: music_quiz_questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.music_quiz_questions (
    id integer NOT NULL,
    question text NOT NULL,
    drawing_type text NOT NULL,
    drawing_params jsonb NOT NULL,
    answers jsonb NOT NULL,
    correct_index integer NOT NULL,
    difficulty text DEFAULT 'beginner'::text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT music_quiz_questions_difficulty_check CHECK ((difficulty = ANY (ARRAY['beginner'::text, 'intermediate'::text, 'advanced'::text])))
);


--
-- Name: music_quiz_questions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.music_quiz_questions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: music_quiz_questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.music_quiz_questions_id_seq OWNED BY public.music_quiz_questions.id;


--
-- Name: playlist_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.playlist_items (
    id bigint NOT NULL,
    playlist_id uuid NOT NULL,
    user_id uuid NOT NULL,
    track_id text NOT NULL,
    track_title text,
    artist_name text,
    sheet_scan_id bigint,
    "position" integer,
    added_at timestamp with time zone DEFAULT now()
);


--
-- Name: playlist_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.playlist_items ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.playlist_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: playlists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.playlists (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    cover_image_url text,
    is_public boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    username text,
    full_name text,
    bio text,
    avatar_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    current_chapter smallint DEFAULT 1 NOT NULL,
    current_part smallint DEFAULT 0 NOT NULL,
    last_active_at timestamp with time zone,
    total_study_seconds bigint DEFAULT 0 NOT NULL
);


--
-- Name: recent_plays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recent_plays (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    song_id uuid NOT NULL,
    last_played_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_id uuid NOT NULL,
    content_id uuid NOT NULL,
    content_type text DEFAULT 'sheet_music'::text NOT NULL,
    reason text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: scans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scans (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    json_data jsonb,
    processing_id text,
    status text DEFAULT 'pending'::text,
    original_filename text,
    file_type text,
    processed_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: scans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.scans ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.scans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: sheet_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sheet_files (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    job_id uuid NOT NULL,
    storage_path text NOT NULL,
    file_size_bytes bigint,
    status text DEFAULT 'processing'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT sheet_files_status_check CHECK ((status = ANY (ARRAY['processing'::text, 'completed'::text, 'failed'::text, 'orphaned'::text])))
);


--
-- Name: songs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.songs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    composer text NOT NULL,
    level smallint NOT NULL,
    tempo text NOT NULL,
    hands text NOT NULL,
    skill_tags text[] DEFAULT '{}'::text[] NOT NULL,
    skill_description text NOT NULL,
    initials text NOT NULL,
    sheet_file_id uuid,
    is_free boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    sort_order smallint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sheet_url text,
    cover_image_url text,
    is_converted boolean DEFAULT false,
    original_pdf_path text,
    labeled_pdf_path text,
    output_json_path text,
    CONSTRAINT songs_hands_check CHECK ((hands = ANY (ARRAY['right_only'::text, 'left_only'::text, 'both'::text]))),
    CONSTRAINT songs_level_check CHECK (((level >= 1) AND (level <= 5))),
    CONSTRAINT songs_tempo_check CHECK ((tempo = ANY (ARRAY['slow'::text, 'medium'::text, 'fast'::text])))
);


--
-- Name: user_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_blocks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    blocker_id uuid NOT NULL,
    blocked_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: user_onboarding; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_onboarding (
    id uuid NOT NULL,
    level text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    genres text[] DEFAULT '{}'::text[] NOT NULL,
    practice_mins smallint DEFAULT 10 NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT user_onboarding_level_check CHECK ((level = ANY (ARRAY['beginner'::text, 'some_basics'::text, 'intermediate'::text, 'advanced'::text]))),
    CONSTRAINT user_onboarding_practice_mins_check CHECK ((practice_mins = ANY (ARRAY[5, 10, 15, 20, 30, 45, 60])))
);


--
-- Name: user_storage_usage; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.user_storage_usage WITH (security_invoker='on') AS
 SELECT user_id,
    count(DISTINCT job_id) AS total_jobs,
    count(id) AS total_files,
    COALESCE(sum(file_size_bytes), (0)::numeric) AS total_storage_bytes,
    round((COALESCE(sum(file_size_bytes), (0)::numeric) / ((1024 * 1024))::numeric), 2) AS total_storage_mb
   FROM public.sheet_files sf
  GROUP BY user_id;


--
-- Name: music_quiz_questions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.music_quiz_questions ALTER COLUMN id SET DEFAULT nextval('public.music_quiz_questions_id_seq'::regclass);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: lesson_events lesson_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_events
    ADD CONSTRAINT lesson_events_pkey PRIMARY KEY (id);


--
-- Name: music_quiz_questions music_quiz_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.music_quiz_questions
    ADD CONSTRAINT music_quiz_questions_pkey PRIMARY KEY (id);


--
-- Name: playlist_items playlist_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playlist_items
    ADD CONSTRAINT playlist_items_pkey PRIMARY KEY (id);


--
-- Name: playlists playlists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playlists
    ADD CONSTRAINT playlists_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_username_key UNIQUE (username);


--
-- Name: recent_plays recent_plays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recent_plays
    ADD CONSTRAINT recent_plays_pkey PRIMARY KEY (id);


--
-- Name: recent_plays recent_plays_user_id_song_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recent_plays
    ADD CONSTRAINT recent_plays_user_id_song_id_key UNIQUE (user_id, song_id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: scans scans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT scans_pkey PRIMARY KEY (id);


--
-- Name: sheet_files sheet_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sheet_files
    ADD CONSTRAINT sheet_files_pkey PRIMARY KEY (id);


--
-- Name: songs songs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.songs
    ADD CONSTRAINT songs_pkey PRIMARY KEY (id);


--
-- Name: jobs unique_user_job; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT unique_user_job UNIQUE (user_id, id);


--
-- Name: sheet_files unique_user_job_files; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sheet_files
    ADD CONSTRAINT unique_user_job_files UNIQUE (user_id, job_id);


--
-- Name: user_blocks user_blocks_blocker_id_blocked_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocker_id_blocked_id_key UNIQUE (blocker_id, blocked_id);


--
-- Name: user_blocks user_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_pkey PRIMARY KEY (id);


--
-- Name: user_onboarding user_onboarding_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_onboarding
    ADD CONSTRAINT user_onboarding_pkey PRIMARY KEY (id);


--
-- Name: idx_jobs_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jobs_created_at ON public.jobs USING btree (created_at DESC);


--
-- Name: idx_jobs_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jobs_status ON public.jobs USING btree (status);


--
-- Name: idx_jobs_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jobs_user_id ON public.jobs USING btree (user_id);


--
-- Name: idx_quiz_questions_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quiz_questions_active ON public.music_quiz_questions USING btree (is_active, difficulty);


--
-- Name: idx_scans_discover_song_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_scans_discover_song_id ON public.scans USING btree (((json_data ->> 'discover_song_id'::text)));


--
-- Name: idx_scans_json_data_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_scans_json_data_gin ON public.scans USING gin (json_data jsonb_path_ops);


--
-- Name: idx_scans_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_scans_user_id ON public.scans USING btree (user_id);


--
-- Name: idx_sheet_files_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sheet_files_created_at ON public.sheet_files USING btree (created_at DESC);


--
-- Name: idx_sheet_files_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sheet_files_job_id ON public.sheet_files USING btree (job_id);


--
-- Name: idx_sheet_files_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sheet_files_status ON public.sheet_files USING btree (status);


--
-- Name: idx_sheet_files_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sheet_files_user_id ON public.sheet_files USING btree (user_id);


--
-- Name: idx_user_onboarding_genres; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_onboarding_genres ON public.user_onboarding USING gin (genres);


--
-- Name: idx_user_onboarding_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_onboarding_level ON public.user_onboarding USING btree (level);


--
-- Name: idx_user_onboarding_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_user_onboarding_unique ON public.user_onboarding USING btree (id);


--
-- Name: playlist_items_playlist_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX playlist_items_playlist_idx ON public.playlist_items USING btree (playlist_id, "position");


--
-- Name: recent_plays_recency_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX recent_plays_recency_idx ON public.recent_plays USING btree (user_id, last_played_at DESC);


--
-- Name: user_onboarding on_user_onboarding_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER on_user_onboarding_updated BEFORE UPDATE ON public.user_onboarding FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


--
-- Name: jobs jobs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: lesson_events lesson_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_events
    ADD CONSTRAINT lesson_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: playlist_items playlist_items_playlist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playlist_items
    ADD CONSTRAINT playlist_items_playlist_id_fkey FOREIGN KEY (playlist_id) REFERENCES public.playlists(id) ON DELETE CASCADE;


--
-- Name: playlist_items playlist_items_sheet_scan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playlist_items
    ADD CONSTRAINT playlist_items_sheet_scan_id_fkey FOREIGN KEY (sheet_scan_id) REFERENCES public.scans(id) ON DELETE SET NULL;


--
-- Name: playlist_items playlist_items_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playlist_items
    ADD CONSTRAINT playlist_items_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: playlists playlists_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playlists
    ADD CONSTRAINT playlists_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: recent_plays recent_plays_song_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recent_plays
    ADD CONSTRAINT recent_plays_song_id_fkey FOREIGN KEY (song_id) REFERENCES public.songs(id) ON DELETE CASCADE;


--
-- Name: recent_plays recent_plays_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recent_plays
    ADD CONSTRAINT recent_plays_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: reports reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: scans scans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT scans_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sheet_files sheet_files_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sheet_files
    ADD CONSTRAINT sheet_files_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: sheet_files sheet_files_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sheet_files
    ADD CONSTRAINT sheet_files_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: songs songs_sheet_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.songs
    ADD CONSTRAINT songs_sheet_file_id_fkey FOREIGN KEY (sheet_file_id) REFERENCES public.sheet_files(id) ON DELETE SET NULL;


--
-- Name: user_blocks user_blocks_blocked_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_blocks user_blocks_blocker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_onboarding user_onboarding_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_onboarding
    ADD CONSTRAINT user_onboarding_id_fkey FOREIGN KEY (id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: music_quiz_questions Anyone can read quiz questions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can read quiz questions" ON public.music_quiz_questions FOR SELECT USING (true);


--
-- Name: playlists Anyone can view public playlists; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view public playlists" ON public.playlists FOR SELECT USING ((is_public = true));


--
-- Name: user_onboarding Enable insert for authenticated users only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable insert for authenticated users only" ON public.user_onboarding FOR INSERT TO authenticated, anon WITH CHECK (true);


--
-- Name: songs Enable read access for all users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable read access for all users" ON public.songs FOR SELECT TO authenticated, anon USING (true);


--
-- Name: user_onboarding Enable read access for all users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable read access for all users" ON public.user_onboarding FOR SELECT TO dashboard_user, authenticated, anon, supabase_admin USING (true);


--
-- Name: playlist_items Owner can manage playlist items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Owner can manage playlist items" ON public.playlist_items USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: playlists Owner can manage playlists; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Owner can manage playlists" ON public.playlists USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: playlist_items Owner can view playlist items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Owner can view playlist items" ON public.playlist_items FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: playlists Owner can view private playlists; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Owner can view private playlists" ON public.playlists FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: music_quiz_questions Service role can manage questions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role can manage questions" ON public.music_quiz_questions USING ((auth.role() = 'service_role'::text));


--
-- Name: reports Users can create reports.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can create reports." ON public.reports FOR INSERT WITH CHECK ((auth.uid() = reporter_id));


--
-- Name: scans Users can delete own scans; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own scans" ON public.scans FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: profiles Users can insert own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK ((id = auth.uid()));


--
-- Name: profiles Users can insert own profile row; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own profile row" ON public.profiles FOR INSERT WITH CHECK ((auth.uid() = id));


--
-- Name: scans Users can insert own scans; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own scans" ON public.scans FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: recent_plays Users can insert their own recents; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own recents" ON public.recent_plays FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_blocks Users can manage their own blocks.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can manage their own blocks." ON public.user_blocks USING ((auth.uid() = blocker_id));


--
-- Name: scans Users can see own scans; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can see own scans" ON public.scans FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: profiles Users can update own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE TO authenticated USING ((id = auth.uid())) WITH CHECK ((id = auth.uid()));


--
-- Name: scans Users can update own scans; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own scans" ON public.scans FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: recent_plays Users can update their own recents; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own recents" ON public.recent_plays FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: profiles Users can view own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT TO authenticated USING ((id = auth.uid()));


--
-- Name: scans Users can view own scans; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own scans" ON public.scans FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: recent_plays Users can view their own recents; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own recents" ON public.recent_plays FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: lesson_events Users manage own events; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own events" ON public.lesson_events USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: profiles Users update own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE USING ((auth.uid() = id));


--
-- Name: jobs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

--
-- Name: jobs jobs_user_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY jobs_user_delete ON public.jobs FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: jobs jobs_user_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY jobs_user_insert ON public.jobs FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: jobs jobs_user_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY jobs_user_isolation ON public.jobs FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: jobs jobs_user_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY jobs_user_update ON public.jobs FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: lesson_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lesson_events ENABLE ROW LEVEL SECURITY;

--
-- Name: music_quiz_questions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.music_quiz_questions ENABLE ROW LEVEL SECURITY;

--
-- Name: playlist_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.playlist_items ENABLE ROW LEVEL SECURITY;

--
-- Name: playlists; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.playlists ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: recent_plays; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.recent_plays ENABLE ROW LEVEL SECURITY;

--
-- Name: reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

--
-- Name: scans; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.scans ENABLE ROW LEVEL SECURITY;

--
-- Name: sheet_files; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sheet_files ENABLE ROW LEVEL SECURITY;

--
-- Name: sheet_files sheet_files_user_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sheet_files_user_delete ON public.sheet_files FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: sheet_files sheet_files_user_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sheet_files_user_insert ON public.sheet_files FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: sheet_files sheet_files_user_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sheet_files_user_isolation ON public.sheet_files FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: sheet_files sheet_files_user_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sheet_files_user_update ON public.sheet_files FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: songs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.songs ENABLE ROW LEVEL SECURITY;

--
-- Name: user_blocks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

--
-- Name: user_onboarding; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_onboarding ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION delete_user_account_data(p_user_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.delete_user_account_data(p_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.delete_user_account_data(p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.delete_user_account_data(p_user_id uuid) TO service_role;


--
-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.handle_new_user() TO anon;
GRANT ALL ON FUNCTION public.handle_new_user() TO authenticated;
GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;


--
-- Name: FUNCTION handle_updated_at(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.handle_updated_at() TO anon;
GRANT ALL ON FUNCTION public.handle_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.handle_updated_at() TO service_role;


--
-- Name: FUNCTION increment_study_time(p_user_id uuid, p_delta integer); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.increment_study_time(p_user_id uuid, p_delta integer) TO anon;
GRANT ALL ON FUNCTION public.increment_study_time(p_user_id uuid, p_delta integer) TO authenticated;
GRANT ALL ON FUNCTION public.increment_study_time(p_user_id uuid, p_delta integer) TO service_role;


--
-- Name: TABLE jobs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.jobs TO anon;
GRANT ALL ON TABLE public.jobs TO authenticated;
GRANT ALL ON TABLE public.jobs TO service_role;


--
-- Name: TABLE lesson_events; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.lesson_events TO anon;
GRANT ALL ON TABLE public.lesson_events TO authenticated;
GRANT ALL ON TABLE public.lesson_events TO service_role;


--
-- Name: TABLE music_quiz_questions; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.music_quiz_questions TO anon;
GRANT ALL ON TABLE public.music_quiz_questions TO authenticated;
GRANT ALL ON TABLE public.music_quiz_questions TO service_role;


--
-- Name: SEQUENCE music_quiz_questions_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.music_quiz_questions_id_seq TO anon;
GRANT ALL ON SEQUENCE public.music_quiz_questions_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.music_quiz_questions_id_seq TO service_role;


--
-- Name: TABLE playlist_items; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.playlist_items TO anon;
GRANT ALL ON TABLE public.playlist_items TO authenticated;
GRANT ALL ON TABLE public.playlist_items TO service_role;


--
-- Name: SEQUENCE playlist_items_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.playlist_items_id_seq TO anon;
GRANT ALL ON SEQUENCE public.playlist_items_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.playlist_items_id_seq TO service_role;


--
-- Name: TABLE playlists; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.playlists TO anon;
GRANT ALL ON TABLE public.playlists TO authenticated;
GRANT ALL ON TABLE public.playlists TO service_role;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;


--
-- Name: TABLE recent_plays; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.recent_plays TO anon;
GRANT ALL ON TABLE public.recent_plays TO authenticated;
GRANT ALL ON TABLE public.recent_plays TO service_role;


--
-- Name: TABLE reports; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.reports TO anon;
GRANT ALL ON TABLE public.reports TO authenticated;
GRANT ALL ON TABLE public.reports TO service_role;


--
-- Name: TABLE scans; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.scans TO anon;
GRANT ALL ON TABLE public.scans TO authenticated;
GRANT ALL ON TABLE public.scans TO service_role;


--
-- Name: SEQUENCE scans_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.scans_id_seq TO anon;
GRANT ALL ON SEQUENCE public.scans_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.scans_id_seq TO service_role;


--
-- Name: TABLE sheet_files; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.sheet_files TO anon;
GRANT ALL ON TABLE public.sheet_files TO authenticated;
GRANT ALL ON TABLE public.sheet_files TO service_role;


--
-- Name: TABLE songs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.songs TO anon;
GRANT ALL ON TABLE public.songs TO authenticated;
GRANT ALL ON TABLE public.songs TO service_role;


--
-- Name: TABLE user_blocks; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_blocks TO anon;
GRANT ALL ON TABLE public.user_blocks TO authenticated;
GRANT ALL ON TABLE public.user_blocks TO service_role;


--
-- Name: TABLE user_onboarding; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_onboarding TO anon;
GRANT ALL ON TABLE public.user_onboarding TO authenticated;
GRANT ALL ON TABLE public.user_onboarding TO service_role;


--
-- Name: TABLE user_storage_usage; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_storage_usage TO anon;
GRANT ALL ON TABLE public.user_storage_usage TO authenticated;
GRANT ALL ON TABLE public.user_storage_usage TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

\unrestrict fncV6py2h1gZB0uw0VLXrRfvvZ7yMg3dpAnt0sy6LywdgnTq1mESHWdoU5Tng4o

