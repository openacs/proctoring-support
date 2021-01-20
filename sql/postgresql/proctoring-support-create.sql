
-- Table of objects where proctoring is enabled
create table proctoring_objects (
       object_id       integer
                       primary key
                       references acs_objects(object_id) on delete cascade,
       enabled_p       boolean not null default true,
       start_date      date, -- date since which proctoring can happen
                             -- (e.g. 2018-01-01)

       end_date        date, -- date since which proctoring is closed
                             -- (e.g. 2018-01-02)

       start_time      time, -- time of day since which proctoring can
                             -- happen for every day where proctoring
                             -- is enabled (e.g. 08:00)

       end_time        time, -- time of day since which proctoring is
                             -- closed for every day where proctoring
                             -- is enabled (e.g. 20:00)
       preview_p       boolean not null default false, -- display a preview of recording to proctored user
       audio_p         boolean not null default true,   -- do we record audio?
       camera_p        boolean not null default true,   -- do we record the camera?
       desktop_p       boolean not null default true,   -- do we record the desktop?
       proctoring_p    boolean not null default true,   -- do the actual proctoring
       examination_statement_p boolean not null default true   -- display the examination statement
);

comment on table proctoring_objects is 'Objects for which proctoring is enabled';
comment on column proctoring_objects.object_id is 'Object which should be proctored';
comment on column proctoring_objects.start_date is 'Date since which proctoring can happen';
comment on column proctoring_objects.end_date is 'Date since which proctoring is closed';
comment on column proctoring_objects.start_time is 'Time of day since which proctoring can happen for every day where proctoring is enabled';
comment on column proctoring_objects.end_time is 'Time of day since which proctoring is closed for every day where proctoring is enabled';
comment on column proctoring_objects.preview_p is 'Display a preview of the recording to the proctored user';
comment on column proctoring_objects.proctoring_p is 'Turn proctoring on/off';
comment on column proctoring_objects.examination_statement_p is 'Display the examination statement';


create table proctoring_examination_statement_acceptance (
       object_id       integer not null
                       references acs_objects(object_id) on delete cascade,
       user_id         integer not null
                       references users(user_id) on delete cascade,
       timestamp       timestamp not null default current_timestamp
);

comment on table proctoring_examination_statement_acceptance is 'Records acceptance of the examination statements for a proctored object by a user. Can be repeated.';

create index proctoring_examination_statement_acceptance_object_id_idx on
       proctoring_examination_statement_acceptance(object_id);

create index proctoring_examination_statement_acceptance_user_id_idx on
       proctoring_examination_statement_acceptance(user_id);
