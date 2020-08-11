ad_include_contract {
    Inside a page, this include behaves as a captive portal and if
    proctoring is enabled and we are still not in the proctoring
    iframe, user is force redirected to the object_url
} {
    object_id:naturalnum,notnull
    object_url:localurl,notnull
}

if {[ns_conn isconnected]} {
    set admin_p [permission::permission_p -object_id $object_id -party_id [ad_conn user_id] -privilege admin]
    set read_p [permission::permission_p -object_id $object_id -party_id [ad_conn user_id] -privilege read]
} else {
    set admin_p false
    set read_p false
}

if {$read_p && !$admin_p} {
    set proctoring_p [::proctoring::active_p -object_id $object_id]
} else {
    set proctoring_p false
}
