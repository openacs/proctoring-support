ad_page_contract {
    Display the proctoring artifacts.
} {
    user_id:naturalnum,multiple,optional
    file:optional
}

set object_id [ad_conn package_id]

::permission::require_permission -object_id $object_id -privilege admin
