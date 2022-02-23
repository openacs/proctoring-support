ad_page_contract {
    AJAX backend fot the reviewing of proctoring artifacts.

    @param artifact_id on which artifact we are operating
    @param comment textual comment. Can be empty, for instance, when
                   we are flagging the artifact.
    @param flag are we flagging this artifact for review. Can be empty
                and defaults to false in this case.
    @param delete_record an optional JSON record representing a review
                         comment that we want to delete.

    @return In case of error, the response will be returned to the
            user. In case of success, the updated list of review
            comments will be returned in JSON format.
} {
    artifact_id:naturalnum,notnull
    {comment ""}
    {flag:boolean ""}
    {deleted_record ""}
}

set user_id [ad_conn user_id]

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

try {
    ::xo::dc 1row update_comments {
        with
        updated_revisions as (
            select jsonb_agg(u.revision)

            -- The flag is stored on each review comment, but counts
            -- as a single property. Therefore, we set for all review
            -- comments the same flag, when specified. This because we
            -- might want to handle the flag on single messages in the
            -- future.
            from (select revision || (case when :flag is null then '{}'
                                      else (select to_jsonb(f.*) from
                                            (select :flag as flag from dual) f)
                                      end) as revision
                    from (

                  -- These are all of the existing messages, minus the
                  -- eventually deleted one.
                  select revision
                  from
                  (select jsonb_array_elements(metadata->'revisions') as revision
                     from proctoring_object_artifacts a
                    where a.artifact_id = :artifact_id
                   ) existing
                  where :deleted_record is null or
                  not (:deleted_record @> revision
                       and revision @> :deleted_record)

                  union all

                  -- This is the new message, when some comment is
                  -- there to store.
                  select to_jsonb(record) as revision from
                  (select person_id as user_id,
                          to_char(current_timestamp, 'YYYY-MM-DD HH24:MI:SS') as timestamp,
                          p.first_names || ' ' || p.last_name as author,
                          :comment as comment,
                          'false' as flag
                    from persons p
                   where person_id = :user_id
                   and   :comment is not null) record
                  ) u

           -- Sort the updated revisions by timestamp
           order by revision->'timestamp' asc
            ) u
        ),
        update as (
            -- Now, take the aggregated JSON structure built above and
            -- replace the field "revisions" in the "medatata" JSON
            -- column of the artifacts table.
            update proctoring_object_artifacts set
               metadata = jsonb_set(coalesce(metadata, '{}'),
                                    '{revisions}',
                                    (select * from updated_revisions))
            where artifact_id = :artifact_id
              and acs_permission.permission_p(object_id, :user_id, 'admin')
            returning object_id, metadata->'revisions' as revisions
        )

        -- Return the final result as a JSON array
        select object_id, revisions from update
    }

    if {[namespace which ::ws::multicast] ne ""} {
        ns_log warning ciao
        # Notify that something new is there for this object, so the
        # users list will refresh
        set chat proctoring-${object_id}
        ::ws::multicast $chat [ns_connchan wsencode \
                                   -opcode text 1]

    }

    ns_return 200 text/plain $revisions

} on error {errmsg} {

    ns_return 500 text/html $errmsg

}
