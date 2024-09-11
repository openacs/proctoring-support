
create table proctoring_safe_exam_browser_conf (
       object_id       integer primary key
                       references acs_objects(object_id) on delete cascade,
       seb_file        text not null, -- the file created via the SEB
                                      -- exam configuration that will
                                      -- configure the clients
                                      -- accessing this proctored
                                      -- object
       key             text not null  -- the keys generated during the SEB
                                      -- configuration that have been allowed
                                      -- access to this exam
);

create index proctoring_safe_exam_browser_conf_object_id_idx on
       proctoring_safe_exam_browser_conf(object_id);
