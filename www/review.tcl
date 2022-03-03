ad_page_contract {
    AJAX backend fot the reviewing of proctoring artifacts.

    @param object_id id of the proctored object
    @param user_id user this artifacts belongs to
    @param artifact_id on which artifact we are operating. If this is
                       specified, we will operate on a single
                       artifact, rather than all those for object and
                       user.
    @param comment textual comment. Can be empty, for instance, when
                   we are flagging the artifact.
    @param flag true means "OK" and false means "flag for
                review". When empty, it won't change the status of the
                artifact.
    @param delete_record a JSON record representing a review comment
                         that we want to delete. All revisions equals
                         to this will be deleted from the artifact.
    @param return_url the return URL

    @return In case of error, the response will be returned to the
            user. In case of success, if this was an operation on a
            single artifact, the updated list of review comments will
            be returned in JSON format. If this was an operation on
            all artifacts for object and user, then we will issue a
            redirect to return_url.
} {
    {artifact_id:naturalnum ""}
    {object_id:naturalnum ""}
    {user_id:naturalnum ""}
    {comment ""}
    {flag:boolean ""}
    {deleted_record ""}
    {return_url:localurl .}
}

set reviewer_id [ad_conn user_id]

if {$deleted_record eq "" && $comment eq ""} {
    if {$flag} {
        set comment [_ proctoring-support.user_has_flagged_this_artifact_msg]
    } else {
        set comment [_ proctoring-support.user_has_unflagged_this_artifact_msg]
    }
}

if {$flag ne ""} {
    set flag [expr {$flag ? "true" : "false"}]
}

::xo::dc 1row update_comments {
    with
    updated_revisions as (
        select jsonb_agg(u.revision) as revisions, u.artifact_id
        -- The flag is stored on each review comment, but counts
        -- as a single property. Therefore, we set for all review
        -- comments the same flag, when specified. This because we
        -- might want to handle the flag on single messages in the
        -- future.
        from (select revision || (case when :flag is null then '{}'
                                  else (select to_jsonb(f.*) from
                                        (select :flag as flag from dual) f)
                                  end) as revision,
                     artifact_id
               from (

              -- These are all of the existing messages, minus the
              -- eventually deleted one.
              select revision, artifact_id
              from
              (select jsonb_array_elements(metadata->'revisions') as revision,
                      a.artifact_id
                 from proctoring_object_artifacts a
                where (a.object_id = :object_id
                       and a.user_id = :user_id) or
                      (:object_id is null
                       and :user_id is null
                       and a.artifact_id = :artifact_id)
               ) existing
              where :deleted_record is null or
              not (:deleted_record @> revision
                   and revision @> :deleted_record)

              union all

              -- This is the new message, when some comment is
              -- there to store.
              select to_jsonb(record) as revision,
                     coalesce(a.artifact_id, :artifact_id) as artifact_id
                from (select person_id as user_id,
                             to_char(current_timestamp, 'YYYY-MM-DD HH24:MI:SS') as timestamp,
                             p.first_names || ' ' || p.last_name as author,
                             :comment as comment,
                             :flag as flag
                       from persons p
                      where person_id = :reviewer_id
                      and   :comment is not null) record
                 left join proctoring_object_artifacts a
                   on a.object_id = :object_id
                  and a.user_id = :user_id
              ) u

       -- Sort the updated revisions by timestamp
       order by revision->'timestamp' asc
        ) u
        group by artifact_id
    ),
    update as (
       -- Now, take the aggregated JSON structure built above and
       -- replace the field "revisions" in the "medatata" JSON
       -- column of the artifacts table.
       update proctoring_object_artifacts as a set
          metadata = jsonb_set(coalesce(metadata, '{}'),
                               '{revisions}',
                               (select revisions from updated_revisions where artifact_id = a.artifact_id))
        where (artifact_id in (select artifact_id from updated_revisions)
               or artifact_id = :artifact_id)
         and acs_permission.permission_p(a.object_id, :reviewer_id, 'admin')
       returning a.object_id, a.metadata->'revisions' as revisions
    )

    -- Return the object_id so that we can inform websocket
    -- subscribers of changes. The revisions we return as JSON in
    -- case we are updating a single artifact.
    select object_id, revisions from update
    fetch first 1 rows only
}

if {[namespace which ::ws::multicast] ne ""} {
    # Notify that something new is there for this object, so the
    # users list will refresh
    set chat proctoring-${object_id}
    ::ws::multicast $chat [ns_connchan wsencode \
                               -opcode text 1]

}

if {$artifact_id ne ""} {
    ns_return 200 text/plain $revisions
} else {
    ad_returnredirect $return_url
    ad_script_abort
}

