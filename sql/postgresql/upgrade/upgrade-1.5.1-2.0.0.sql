
begin;

alter table proctoring_safe_exam_browser_conf alter column seb_file drop not null;
alter table proctoring_safe_exam_browser_conf rename column key to allowed_keys;

drop index proctoring_safe_exam_browser_conf_object_id_idx;

end;

