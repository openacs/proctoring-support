ad_page_contract {
    AJAX backend for bulk reviewing the proctoring artifacts.

    @param object_id id of the proctored object
    @param user_id user this artifacts belongs to
    @param flag which flag are we setting?
    @param return_url the return URL

    @return a redirect to the return_url
} {
    object_id:naturalnum,notnull
    user_id:naturalnum,notnull
    {flag:boolean false}
    {return_url:localurl .}
}

set reviewer_id [ad_conn user_id]

if {$flag} {
    set comment [_ proctoring-support.user_has_flagged_this_artifact_msg]
} else {
    set comment [_ proctoring-support.user_has_unflagged_this_artifact_msg]
}

set flag [expr {$flag ? "true" : "false"}]

::xo::dc dml update_comments {
    with
    updated_revisions as (
        select jsonb_agg(u.revision) as revisions, u.artifact_id

        -- The flag is stored on each review comment, but counts
        -- as a single property. Therefore, we set for all review
        -- comments the same flag, when specified. This because we
        -- might want to handle the flag on single messages in the
        -- future.
        from (select revision || (select to_jsonb(f.*) from
                                  (select :flag as flag from dual) f) as revision,
                     artifact_id
                from (

              -- These are all of the existing messages, minus the
              -- eventually deleted one.
              select revision, artifact_id
              from
              (select jsonb_array_elements(metadata->'revisions') as revision,
                      a.artifact_id
                 from proctoring_object_artifacts a
               where a.object_id = :object_id
                 and a.user_id = :user_id
               ) existing

              union all

              -- Generate a tuple with the new message for every artifact
              select to_jsonb(record) as revision, a.artifact_id
                from (select person_id as user_id,
                             to_char(current_timestamp, 'YYYY-MM-DD HH24:MI:SS') as timestamp,
                             p.first_names || ' ' || p.last_name as author,
                            :comment as comment,
                            'false' as flag
                        from persons p
                       where person_id = :reviewer_id) record
                  join proctoring_object_artifacts a
                    on a.object_id = :object_id
                   and a.user_id = :user_id
              ) u

       -- Sort the updated revisions by timestamp
       order by revision->'timestamp' asc
       ) u
       group by artifact_id
    )
    -- Now, take the aggregated JSON structure built above and
    -- replace the field "revisions" in the "medatata" JSON
    -- column of the artifacts table.
    update proctoring_object_artifacts as a set
       metadata = jsonb_set(coalesce(metadata, '{}'),
                            '{revisions}',
                            u.revisions)
     from updated_revisions u
    where u.artifact_id = a.artifact_id
      and acs_permission.permission_p(a.object_id, :reviewer_id, 'admin')
}

ad_returnredirect $return_url
ad_script_abort
