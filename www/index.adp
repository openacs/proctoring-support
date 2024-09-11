<if @admin_p@ false>
  <include src="/packages/proctoring-support/lib/proctored-page"
           object_id="@object_id;literal@"
           object_url="/proctoring/proctored-index"
           proctoring_p="true"
           check_active_p="false"
           examination_statement_p="false"
           preview_p="true"
           notify_p="true"
           >
</if>
<else>
  <master>
    <h1>Administrator</h1>
    <a href="display">Display Proctoring Artifacts</a>
</else>
