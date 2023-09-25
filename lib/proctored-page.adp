<master>
  <if @doc@ defined><property name="&doc">doc</property></if>
  <property name="show_header">0</property>
  <property name="show_context_bar">0</property>
  <property name="side_menu">0</property>
  <property name="show_title">0</property>
  <property name="show_footer">0</property>
  <property name="show_community_title">0</property>

  <script src="/resources/proctoring-support/gif.js"></script>
  <script src="/resources/proctoring-support/proctoring.js"></script>
  <script src="/resources/proctoring-support/audiowave.js"></script>
  <link rel="stylesheet" href="/resources/proctoring-support/proctored-page.css">

  <link rel="stylesheet" href="/resources/acs-templating/modal.css">
  <script src="/resources/acs-templating/modal.js"></script>

  <!-- Alert/Error messages -->
  <div id="modal-messages" class="acs-modal">
    <div class="acs-modal-content">
      <div class="modal-body"></div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary acs-modal-close">OK</button>
      </div>
    </div>
  </div>

  <div id="wizard">
    <h1>@proctoring_name@</h1>

    <!-- One "tab" for each step in the form: -->
    <if @proctoring_p;literal@ true>
      <div class="tab">
        <div>@msg.proctoring_accept@</div>
      </div>
      <if @audio_p;literal@ true>
        <div class="tab">
          <h3>#proctoring-support.grant_access_to_microphone_title#</h3>
          <div>#proctoring-support.grant_access_to_microphone_msg#</div>
          <canvas id="audio" style="height: 100px; width: 100%"></canvas>
        </div>
      </if>
      <if @camera_p;literal@ true>
        <div class="tab">
          <h3>#proctoring-support.grant_access_to_camera_title#</h3>
          <div>#proctoring-support.grant_access_to_camera_msg#</div>
          <video class="wizard-video" width="640" id="webcam" autoplay playsinline muted="false" volume=0></video>
        </div>
      </if>
      <if @desktop_p;literal@ true>
        <div class="tab">
          <h3>#proctoring-support.grant_access_to_desktop_title#</h3>
          <div>#proctoring-support.grant_access_to_desktop_msg#</div>
          <video class="wizard-video" width="640" id="desktop" autoplay playsinline muted="false" volume=0></video>
        </div>
      </if>
    </if>
    <if @examination_statement_p;literal@ true>
      <div class="tab">
        <div id="examination-statement">@msg.exam_mode;literal@</div>
      </div>
    </if>
    <div id="error-message" class="text-danger"></div>
    <div style="overflow:auto;">
      <div style="float:right;">
        <button class="btn btn-outline-secondary btn-default" type="button" id="prevBtn">#acs-kernel.common_Previous#</button>
        <button class="btn btn-primary" type="button" id="retryBtn">#proctoring-support.check_again#</button>
        <button class="btn btn-primary" type="button" id="nextBtn">#acs-kernel.common_Next#</button>
      </div>
    </div>
    <!-- Circles which indicates the steps of the form: -->
    <div id="steps">
      <if @examination_statement_p;literal@ true>
        <span class="step"></span>
      </if>
      <if @proctoring_p;literal@ true>
        <if @audio_p;literal@ true>
          <span class="step"></span>
        </if>
        <if @camera_p;literal@ true>
          <span class="step"></span>
        </if>
        <if @desktop_p;literal@ true>
          <span class="step"></span>
        </if>
        <span class="step"></span>
      </if>
    </div>
  </div>

  <div id="proctoring">
    <div class="row info_proctoring">
      <bold>@msg.proctoring_banner@</bold>
      <div id="preview-placeholder"></div>
    </div>

    <div id="proctored-iframe-placeholder" class="embed-responsive embed-responsive-16by9"></div>
  </div>

  <script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
    const objectId = "@object_id;literal@";
    const objectURL = "@object_url;literal@";
    const hasUpload = @upload_p;literal@;
    const uploadURL = "@upload_url;literal@";
    const hasExaminationStatement = @examination_statement_p;literal@;
    const examinationStatementURL = "@examination_statement_url;literal@";
    const hasPreview = @preview_p;literal@;
    const hasProctoring = @proctoring_p;literal@;
    const hasCamera = @camera_p;literal@;
    const hasDesktop = @desktop_p;literal@;
    const hasAudio = @audio_p;literal@;
    const minMsInterval = @min_ms_interval;literal@;
    const maxMsInterval = @max_ms_interval;literal@;
    const minAudioDuration = @min_audio_duration;literal@;
    const maxAudioDuration = @max_audio_duration;literal@;
    const missingStreamMessage = "@msg.missing_stream;noquote@";
    const blackPictureCameraMessage = "@msg.black_picture_camera;noquote@";
    const blackPictureDesktopMessage = "@msg.black_picture_desktop;noquote@";
    const requestFailedMessage = "@msg.request_failed@";
    const requestTimedOutMessage = "@msg.request_timeout@";
    const audioGrabbingNotSupportedMessage = "@msg.audio_grabbing_not_supported;noquote@";
    const cameraGrabbingNotSupportedMessage = "@msg.camera_grabbing_not_supported;noquote@";
    const desktopGrabbingNotSupportedMessage = "@msg.desktop_grabbing_not_supported;noquote@";
    const yourMicrophoneIsMutedMessage = "@msg.your_microphone_is_muted;noquote@";
    const microphonePermissionDeniedMessage = "@msg.microphone_permission_denied;noquote@";
    const cameraPermissionDeniedMessage = "@msg.camera_permission_denied;noquote@";
    const desktopPermissionDeniedMessage = "@msg.desktop_permission_denied;noquote@";
    const microphoneNotFoundMessage = "@msg.microphone_not_found;noquote@";
    const cameraNotFoundMessage = "@msg.camera_not_found;noquote@";
    const microphoneNotReadableMessage = "@msg.microphone_not_readable;noquote@";
    const cameraNotReadableMessage = "@msg.camera_not_readable;noquote@";
    const wrongDisplaySurfaceSelectedMessage = "@msg.wrong_display_surface_selected;noquote@";
    const displaySurfaceNotSupportedMessage = "@msg.display_surface_not_supported;noquote@";
    const mobileDevicesUnsupportedMessage = "@msg.mobile_devices_not_supported@";
    const microphoneTooLowMessage = "@msg.microphone_too_low;noquote@";
    const isMobile = @mobile_p;literal@;
    const checkActive = @check_active_p;literal@;
    const record_p = @record_p;literal@;
    const nextLabel = "#acs-kernel.common_Next#";
    const submitLabel = "#proctoring-support.wizard_finish#";
    const acceptLabel = "#proctoring-support.accept#";
    const blackPictureSizeThreshold = 5000; // kbytes
    const tooLongWithoutSendingArtifactsMessage = `@msg.too_long_without_sending_artifacts@`;
  </script>
  <script src="/resources/proctoring-support/proctored-page.js"></script>
