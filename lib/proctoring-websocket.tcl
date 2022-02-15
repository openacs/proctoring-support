ad_include_contract {

    Subrscibe to the websocket notifying about new artifacts available
    for a certain object/user combination.

} {
    user_id:naturalnum,optional
    object_id:naturalnum,notnull
}

auth::require_login

permission::require_permission -object_id $object_id -party_id [ad_conn user_id] -privilege admin

set chat proctoring-${object_id}
if {[info exists user_id]} {
    append chat -${user_id}
}
ns_log warning "Subscribing to chat: $chat"
ws::subscribe [ws::handshake] $chat
ad_script_abort
