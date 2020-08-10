ad_include_contract {

    Store acceptance of the examination statement

} {
    object_id:naturalnum,notnull
}

auth::require_login

set user_id [ad_conn user_id]

::xo::dc dml -prepare {integer integer} insert {
    insert into proctoring_examination_statement_acceptance
    (object_id, user_id)
    values
    (:object_id, :user_id)
}

ns_return 200 text/plain OK
ad_script_abort
