<script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
  window.addEventListener("load", function(e) {
      var isProctored = @proctoring_p@;
      var inProctoringIframe = window.parent != undefined &&
          window.parent.document.querySelector("#proctored-iframe-@object_id@") != null;
      if (isProctored && !inProctoringIframe) {
          location.href = "@object_url@";
      }
  });
</script>