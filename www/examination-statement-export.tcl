ad_page_contract {

    Export the exam declaration acceptances for this object

} {
    object_id:naturalnum,notnull
}

permission::require_permission -object_id $object_id -privilege admin
