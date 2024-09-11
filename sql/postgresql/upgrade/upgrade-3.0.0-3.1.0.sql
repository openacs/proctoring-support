begin;

--
-- The proctoring_object_artifacts table is meant to store information
-- for each file collected during proctoring and provide a technical
-- space to store additional metadata coming from e.g. postprocessing
-- happening at a later phase.
-- The metadata column is a JSON so that the particular type of
-- information we store is flexible and can depend on the different
-- kind of file or even be extended by downstream integrations.
--
create table if not exists proctoring_object_artifacts (
       artifact_id serial primary key,
       -- we might have referenced the proctoring_objects table rather
       -- than acs_objects, but this makes the data model more
       -- flexible for those integrations that do not store the
       -- proctoring configuration in proctoring_objects (e.g. xowf)
       object_id   integer references acs_objects(object_id) on delete cascade,
       user_id     integer references users(user_id) on delete cascade,
       timestamp   timestamp not null default current_timestamp,
       name        text not null,
       type        text not null,
       file        text not null,
       metadata    jsonb
);

create index if not exists proctoring_object_artifacts_object_id_idx on
       proctoring_object_artifacts(object_id);

create index if not exists proctoring_object_artifacts_user_id_idx on
       proctoring_object_artifacts(user_id);

create index if not exists proctoring_object_artifacts_timestamp_idx on
       proctoring_object_artifacts(timestamp);

create index if not exists proctoring_object_artifacts_name_idx on
       proctoring_object_artifacts(name);

create index if not exists proctoring_object_artifacts_type_idx on
       proctoring_object_artifacts(type);

create index if not exists proctoring_object_artifacts_file_idx on
       proctoring_object_artifacts(file);

create unique index if not exists proctoring_object_artifacts_un_idx on
       proctoring_object_artifacts(object_id, user_id, timestamp, name, type);

end;
