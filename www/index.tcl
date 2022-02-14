ad_page_contract {
    A demo page showcasing proctoring.

    For this demo, we will use the same proctoring package as the
    proctored object. Admins of the page will be able to see and
    manage the proctoring artifacts, while regular users accessing the
    package will be proctored.
}

auth::require_login

set object_id [ad_conn package_id]

set admin_p [::permission::permission_p -object_id $object_id -privilege admin]
